local Core=dofile('Core.lua');local Actions=dofile('Actions.lua');local n=0
local function eq(a,b)n=n+1;assert(a==b,'door delay #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local time=0;local originalClock=os.clock;os.clock=function()return time end
local function signal()local s={};function s:Connect(f)self[#self+1]=f;return{Disconnect=function()end}end;function s:Fire(o)for _,f in ipairs(self)do f(o)end end;return s end
local function node(name,parent,class)
 local o={Name=name,Parent=parent,Children={},Class=class or 'Folder'}
 function o:IsA(c)return c==self.Class or c=='BasePart'and self.Class=='Part'end
 function o:GetChildren()return self.Children end
 function o:IsDescendantOf(w)local p=self.Parent;while p do if p==w then return true end;p=p.Parent end;return false end
 if parent then parent.Children[#parent.Children+1]=o end;return o
end
local world=node('Workspace');world.DescendantAdded=signal();world.DescendantRemoving=signal()
local folder=node('Door',world);local old=node('DoorInnerTouch',folder,'Part')
local index=Actions.new({},world,Core,function(c)return c end,function()end,function()end)
-- New door arrives during the initial sweep at time zero; it must not become exempt.
local fresh=node('DoorInnerTouch',folder,'Part');world.DescendantAdded:Fire(fresh)
while not index.Ready do index:serviceIndex()end
eq(index:waitRemaining(old,10),0);eq(index:waitRemaining(fresh,1),1)
time=.4;eq(index:waitRemaining(fresh,1),.6);time=1;eq(index:waitRemaining(fresh,1),0)
local revision=index.Revision
world.DescendantRemoving:Fire(old);time=2;world.DescendantAdded:Fire(old);index:serviceIndex()
eq(index:generation(old),2);eq(index:waitRemaining(old,1),1);eq(index.Revision,revision+1)
time=4;local late=node('Part',folder,'Part');world.DescendantAdded:Fire(late)
time=5;late.Name='DoorInnerTouch';time=6;index:serviceIndex();while #index.Stack>0 do index:serviceIndex()end
eq(index:waitRemaining(late,3),1) -- Timestamp survives late naming and indexing.
index:Destroy()
local function setup()
 local a={Ready=true,Found={},Born={},Generations={},Revision=0,Captures=0,Returns=0,Sent=0,Silent=true}
 function a:doors()return self.Found end
 function a:generation(d)return self.Generations[d]or 1 end
 function a:waitRemaining(d,delay,now)return self.Born[d]and math.max(0,self.Born[d]+delay-now)or 0 end
 function a:distance(d)return d.Distance end
 function a:capture()self.Captures=self.Captures+1;return{}end
 function a:approach()if self.FailMove then error('blocked')end end
 function a:valid()return true end
 function a:aim()end
 function a:beginFeedback()return 1 end
 function a:prepareClick()return 'fixture'end
 function a:mouseDown(ctx)ctx.Sent=true;self.Sent=self.Sent+1 end
 function a:mouseUp()end
 function a:feedback(ctx)if ctx.Sent and not self.Silent then return{Name='Knock',Id='test'}end end
 function a:confirmed()end
 function a:restore()self.Returns=self.Returns+1 end
 local app=Core.new(a,function()return time end,function()end)
 local function tick(dt)time=time+dt;app:step()end
 local function complete()for _=1,150 do if not app.Busy then return end;tick(.05)end;error('attempt did not finish')end
 return a,app,tick,complete
end
local a,app,tick,complete=setup();local door={Distance=1};a.Found={door};a.Born[door]=time
app:setAuto(true);app:step();eq(app.Busy,false);eq(a.Captures,0)
tick(.99);eq(a.Captures,0);tick(.02);eq(a.Captures,1);eq(app.Door,door)
complete();eq(app.Busy,false);eq(app:isProcessed(door),false);eq(app.RetryDoor,door)
local deadline=app.RetryAt;eq(deadline,time+3)
local other={Distance=.01};a.Found={other,door};a.Revision=a.Revision+1
tick(2.99);eq(a.Captures,1);tick(.02);eq(app.Door,door);eq(a.Captures,2)
a.Silent=false;complete();eq(app:isProcessed(door),true);eq(app.RetryDoor,nil)
app:setAuto(false)
-- Manual interaction waits too, without enabling auto or moving before the deadline.
a,app,tick,complete=setup();a.Found={door};a.Born[door]=time
app.NewDoorDelay=2;eq(app:attempt(true),false);eq(app.PendingManual,true);eq(a.Captures,0)
tick(1);eq(a.Captures,0);app.NewDoorDelay=.5;app.NextScan=0;tick(.05);eq(a.Captures,1)
complete();eq(app.Auto,false);eq(app.RetryDoor,door);tick(3);eq(a.Captures,2)
app:setAuto(false);eq(app.RetryDoor,nil);eq(app.PendingManual,false);eq(app.Busy,false)
tick(10);eq(a.Captures,2)
-- Old doors stay immediate even with a large configured delay.
a,app,tick,complete=setup();a.Found={door};app.NewDoorDelay=60
eq(app:attempt(true),true);app:setAuto(false)
-- Removed or regenerated targets cancel a scheduled retry instead of targeting another door.
a,app,tick,complete=setup();a.Found={door};app:attempt(true);complete()
a.Found={other};tick(.1);eq(app.RetryDoor,nil);eq(a.Captures,1);tick(3);eq(a.Captures,1)
a.Found={door};app:attempt(true);complete();a.Generations[door]=2;tick(.1);eq(app.RetryDoor,nil)
-- Approach failures retry after the same three-second interval.
a,app,tick,complete=setup();a.Found={door};a.FailMove=true
eq(app:attempt(true),false);eq(a.Returns,1);eq(app.RetryDoor,door)
tick(2.99);eq(a.Captures,1);a.FailMove=false;tick(.02);eq(a.Captures,2);eq(app.Busy,true)
app:Destroy();eq(app.RetryDoor,nil)
-- A door introduced during passive waiting wakes the scheduler, then respects its age.
a,app,tick,complete=setup();app:setAuto(true);app:step();eq(app.Waiting,true)
a.Found={door};a.Born[door]=time;a.Revision=a.Revision+1;tick(.1)
eq(a.Captures,0);tick(.89);eq(a.Captures,0);tick(.02);eq(a.Captures,1)
app:setAuto(false)
-- Stop while waiting must cancel even a manual delayed operation.
a,app,tick,complete=setup();a.Found={door};a.Born[door]=time
app:attempt(true);eq(app.PendingManual,true);app:setAuto(false);tick(5);eq(a.Captures,0)
-- Turning auto on after a new door has already aged needs no additional wait.
a,app,tick,complete=setup();a.Found={door};a.Born[door]=time-10;app:setAuto(true);app:step();eq(a.Captures,1)
app:setAuto(false)
-- Zero configured delay is immediate even for a freshly indexed object.
a,app,tick,complete=setup();a.Found={door};a.Born[door]=time;app.NewDoorDelay=0
eq(app:attempt(true),true);app:setAuto(false)
-- A temporarily missing avatar does not lose the retry target.
a,app,tick,complete=setup();a.Found={door};app:attempt(true);complete()
local distance=a.distance;a.distance=function()return nil end
tick(3);eq(app.RetryDoor,door);eq(a.Captures,1)
a.distance=distance;tick(3);eq(a.Captures,2);app:Destroy()
os.clock=originalClock
print('PASS: '..n..' door-age exemptions, configurable delay, exact-target retries and cancellation assertions')
