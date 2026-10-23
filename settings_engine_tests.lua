-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'settings engine #'..count..': '..tostring(a)..' ~= '..tostring(b))end
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

-- Token codec stores detached JSON-like values; each launch decodes a fresh table.
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local files,objects={},{};local writeCount=0
function services.HttpService:JSONEncode(v)objects[#objects+1]=copy(v);return 'json:'..#objects end
function services.HttpService:JSONDecode(s)local i=tonumber(s:match('^json:(%d+)$'));return copy(assert(objects[i],'invalid json'))end
readfile=function(f)return assert(files[f],'missing')end
writefile=function(f,s)files[f]=s;writeCount=writeCount+1 end
isfile=function(f)return files[f]~=nil end
queue_on_teleport=function()end
local app=dofile('auto_candy.lua')
local function find(n)return assert(app.Gui:FindFirstChild(n,true),n)end
local function tick(dt)time=time+dt;hb:Fire(dt)end
local function stopKey(k)input.InputBegan:Fire({UserInputType='Keyboard',KeyCode=k},false)end
eq(find('DoorDelay').Text,'1');eq(find('StopKey').Text,'T');eq(app.App.Auto,false)
eq(find('Window').Size.Y.Offset,510)
find('DoorDelay').Text='2,5';find('DoorDelay').FocusLost:Fire(true)
eq(app.App.NewDoorDelay,2.5);eq(find('DoorDelay').Text,'2.5')
local before=writeCount
for _,bad in ipairs({'-1','61','nan','inf','oops'})do
 find('DoorDelay').Text=bad;find('DoorDelay').FocusLost:Fire(true);eq(app.App.NewDoorDelay,2.5)
end
eq(writeCount,before)
find('StopKey').Text='f8';find('StopKey').FocusLost:Fire(true)
eq(app.Settings.Values.StopKey,'F8')
local pointer={UserInputType='MouseButton1',Position=Vector3.new(0,0,0)}
find('Resize').InputBegan:Fire(pointer)
input.InputChanged:Fire({UserInputType='MouseMovement',Position=Vector3.new(68,0,0)})
input.InputEnded:Fire(pointer);eq(app.Settings.Values.Scale,1.2)
find('Collapse').Activated:Fire();eq(app.Settings.Values.Collapsed,true)
find('Auto').Activated:Fire();eq(app.Settings.Values.Auto,true)
local previous=app
app=dofile('auto_candy.lua')
eq(previous.Gui.Parent,nil);eq(app.Settings.Loaded,true);eq(app.App.NewDoorDelay,2.5)
eq(find('DoorDelay').Text,'2.5');eq(find('StopKey').Text,'F8');eq(app.App.Auto,true)
eq(find('Window').Size.Y.Offset,46);eq(find('Body').Visible,false)
eq(find('Window'):FindFirstChildOfClass('UIScale').Scale,1.2)
stopKey(Enum.KeyCode.T);eq(app.App.Auto,true);stopKey(Enum.KeyCode.F8);eq(app.App.Auto,false)
-- Both modes survive a fresh launch and share the restored stop key.
find('Collapse').Activated:Fire();find('ServerHop').Activated:Fire()
eq(app.Hopper.Enabled,true);eq(app.Settings.Values.ServerHop,true);eq(app.Settings.Values.Auto,true)
app=dofile('auto_candy.lua');eq(app.Hopper.Enabled,true);eq(app.App.Auto,true);eq(find('StopKey').Text,'F8')
-- Reset cancels current work, persists defaults, and restores the expanded scale.
tick(.1);eq(app.App.Busy,true)
find('ResetDefaults').Activated:Fire()
eq(app.App.Busy,false);eq(app.App.Auto,false);eq(app.Hopper.Enabled,false)
eq(app.App.NewDoorDelay,1);eq(find('DoorDelay').Text,'1');eq(find('StopKey').Text,'T')
eq(find('Window'):FindFirstChildOfClass('UIScale').Scale,1);eq(find('Window').Size.Y.Offset,510)
eq(root.Position.X,20)
app=dofile('auto_candy.lua');eq(app.App.Auto,false);eq(app.Hopper.Enabled,false);eq(app.App.NewDoorDelay,1)
eq(find('StopKey').Text,'T');eq(app.Settings.Values.Collapsed,false);eq(app.Settings.Values.Scale,1)
-- Persistence failures leave the controls responsive and are visible in the log.
writefile=function()error('fixture write denied')end
app=dofile('auto_candy.lua');find('DoorDelay').Text='4';find('DoorDelay').FocusLost:Fire(true)
eq(app.App.NewDoorDelay,4)
eq(find('LogText').Text:find('Не удалось сохранить настройки',1,true)~=nil,true)
app:Destroy()
local active=0;for _,s in ipairs(signals)do for _,c in ipairs(s.listeners)do if c.Connected then active=active+1 end end end
eq(active,0)
os.clock=realClock
print('PASS: '..count..' actual GUI settings, reload, mode restoration, reset and cleanup assertions')
