local Hop=dofile('ServerHop.lua')
local n=0
local function eq(a,b) n=n+1;assert(a==b,'hop #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local now=0;local epoch=10000;local logs={};local stored;local queued={};local jobs={};local workers={};local requests=0
local page={data={{id='current',playing=1,maxPlayers=10},{id='full',playing=10,maxPlayers=10},
 {id='next',playing=2,maxPlayers=10},{id='other',playing=8,maxPlayers=10}}}
eq(Hop.choose(page.data,'current',{},epoch),'next')
eq(Hop.choose(page.data,'current',{next=epoch},epoch),'other')
eq(Hop.choose({{id='bad',playing=-1,maxPlayers=10}},'current',{},epoch),nil)
eq(Hop.choose(page.data,'current',{next=epoch-1801},epoch),'next')
local app={Auto=false,Busy=false,Visited={}}
function app:setAuto(v)self.Auto=v end
local actions={Ready=true,found={}}
function actions:body()return {}end
function actions:doors()return self.found end
local c={App=app,Actions=actions,PlaceId=10,JobId='current',UserId=123,Clock=function()return now end,Epoch=function()return epoch end,
 Log=function(s)logs[#logs+1]=s end,Read=function()if not stored then error('missing')end;return stored end,
 Write=function(_,v)stored=v end,Encode=function(v)return v end,Decode=function(v)return v end,
 Queue=function(code)queued[#queued+1]=code end,Get=function()requests=requests+1;return page end,
 Spawn=function(fn)fn()end,Teleport=function(job)jobs[#jobs+1]=job end,UrlEncode=function(v)return v end}
local h=Hop.new(c);eq(h.ShouldResume,false);eq(h:setEnabled(true),true);eq(app.Auto,true);eq(app.HopMode,true)
h:step();eq(#jobs,0);now=20;h:step();eq(#jobs,0);now=29;h:step();eq(#jobs,0)
now=30;h:step();eq(#jobs,1);eq(jobs[1],'next');eq(h.Pending,true);eq(#queued,1);eq(stored.ResumeJobId,'next');local firstToken=stored.ResumeToken
h:step();eq(#jobs,1)
-- A failed teleport clears the resume target, backs off and chooses another job.
h:failed('full since query');eq(h.Pending,false);eq(stored.ResumeJobId,nil);eq(h.Failures,1)
now=39;h:step();eq(#jobs,1);now=41;h:step();eq(jobs[2],'other');eq(stored.ResumeJobId,'other')
eq(h:setEnabled(false),true);eq(stored.Enabled,false);eq(app.HopMode,false);eq(h.Pending,false)
-- Unsupported executor cannot enable server hopping.
local previousQueue=c.Queue;c.Queue=nil;local unsupported=Hop.new(c)
eq(unsupported:setEnabled(true),false);eq(unsupported.Enabled,false);c.Queue=previousQueue
-- Presence of an unprocessed door blocks hopping until a completed click.
stored=nil;now=0;app.Auto=false;app.Visited={};local door={};actions.found={door}
h=Hop.new(c);h:setEnabled(true);now=40;h:step();eq(h.QuietSince,nil)
app.Visited[door]=true;h:step();eq(h.QuietSince,40);now=49;h:step();eq(h.Pending,false)
-- Newly loaded doors reset the quiet timer.
actions.found={door,{}};now=50;h:step();eq(h.QuietSince,nil)
actions.found={};now=51;h:step();eq(h.QuietSince,51)
-- Deferred network work is cancelled by mode-off and never queues/teleports.
c.Spawn=function(fn)workers[#workers+1]=fn end
now=62;h:step();eq(h.Searching,true);local before=#jobs
h:setEnabled(false);workers[#workers]();eq(#jobs,before)
-- A stale HTTP worker cannot act after a timeout.
now=0;h=Hop.new(c);h:setEnabled(true);now=20;h:step();now=31;h:step();eq(h.Searching,true)
now=52;h:step();eq(h.Searching,false);eq(h.Failures,1)
workers[#workers]();eq(#jobs,before)
-- Resume is restricted to user, place, target job and fresh state.
stored={Schema=1,Enabled=true,PlaceId=10,UserId=123,SavedAt=epoch,ResumeJobId='current',VisitedJobs={old=epoch}}
h=Hop.new(c);eq(h.ShouldResume,true);eq(h.Visited.old,epoch)
stored.UserId=456;eq(Hop.new(c).ShouldResume,false);stored.UserId=123
stored.SavedAt=epoch-601;eq(Hop.new(c).ShouldResume,false);stored.SavedAt=epoch
stored.ResumeJobId='wrong';eq(Hop.new(c).ShouldResume,false)
-- A false return is refusal even when the queue function did not throw.
c.Spawn=function(fn)fn()end
local originalQueue=c.Queue;c.Queue=function()return false end
local rejected=Hop.new(c);rejected:setEnabled(true);before=#jobs;rejected:begin()
eq(#jobs,before);eq(rejected.Pending,false);eq(rejected.Failures,1);eq(stored.ResumeJobId,nil)
c.Queue=originalQueue
-- A refused state write must not report a ready hop mode.
local originalWrite=c.Write;c.Write=function()return false end
local denied=Hop.new(c);eq(denied:setEnabled(true),false);eq(denied.Enabled,false)
c.Write=originalWrite
-- The actual queued program checks the persisted switch and avoids duplicate boot.
local code=queued[1];local boots=0
stored={Schema=1,Enabled=true,PlaceId=10,UserId=123,SavedAt=epoch,ResumeJobId='next',ResumeToken=firstToken}
local originalTime=os.time;os.time=function()return epoch end
readfile=function()return stored end
local playerGui={}
local player={UserId=123,FindFirstChild=function()return playerGui end}
game={PlaceId=10,JobId='next',GetService=function(_,name)
 if name=='Players'then return{LocalPlayer=player}end
 return{JSONDecode=function(_,v)return v end}
end,IsLoaded=function()return true end,HttpGet=function()return 'fixed loader fixture'end}
loadstring=function()return function()boots=boots+1;local report={State='ready',App={Ready=true,JobId='next',PlaceId=10,UserId=123,Gui={Parent=playerGui}}};_G.SlapBattlesAutoCandy=report.App;return report end end
local resumeClock=0;local originalClock=os.clock;os.clock=function()return resumeClock end
task={spawn=function(fn)fn()end,wait=function(dt)resumeClock=resumeClock+(dt or .1)end}
warn=function()end
assert(load(code))();eq(boots,1);assert(load(code))();eq(boots,1)
_G.AutoCandyResumeBooted=nil;_G.AutoCandyResumeStatus=nil;stored.Enabled=false;assert(load(code))();eq(boots,1)
stored.Enabled=true;_G.AutoCandyResumeStatus=nil;game.JobId='wrong';assert(load(code))();eq(boots,1)
os.time=originalTime;os.clock=originalClock
h:Destroy(false);eq(h.Destroyed,true);eq(stored.Enabled,false)
print('PASS: '..n..' server selection, quiet window, retries, resume gates and cancellation assertions')
