-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'multi hop #'..count..': '..tostring(a)..' ~= '..tostring(b))end
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

-- Shared globals/files intentionally survive all simulated servers, as they may in an executor.
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local files,objects={},{}
function services.HttpService:JSONEncode(v)objects[#objects+1]=copy(v);return 'json:'..#objects end
function services.HttpService:JSONDecode(s)local i=tonumber(s:match('^json:(%d+)$'));return copy(assert(objects[i],'invalid json'))end
readfile=function(f)return assert(files[f],'missing')end
writefile=function(f,s)files[f]=s end
isfile=function(f)return files[f]~=nil end
loadstring=load;warn=function()end
local f=assert(io.open('auto_candy.lua','rb'));local source=f:read('*a');f:close()
local downloads,requests=0,0;local destination='job-1';local queued={};local transfers={}
request=function()
 requests=requests+1
 return{StatusCode=200,Body=services.HttpService:JSONEncode({data={{id=destination,playing=1,maxPlayers=10}}})}
end
function game:IsLoaded()return true end
function game:HttpGet()downloads=downloads+1;return source end
function services.TeleportService:TeleportToPlaceInstance(place,job,p)
 eq(place,game.PlaceId);eq(p,player);transfers[#transfers+1]=job
end
queue_on_teleport=function(code)queued[#queued+1]=code end
task.wait=function(dt)time=time+(dt or .01)end
local loading=dofile('loader.lua');local app=loading.App
app.Gui:FindFirstChild('ServerHop',true).Activated:Fire()
eq(app.Hopper.Enabled,true);eq(app.Ready,true);eq(downloads,1)
local firstCode
for round=1,10 do
 destination='job-'..round
 local previous=app;local previousGui=app.Gui;local previousParent=previousGui.Parent
 app.Hopper:begin();eq(app.Hopper.Pending,true);eq(transfers[#transfers],destination)
 local stateFile=app.Hopper.StateFile
 local handoff=services.HttpService:JSONDecode(files[stateFile])
 eq(handoff.OwnerSession,app.SessionId);eq(handoff.ResumeJobId,destination)
 eq(type(handoff.ResumeToken),'string')
 local code=queued[#queued];if not firstCode then firstCode=code end
 -- Simulate a stale but syntactically valid settings snapshot in the executor bridge.
 if round==6 then
  local settingsFile=app.Settings.File
  local stale=services.HttpService:JSONDecode(files[settingsFile]);stale.Values.Auto=false;stale.Values.ServerHop=false
  files[settingsFile]=services.HttpService:JSONEncode(stale)
 end
 -- Keep the old GUI parent alive, but replace the actual current PlayerGui.
 previousParent.Parent=nil
 local newPlayerGui=Instance.new('PlayerGui');newPlayerGui.Parent=player
 game.JobId=destination
 eq(previousGui.Parent~=nil,true);eq(previousGui.Parent==newPlayerGui,false)
 assert(load(code))()
 app=_G.SlapBattlesAutoCandy
 eq(app~=previous,true);eq(app.JobId,destination);eq(app.Gui.Parent,newPlayerGui)
 eq(app.Ready,true);eq(app.Hopper.Enabled,true);eq(app.App.Auto,true)
 eq(previousGui.Parent,nil);eq(previous.Ready,false)
 local resumed=services.HttpService:JSONDecode(files[stateFile])
 eq(resumed.OwnerSession,app.SessionId);eq(resumed.Enabled,true)
 eq(_G.AutoCandyResumeStatus.Phase,'ready');eq(_G.AutoCandyResumeStatus.Token,handoff.ResumeToken)
 -- Late callbacks and old cleanup cannot disable or overwrite the new owner.
 local snapshot=files[stateFile]
 local saved=pcall(previous.Hopper.save,previous.Hopper,nil)
 eq(saved,false)
 previous.Hopper:failed('late error');previous.Hopper:step();previous:Destroy(false)
 eq(files[stateFile],snapshot);eq(app.Hopper.Enabled,true)
 assert(load(code))();eq(_G.SlapBattlesAutoCandy,app)
 eq(_G.AutoCandyLoading.Source,source) -- Bundle does not recursively grow on each hop.
 eq(downloads,1)
end
eq(requests,10);eq(#queued,10);eq(#transfers,10)
-- An old persisted queue entry cannot replace the active newest-server status or GUI.
assert(load(firstCode))();eq(_G.SlapBattlesAutoCandy,app);eq(app.Ready,true)
eq(_G.AutoCandyResumeStatus.Phase,'ready');eq(_G.AutoCandyResumeStatus.Target,'job-10')
-- Retrying a door is a distinct blocked state, not a failed bootstrap.
hb:Fire(.01);app.App:setAuto(false);app.App:setAuto(true)
app.App:scheduleRetry(door,false);time=time+.1;hb:Fire(.1)
eq(app.Hopper.Stage,'blocked');eq(app.Hopper.Reason,'Повтор той же двери')
local clipboard
setclipboard=function(text)clipboard=text end
app.Gui:FindFirstChild('CopyDiagnostics',true).Activated:Fire()
local report=services.HttpService:JSONDecode(clipboard)
eq(report.Job,'job-10');eq(report.CurrentGui,true);eq(report.Hop.Stage,'blocked')
eq(report.Hop.Reason,'Повтор той же двери');eq(report.Ready,true);eq(#report.Events<=50,true)
-- Repeated transient failures preserve the enabled mode with a longer backoff.
for _=1,6 do app.Hopper:failed('HTTP 429')end
eq(app.Hopper.Enabled,true);eq(app.Hopper.NextTry>=time+120,true)
-- Other account state has its own file and cannot cancel the current account.
local stateFile=app.Hopper.StateFile;local snapshot=files[stateFile]
local otherApp={setAuto=function()end}
local other=dofile('ServerHop.lua').new({App=otherApp,UserId=999,PlaceId=game.PlaceId,JobId='other',Log=function()end,
 Read=readfile,Write=writefile,Encode=function(v)return services.HttpService:JSONEncode(v)end,
 Decode=function(v)return services.HttpService:JSONDecode(v)end,Queue=function()end})
eq(other:setEnabled(true),true);eq(other.StateFile~=stateFile,true);other:Destroy(false)
eq(files[stateFile],snapshot)
-- Ownership does not expire just because the current app stayed on one server for ten minutes.
local oldSaved=services.HttpService:JSONDecode(files[stateFile]);oldSaved.SavedAt=os.time()-1000
files[stateFile]=services.HttpService:JSONEncode(oldSaved);snapshot=files[stateFile]
local unclaimed=dofile('ServerHop.lua').new({App=otherApp,UserId=player.UserId,PlaceId=game.PlaceId,JobId='stale',Log=function()end,
 Read=readfile,Write=writefile,Encode=function(v)return services.HttpService:JSONEncode(v)end,
 Decode=function(v)return services.HttpService:JSONDecode(v)end,Queue=function()end})
eq(unclaimed:setEnabled(false),false);eq(files[stateFile],snapshot)
app:Destroy()
local active=0;for _,s in ipairs(signals)do for _,c in ipairs(s.listeners)do if c.Connected then active=active+1 end end end
eq(active,0)
os.clock=realClock
print('PASS: '..count..' ten actual loader/bundle transitions, stale GUI/writers, diagnostics, backoff and isolation assertions')
