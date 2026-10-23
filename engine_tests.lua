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
RaycastParams={new=function()return{}end};OverlapParams={new=function()return{}end}
local methods,mt={},{}
Instance={new=function(class)return setmetatable({class=class,p={Name=class,Enabled=true,Visible=true},children={},signals={}},mt)end}
mt.__index=function(o,k)
 if methods[k]then return methods[k]end
 if k=='AbsoluteSize'then return{X=1000,Y=800}end
 if k=='Activated'or k=='InputBegan'or k=='InputChanged'or k=='InputEnded'or k=='WindowFocusReleased'or k=='Destroying'
 or k=='DescendantAdded'or k=='DescendantRemoving'or k=='MouseEnter'or k=='MouseLeave'or k=='Played'then
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
local app=dofile('auto_candy.lua');eq(app.Gui.Parent,pg);hb:Fire(.01)
local function find(n)return assert(app.Gui:FindFirstChild(n,true),n)end
local function tick(delta)time=time+delta;hb:Fire(delta)end
local original=root.CFrame;local originalCamera=camera.CFrame
tick(.31);eq(find('Window').GroupTransparency,0)
find('Collapse').Activated:Fire();tick(.27);eq(find('Body').Visible,false);eq(find('Window').Size.Y.Offset,46)
find('Collapse').Activated:Fire();tick(.27);eq(find('Body').Visible,true);eq(find('Window').Size.Y.Offset,402)
-- Rapid reversal must not let the previous collapse hide the reopened body.
find('Collapse').Activated:Fire();find('Collapse').Activated:Fire();tick(.27);eq(find('Body').Visible,true)
find('Teleport').MouseEnter:Fire();eq(find('Teleport'):FindFirstChildOfClass('UIScale').Scale,1.025)
find('Teleport').MouseLeave:Fire();eq(find('Teleport'):FindFirstChildOfClass('UIScale').Scale,1)
local pointer={UserInputType='MouseButton1',Position=Vector3.new(0,0,0)}
find('Resize').InputBegan:Fire(pointer)
input.InputChanged:Fire({UserInputType='MouseMovement',Position=Vector3.new(68,0,0)})
eq(find('Window'):FindFirstChildOfClass('UIScale').Scale,1.2)
input.InputEnded:Fire(pointer)
local function untilPhase(phase)
 for _=1,160 do if app.App.Phase==phase then return end;tick(.1)end
 error('phase timeout: '..phase..' from '..app.App.Phase)
end
local function finish()untilPhase('idle')end
find('Teleport').Activated:Fire();eq(app.App.Busy,true)
-- 2 studs away from the surface of the .2-thick door.
eq(math.abs(root.Position.Z),2.1)
tick(.36);eq(app.Gui.Enabled,false);eq(camera.CameraType,'Scriptable')
untilPhase('pressed');eq(clicks[1],true);eq(services.VirtualInputManager.LastY,436)
finish();eq(clicks[2],false);eq(app.App.Busy,false);eq(app.Gui.Enabled,true)
eq(app.App.Confirmed[door],true);eq(input.MouseBehavior,'LockCenter')
eq(moves[#moves].X,40);eq(moves[#moves].Y,50)
eq(root.Position.X,original.Position.X);eq(root.Position.Z,original.Position.Z)
eq(camera.CFrame,originalCamera);eq(camera.CameraType,'Custom')
-- A denied virtual click still restores the camera, UI and player.
services.VirtualInputManager.Fail=true
find('Teleport').Activated:Fire();finish()
eq(app.App.Busy,false);eq(app.Gui.Enabled,true);eq(root.Position.X,original.Position.X)
eq(camera.CFrame,originalCamera);eq(clicks[#clicks],false)
services.VirtualInputManager.Fail=false
-- A silently ignored screen click is retried with viewport coordinates.
services.VirtualInputManager.ViewportOnly=true
local before=#clicks
find('Teleport').Activated:Fire();finish()
eq(#clicks-before,4);eq(app.App.Confirmed[door],true)
-- Confirmed working backend is preferred on the next operation.
before=#clicks;find('Teleport').Activated:Fire();finish();eq(#clicks-before,2)
-- A valid alternate VirtualInput backend handles explicit VIM denial.
services.VirtualInputManager.Fail=true
input.Virtual={SendMousePosition=function()end,SendMouseButton=function(_,_,_,down) if down then knock.Played:Fire() end end}
find('Teleport').Activated:Fire();finish();eq(app.App.Confirmed[door],true)
input.Virtual=nil;services.VirtualInputManager.Fail=false
-- Direct activation is only offered when the selected door has a detector.
local detector=Instance.new('ClickDetector');detector.Parent=door
local detectorCalls=0
fireclickdetector=function(target)eq(target,detector);detectorCalls=detectorCalls+1;knock.Played:Fire()end
before=#clicks;find('Teleport').Activated:Fire();finish();eq(detectorCalls,1);eq(#clicks,before)
fireclickdetector=nil;detector:Destroy()
-- Closing while a click is held releases it and returns before destruction.
find('Teleport').Activated:Fire();untilPhase('pressed');eq(clicks[#clicks],true)
find('Close').Activated:Fire();eq(clicks[#clicks],false);eq(root.Position.X,original.Position.X)
eq(app.Gui.Parent,pg);tick(.24)
eq(_G.SlapBattlesAutoCandy,nil)
local active=0;for _,s in ipairs(signals)do for _,c in ipairs(s.listeners)do if c.Connected then active=active+1 end end end
eq(active,0)
-- Re-running the bundle removes its preceding session and has exactly two action buttons.
local first=dofile('auto_candy.lua');local second=dofile('auto_candy.lua')
eq(first.Gui.Parent,nil);eq(second.Gui.Parent,pg)
second:Destroy();eq(_G.SlapBattlesAutoCandy,nil)
for _,t in ipairs(tweens)do eq(t.Cancelled,true)end
os.clock=realClock
print('PASS: '..count..' actual bundle/GUI/geometry/input/return/cleanup assertions')
