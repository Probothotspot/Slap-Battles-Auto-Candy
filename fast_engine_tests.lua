_G.AutoCandyFastCycle=nil -- production default is the fast route
-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'engine #'..count..': '..tostring(a)..' ~= '..tostring(b))end
math.clamp=function(x,a,b)return math.max(a,math.min(b,x))end
local time=0;local realClock=os.clock;os.clock=function()return time end
local signals={}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end
  self.listeners[#self.listeners+1]=c;return c
 end
 function s:Fire(...)
  local list={table.unpack(self.listeners)}
  for _,c in ipairs(list)do if c.Connected then c.fn(...)end end
 end
 signals[#signals+1]=s;return s
end
local vm={}
Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end}
vm.__index=function(v,k)
 if k=='Magnitude'then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end
 if k=='Unit'then return v*(1/v.Magnitude)end
 if k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__unm=function(a)return Vector3.new(-a.X,-a.Y,-a.Z)end
vm.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
Vector3.zero=Vector3.new(0,0,0)
Vector2={new=function(x,y)return{X=x,Y=y}end}
local cm={}
CFrame={new=function(x,y,z)
 local p=type(x)=='table'and x or Vector3.new(x or 0,y or 0,z or 0)
 return setmetatable({Position=p,RightVector=Vector3.new(1,0,0),UpVector=Vector3.new(0,1,0),LookVector=Vector3.new(0,0,-1)},cm)
end}
function CFrame.lookAt(p,target)
 local c=CFrame.new(p);c.LookVector=(target-p).Unit
 c.RightVector=Vector3.new(-c.LookVector.Z,0,c.LookVector.X).Unit;return c
end
cm.__index={ToObjectSpace=function(a,b)return CFrame.new(b.Position-a.Position)end}
cm.__mul=function(a,b)return CFrame.new(a.Position+a.RightVector*b.Position.X+a.UpVector*b.Position.Y-a.LookVector*b.Position.Z)end
UDim={new=function(s,o)return{Scale=s,Offset=o}end}
UDim2={new=function(xs,xo,ys,yo)return{X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
Color3={fromRGB=function(r,g,b)return{r,g,b}end}
ColorSequence={new=function(v)return v end};ColorSequenceKeypoint={new=function(t,v)return{t,v}end}
TweenInfo={new=function(...)return{...}end}
Enum=setmetatable({},{__index=function(t,k)local v=setmetatable({},{__index=function(_,n)return n end});rawset(t,k,v);return v end})
-- Real KeyCode enum items expose Name and can be enumerated for case-insensitive input.
local keyItems={}
for _,name in ipairs({'Unknown','T','F8','LeftShift','E','Space'})do
 local code={Name=name};Enum.KeyCode[name]=code;keyItems[#keyItems+1]=code
end
function Enum.KeyCode:GetEnumItems()return keyItems end
RaycastParams={new=function()return{}end};OverlapParams={new=function()return{}end}
local methods,mt={},{}
Instance={new=function(class)return setmetatable({class=class,p={Name=class,Enabled=true,Visible=true},children={},signals={}},mt)end}
mt.__index=function(o,k)
 if methods[k]then return methods[k]end
 if k=='AbsoluteSize'then return{X=1000,Y=800}end
 if k=='Activated'or k=='InputBegan'or k=='InputChanged'or k=='InputEnded'or k=='WindowFocusReleased'or k=='Destroying'
 or k=='DescendantAdded'or k=='DescendantRemoving'or k=='MouseEnter'or k=='MouseLeave'or k=='Played'or k=='FocusLost'then
  o.signals[k]=o.signals[k]or signal();return o.signals[k]
 end
 return o.p[k]
end
mt.__newindex=function(o,k,v)
 if k=='Parent'then
  local old=o.p.Parent
  if old then for i,c in ipairs(old.children)do if c==o then table.remove(old.children,i);break end end end
  if v then v.children[#v.children+1]=o end
 end
 o.p[k]=v
 if k=='CFrame'then o.p.Position=v.Position end
end
function methods:IsA(c)return self.class==c or c=='BasePart'and(self.class=='Part'or self.class=='WedgePart')end
function methods:GetChildren()return{table.unpack(self.children)}end
function methods:GetDescendants()
 local all={};local function walk(p)for _,c in ipairs(p.children)do all[#all+1]=c;walk(c)end end;walk(self);return all
end
function methods:IsDescendantOf(p)local a=self.Parent;while a do if a==p then return true end;a=a.Parent end;return false end
function methods:FindFirstChild(n,recursive)
 for _,c in ipairs(self.children)do if c.Name==n then return c end;if recursive then local f=c:FindFirstChild(n,true);if f then return f end end end
end
function methods:FindFirstChildOfClass(c)for _,o in ipairs(self.children)do if o:IsA(c)then return o end end end
function methods:WaitForChild(n)return assert(self:FindFirstChild(n),n)end
function methods:GetPropertyChangedSignal(n)self.signals[n]=self.signals[n]or signal();return self.signals[n]end
function methods:Destroy()
 if self.p.Destroyed then return end;self.p.Destroyed=true;self.Destroying:Fire()
 for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil
end
function methods:GetPivot()return self:FindFirstChild('HumanoidRootPart').CFrame end
function methods:PivotTo(cf)self:FindFirstChild('HumanoidRootPart').CFrame=cf end
workspace=Instance.new('Workspace')
local player=Instance.new('Player');local pg=Instance.new('PlayerGui');pg.Parent=player
local char=Instance.new('Model');player.Character=char;char.Parent=workspace
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=CFrame.new(20,3,20);root.Size=Vector3.new(2,2,1);root.Parent=char
local h=Instance.new('Humanoid');h.Health=100;h.HipHeight=2;h.Parent=char
local doorContainer=Instance.new('Model');doorContainer.Name='Door';doorContainer.Parent=workspace
local door=Instance.new('Part');door.Name='DoorInnerTouch';door.Size=Vector3.new(5,10,.2);door.CFrame=CFrame.new(0,5,0);door.Parent=doorContainer
local knock=Instance.new('Sound');knock.Name='DoorKnock';knock.SoundId='rbxassetid://fixture';knock.Volume=1;knock.Parent=door
local camera={CFrame=CFrame.new(20,10,30),Focus=CFrame.new(),CameraType='Custom',CameraSubject=h}
function camera:WorldToViewportPoint()return{X=500,Y=400,Z=5},true end
function camera:WorldToScreenPoint()return{X=500,Y=436,Z=5},true end
workspace.CurrentCamera=camera
function workspace:Raycast(p)return{Position=Vector3.new(p.X,0,p.Z),Normal=Vector3.new(0,1,0)}end
function workspace:GetPartBoundsInBox()return{}end
local hb=signal();local input=Instance.new('UserInputService');local clicks={}
local services={Players={LocalPlayer=player},UserInputService=input,RunService={Heartbeat=hb},TweenService={},VirtualInputManager={},HttpService={},TeleportService={TeleportInitFailed=signal()}}
local tweens={}
function services.TweenService:Create(o,info,props)
 local t={Object=o,Props=props,Duration=info[1]}
 function t:Play()self.Played=true;if info[4]~=-1 then for k,v in pairs(props)do o[k]=v end end end
 function t:Cancel()self.Cancelled=true end
 tweens[#tweens+1]=t;return t
end
input.MouseBehavior='LockCenter'
function input:GetFocusedTextBox()return self.FocusedBox end
function input:GetMouseLocation()return Vector2.new(40,50)end
function input:CreateVirtualInput()return self.Virtual end
local moves={}
function services.VirtualInputManager:SendMouseMoveEvent(x,y)moves[#moves+1]={X=x,Y=y}end
function services.VirtualInputManager:SendMouseButtonEvent(x,y,_,down)
 clicks[#clicks+1]=down;self.LastY=y
 if self.Fail and down then error('fixture: mouse denied')end
 if down and y==(self.ViewportOnly and 400 or 436) and not self.Silent then knock.Played:Fire() end
end
player.UserId=123
game={PlaceId=100,JobId='current-test-job',GetService=function(_,n)return assert(services[n],n)end}
task={spawn=function(fn)fn()end,wait=function()end}

local houses=Instance.new('Folder');houses.Name='Houses';houses.Parent=workspace;doorContainer.Parent=houses
local doors={door};door.CanTouch=true
for i=1,99 do
 local model=Instance.new('Model');model.Name='Door';model.Parent=houses
 local part=Instance.new('Part');part.Name='DoorInnerTouch';part.Size=Vector3.new(5,10,.2)
 part.CFrame=CFrame.new(i*10,5,i*3);part.CanTouch=true;part.Parent=model;doors[#doors+1]=part
end
for i=1,4000 do local junk=Instance.new('Folder');junk.Name='Decoration';junk.Parent=workspace end
services.RunService.PreSimulation=signal()
local files,objects={},{}
local function copy(t)if type(t)~='table'then return t end;local x={};for k,v in pairs(t)do x[k]=copy(v)end;return x end
function services.HttpService:JSONEncode(v)objects[#objects+1]=copy(v);return 'json:'..#objects end
function services.HttpService:JSONDecode(s)local i=tonumber(s:match('^json:(%d+)$'));return copy(assert(objects[i],'invalid json'))end
readfile=function(f)return assert(files[f],'missing')end
writefile=function(f,raw)files[f]=raw end
isfile=function(f)return files[f]~=nil end
local touchCalls={};local rejected;local activeApp;local reentered=false
firetouchinterest=function(source,target,state)
 eq(source,root)
 touchCalls[#touchCalls+1]={Door=target,State=state,At=time}
 if activeApp and not reentered then reentered=true;hb:Fire(.001)end
 if target==rejected and state==0 then return false end
end
local transfers=0;local queueCode;local destination='next-fast-job'
queue_on_teleport=function(code)queueCode=code end
request=function()return{StatusCode=200,Body=services.HttpService:JSONEncode({data={{id=destination,playing=1,maxPlayers=10}}})}end
function services.TeleportService:TeleportToPlaceInstance(_,job)eq(job,destination);transfers=transfers+1 end
local app=dofile('auto_candy.lua');activeApp=app
local function find(n)return assert(app.Gui:FindFirstChild(n,true),n)end
local function tick()time=time+1/30;hb:Fire(1/30)end
local original=root.CFrame
find('ServerHop').Activated:Fire();eq(app.Hopper.Enabled,true);eq(app.App.FastCycle,true)
tick();eq(app.App.FastStats.Attempted,1);eq(app.App.Busy,true)
eq(app:GetDiagnostics().IndexReady,false) -- first known door does not wait for full Workspace sweep
local frames=1
while transfers==0 and frames<120 do tick();frames=frames+1 end
eq(app.App.FastStats.Attempted,100);eq(app.App.FastStats.Dispatched,100);eq(app.App.FastStats.Failed,0)
eq(#touchCalls,200);eq(transfers,1);eq(type(queueCode),'string');eq(app.App.Busy,false)
eq(root.Position.X,original.Position.X);eq(root.Position.Z,original.Position.Z)
eq(#clicks,0);eq(#knock.Played.listeners,0);eq(app.App.Confirmed[door],nil)
local seen={}
for i=1,#touchCalls,2 do
 local begin,ending=touchCalls[i],touchCalls[i+1]
 eq(begin.State,0);eq(ending.State,1);eq(begin.Door,ending.Door);eq(seen[begin.Door],nil);seen[begin.Door]=true
 eq(ending.At-begin.At<=.5,true)
 if i>1 then eq(begin.At-touchCalls[i-2].At<=.5,true) end
end
eq(frames<=102,true);eq(reentered,true)
-- Run the actual queued loader and default fast bundle through three more servers.
loadstring=load;function game:IsLoaded()return true end
function game:HttpGet()local f=assert(io.open('auto_candy.lua','rb'));local raw=f:read('*a');f:close();return raw end
task.wait=function(dt)time=time+(dt or .01)end
for round=1,3 do
 local previous=app;local previousGui=app.Gui
 pg.Parent=nil;pg=Instance.new('PlayerGui');pg.Parent=player;game.JobId=destination
 assert(load(queueCode))();app=_G.SlapBattlesAutoCandy;activeApp=app
 eq(app~=previous,true);eq(app.Ready,true);eq(app.Gui.Parent,pg);eq(previousGui.Parent,nil)
 eq(app.App.FastCycle,true);eq(app.App.Auto,true);eq(app.Hopper.Enabled,true)
 eq(_G.AutoCandyResumeStatus.Phase,'ready');eq(app.Settings.Values.ServerHop,true)
 destination='fast-job-'..(round+1);local expectedTransfers=transfers+1;frames=0
 while transfers<expectedTransfers and frames<120 do tick();frames=frames+1 end
 eq(transfers,expectedTransfers);eq(app.App.FastStats.Dispatched,100);eq(app.App.FastStats.Failed,0)
 eq(frames<=102,true)
end
-- Manual action is also immediate, paired and restores origin.
find('ServerHop').Activated:Fire();find('Auto').Activated:Fire();eq(app.App.Auto,false)
local before=#touchCalls;find('Teleport').Activated:Fire();eq(#touchCalls,before+2);eq(app.App.Busy,false)
eq(root.Position.X,original.Position.X)
-- Stopping a multi-door route restores origin and leaves no held input/noclip.
app:Destroy();app=dofile('auto_candy.lua');activeApp=app
find('Auto').Activated:Fire();tick();eq(app.App.Busy,true)
input.InputBegan:Fire({UserInputType='Keyboard',KeyCode=Enum.KeyCode.T},false)
eq(app.App.Auto,false);eq(app.App.Busy,false);eq(root.Position.X,original.Position.X)
-- A refused touch is recorded as failed, not confirmed or infinitely retried.
app:Destroy();app=dofile('auto_candy.lua');activeApp=app
rejected=door;find('Auto').Activated:Fire()
for i=1,103 do tick()end
eq(app.App.FastStats.Attempted,100);eq(app.App.FastStats.Failed,1);eq(app.App.FastStats.Dispatched,99)
eq(app.App.Confirmed[door],nil);eq(app.App.RetryDoor,nil)
-- Missing API stops the route and cannot start a loop of empty server hops.
app:Destroy();firetouchinterest=nil;app=dofile('auto_candy.lua');activeApp=app
find('ServerHop').Activated:Fire();local beforeTransfers=transfers;tick()
eq(app.App.Auto,false);eq(app.Hopper.Enabled,false);eq(transfers,beforeTransfers)
eq(app.Settings.Values.Auto,true);eq(app.Settings.Values.ServerHop,true)
app:Destroy()
local active=0;for _,s in ipairs(signals)do for _,c in ipairs(s.listeners)do if c.Connected then active=active+1 end end end
eq(active,0);os.clock=realClock
print('PASS: '..count..' production fast-cycle dispatch, partial indexing, 100 doors, <=0.5s model cadence, no audio wait, reentry, stop, refusal and cleanup assertions')
