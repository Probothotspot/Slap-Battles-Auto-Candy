local Caps=dofile('ExecutorCaps.lua');local Registry=dofile('InteractionMethods.lua')
local n=0;local function eq(a,b)n=n+1;assert(a==b,'methods #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local c=Caps.new({identifyexecutor=function()return 'Xeno','fixture' end})
eq(c.Name,'Xeno');eq(c.Version,'fixture');eq(c.firetouchinterest,nil)
c=Caps.new({identifyexecutor=function()error('unsupported')end,getexecutorname=function()return 'Delta\nfixture'end})
eq(c.Name,'Delta fixture');eq(Caps.new({}).Name,'Unknown')
eq(c:reject('VIM.Mouse','security identity denied'),true);eq(c:allowed('VIM.Mouse'),false)
eq(c:allowed('Prompt.InputHold'),true);eq(c:reject('Other','door removed'),false);eq(c:allowed('Other'),true)
local calls=0
local function node(class,parent)
 local p={Class=class,Name=class,Parent=parent,Children={}}
 function p:IsA(k)return k==self.Class or k=='BasePart'and self.Class=='Part'end
 function p:GetChildren()calls=calls+1;return self.Children end
 function p:GetDescendants()error('No recursive full-tree query')end
 function p:IsDescendantOf(scope)local q=self.Parent;while q do if q==scope then return true end;q=q.Parent end;return false end
 if parent then parent.Children[#parent.Children+1]=p end;return p
end
local world=node('Workspace');local scope=node('Folder',world);scope.Name='Door'
local door=node('Part',scope);door.Name='DoorInnerTouch';door.CanTouch=true;door.CanCollide=false
local ctx={Root={CFrame='stage'},Scope=scope}
local actions={mouseUp=function()end}
local function build(caps)
 local r=Registry.new(ctx,door,scope,world,actions,caps,function()return 0 end)
 while not r.Ready do local before=calls;r:step();eq(calls-before<=64,true)end;return r
end
local r=build(Caps.new({}));eq(#r.Methods,0);eq(#r.Skipped,5)
local touch=node('TouchTransmitter',door);local touchCalls={}
c=Caps.new({firetouchinterest=function(root,target,state)touchCalls[#touchCalls+1]=state;eq(root,ctx.Root);eq(target,door)end})
r=build(c);eq(#r.Methods,2);eq(#touchCalls,0) -- Discovery does not invoke candidates.
eq(r.Methods[1].API,'firetouchinterest');eq(r.Methods[2].API,'PhysicalContact')
r.Methods[1].Begin();eq(touchCalls[1],0);r:release();eq(touchCalls[2],1);eq(ctx.InteractionRelease,nil)
door.CanTouch=false;r=build(c);eq(#r.Methods,0);door.CanTouch=true
touch.Parent=nil;door.Children={}
local detector=node('ClickDetector',door);local hit=0
r=build(Caps.new({fireclickdetector=function(o)eq(o,detector);hit=hit+1 end}))
eq(#r.Methods,1);eq(hit,0);r.Methods[1].Begin();eq(hit,1)
detector.Parent=nil;door.Children={}
local prompt=node('ProximityPrompt',door);prompt.Enabled=true;prompt.HoldDuration=.6
local began,ended=0,0
function prompt:InputHoldBegin()began=began+1 end
function prompt:InputHoldEnd()ended=ended+1 end
local fires=0;c=Caps.new({fireproximityprompt=function()fires=fires+1 end})
r=build(c);eq(#r.Methods,1);eq(r.Methods[1].API,'Prompt.InputHold')
eq(r.Methods[1].Hold>=.7,true);r.Methods[1].Begin();r:release();eq(began,1);eq(ended,1);eq(fires,0)
prompt.HoldDuration=0;r=build(c);eq(#r.Methods,2);r.Methods[1].Begin();eq(fires,1)
prompt.Enabled=false;r=build(c);eq(#r.Methods,0)
prompt.Parent=nil;door.Children={}
for i=1,1000 do node('Folder',scope)end
r=build(Caps.new({}));eq(r.Scanned,512)
print('PASS: '..n..' executor detection, API rejection, object gates, paired release and local scan budget assertions')
