local Actions=dofile('Actions.lua');local Core=dofile('Core.lua')
local n=0
local function eq(a,b)n=n+1;assert(a==b,'index #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local function signal()
 local s={listeners={}}
 function s:Connect(fn)local c={Disconnect=function()end};self.listeners[#self.listeners+1]=fn;return c end
 function s:Fire(o)for _,fn in ipairs(self.listeners)do fn(o)end end
 return s
end
local calls=0
local function node(name,parent,class)
 local o={Name=name,Parent=parent,Children={},Class=class or 'Folder'}
 function o:IsA(c)return c==self.Class or c=='BasePart'and self.Class=='Part'end
 function o:GetChildren()calls=calls+1;return self.Children end
 function o:GetDescendants()error('Whole-tree GetDescendants must never run')end
 function o:IsDescendantOf(w)local p=self.Parent;while p do if p==w then return true end;p=p.Parent end;return false end
 if parent then parent.Children[#parent.Children+1]=o end
 return o
end
local world=node('Workspace');world.DescendantAdded=signal();world.DescendantRemoving=signal()
local f=node('Door',world)
local door=node('DoorInnerTouch',f,'Part')
for i=1,3000 do node('Other'..i,world,'Part')end
local a=Actions.new({},world,Core,function(c)return c end,function()end,function()end)
eq(calls,0);eq(a.Ready,false)
a:serviceIndex();eq(a.Ready,false);eq(calls<=128,true)
local frames=1
while not a.Ready do
 local before=calls;a:serviceIndex();eq(calls-before<=128,true);frames=frames+1
 assert(frames<200)
end
eq(#a:doors(),1);eq(a:doors()[1],door)
local new=node('DoorInnerTouch',f,'Part');local before=calls
world.DescendantAdded:Fire(new);eq(calls,before);eq(a.Doors[new],nil)
a:serviceIndex();eq(a.Doors[new],true)
world.DescendantRemoving:Fire(new);new.Parent=nil;eq(a.Doors[new],nil)
a:Destroy();before=calls;a:serviceIndex();eq(calls,before);eq(#a.Stack,0)
print('PASS: '..n..' incremental-index budgeting, event and cleanup assertions over 3000 objects')
