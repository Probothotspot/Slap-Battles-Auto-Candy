-- Execute the real generated queue program with delayed game/file-bridge readiness.
local Hop=dofile('ServerHop.lua');local n=0
local function eq(a,b)n=n+1;assert(a==b,'resume #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local epoch=10000;local clock=0;local originalClock,originalTime=os.clock,os.time
os.clock=function()return clock end;os.time=function()return epoch end
local stored={};local code;local jobs=0;local logs={}
local app={Auto=false};function app:setAuto(v)self.Auto=v end
local source='-- Auto Candy v1.6.3 | fixture cached bundle'
local c={App=app,PlaceId=10,UserId=123,JobId='old',Actions={},LoaderSource='embedded loader fixture',Source=source,
 Log=function(s)logs[#logs+1]=s end,Spawn=function(fn)fn()end,Read=function(f)return stored[f]end,
 Write=function(f,v)stored[f]=v end,Encode=function(v)return v end,Decode=function(v)return v end,
 Queue=function(v)code=v end,Get=function()return{data={{id='next',playing=1,maxPlayers=10}}}end,
 UrlEncode=function(v)return v end,Teleport=function()jobs=jobs+1 end}
local h=Hop.new(c);eq(h:setEnabled(true),true);h:begin();eq(jobs,1);eq(h.Pending,true)
eq(stored['AutoCandyResume-v1.6.3-123.lua'],source)
local state=stored[h.StateFile]
local function copy(t)local o={};for k,v in pairs(t)do o[k]=v end;return o end
local function scenario(o)
 o=o or {};clock=0
 local s=copy(state);local calls,downloads,destroyed=0,0,0
 local workers,warnings={},{};local env={};local reports={};local cacheSeen={};local readyTimes={}
 getgenv=function()return env end
 local playerGui={}
 local player={UserId=o.wrongUser and 999 or 123}
 function player:FindFirstChild()if clock>=(o.guiAt or 0)then return playerGui end end
 local players=setmetatable({},{__index=function(_,k)if k=='LocalPlayer' and clock>=(o.playerAt or 0)then return player end end})
 local g={}
 function g:GetService(name)if name=='Players'then return players end;return{JSONDecode=function(_,v)return v end,JSONEncode=function(_,v)return v end}end
 function g:IsLoaded()return clock>=(o.loadedAt or 0)end
 function g:HttpGet()downloads=downloads+1;return 'network loader fixture'end
 game=setmetatable(g,{__index=function(_,k)
  if k=='PlaceId'then return 10 end
  if k=='JobId'then return clock>=(o.jobAt or 0)and 'next'or 'old'end
 end})
 local function read(f)
  assert(clock>=5,'file bridge called before startup grace')
  if clock<(o.fileAt or 0)then error('bridge not synchronized')end
  if f==h.StateFile then
   if o.staleUntil and clock<o.staleUntil then local stale=copy(s);stale.ResumeJobId=nil;return stale end
   return s
  end
  if f=='AutoCandyResume-v1.6.3-123.lua'then return o.badCache and '-- old build' or source end
  error('missing')
 end
 readfile=o.envOnly and nil or read;env.readfile=read
 writefile=nil;loadstring=function(text)
  eq(text,'embedded loader fixture') -- No loader HTTP request is needed.
  return function()
   calls=calls+1;cacheSeen[calls]=env.AutoCandyResumeSource and env.AutoCandyResumeSource.Source or false
   if calls<=(o.failures or 0)then return{State='error',Error='fixture HTTP failure',Destroy=function()destroyed=destroyed+1 end}end
   local report={State=o.slow and 'loading'or 'ready',App={Ready=true,JobId='next',PlaceId=10,UserId=123,SessionId='new-session',Gui={Parent=playerGui},Hopper={Enabled=true}}}
   function report:Destroy()destroyed=destroyed+1;self.Destroyed=true end
   env.SlapBattlesAutoCandy=report.App;reports[#reports+1]=report;readyTimes[report]=clock+.5
   return report
  end
 end
 warn=function(s)warnings[#warnings+1]=s end
 task={spawn=function(fn)workers[#workers+1]=fn end,wait=function(dt)
  clock=clock+(dt or .1)
  for _,report in ipairs(reports)do
   -- Main.setEnabled saves the consumed destination before loader.State becomes ready.
   if o.consume and clock>=readyTimes[report]-.3 then s.ResumeJobId=nil;s.OwnerSession='new-session';s.OwnerJobId='next';s.AcceptedResumeToken=s.ResumeToken end
   if o.cancel and clock>=readyTimes[report]-.3 then s.Enabled=false end
   if clock>=readyTimes[report] and not report.Destroyed then report.State='ready' end
  end
 end}
 if o.oldGui then env.SlapBattlesAutoCandy={Ready=true,JobId=o.wrongRoot and 'next'or 'old',PlaceId=10,UserId=123,Gui={Parent={}}} end
 if o.oldWorker then env.AutoCandyResumeWorkers={[s.ResumeToken]={Runtime=game,Phase=o.deadWorker and 'waiting'or 'ready',Updated=o.deadWorker and -100 or clock}} end
 if o.wrongToken then s.ResumeToken='stale-token' end
 if o.alreadyConsumed then
  s.AcceptedResumeToken=s.ResumeToken;s.ResumeJobId=nil;s.OwnerSession='mounted-session';s.OwnerJobId='next'
  env.SlapBattlesAutoCandy={Ready=true,JobId='next',PlaceId=10,UserId=123,SessionId='mounted-session',Gui={Parent=playerGui},Hopper={Enabled=true}}
 end
 if o.disabled then s.Enabled=false end
 if o.stale then s.SavedAt=epoch-601 end
 assert(load(code))();assert(load(code))();eq(#workers,1) -- Duplicate queue entries share one worker.
 workers[1]()
 local status=env.AutoCandyResumeStatus
 return {Status=status,Calls=calls,Downloads=downloads,Destroyed=destroyed,Warnings=warnings,Cache=cacheSeen,Env=env,At=clock}
end
local r=scenario({loadedAt=1,playerAt=2,guiAt=2.5,jobAt=1.5,fileAt=3,staleUntil=4,envOnly=true,slow=true,consume=true})
eq(r.Status.Phase,'ready');eq(r.Calls,1);eq(r.Downloads,0);eq(r.Cache[1],source)
eq(r.At>=4.5,true);eq(r.Env.AutoCandyResumeBooted,'next');eq(r.Env.AutoCandyResumeSource,nil)
r=scenario({failures=1});eq(r.Status.Phase,'ready');eq(r.Calls,2);eq(r.Destroyed,1);eq(r.Cache[1],source);eq(r.Cache[2],false)
r=scenario({failures=3});eq(r.Status.Phase,'error');eq(r.Calls,3);eq(r.Destroyed,3);eq(#r.Warnings,1);eq(r.Env.AutoCandyResumeBooted,nil)
r=scenario({disabled=true});eq(r.Status.Phase,'cancelled');eq(r.Calls,0)
r=scenario({stale=true});eq(r.Status.Phase,'cancelled');eq(r.Calls,0)
r=scenario({wrongUser=true});eq(r.Status.Phase,'cancelled');eq(r.Calls,0)
r=scenario({fileAt=100});eq(r.Status.Phase,'error');eq(r.Calls,0);eq(r.At>=60,true)
r=scenario({badCache=true});eq(r.Status.Phase,'ready');eq(r.Cache[1],false)
r=scenario({slow=true,cancel=true});eq(r.Status.Phase,'cancelled');eq(r.Destroyed,1);eq(r.Env.AutoCandyResumeBooted,nil)
r=scenario({oldGui=true,oldWorker=true});eq(r.Status.Phase,'ready');eq(r.Calls,1)
r=scenario({oldGui=true,wrongRoot=true,oldWorker=true});eq(r.Status.Phase,'ready');eq(r.Calls,1)
r=scenario({oldWorker=true,deadWorker=true});eq(r.Status.Phase,'ready');eq(r.Calls,1)
r=scenario({wrongToken=true});eq(r.Status.Phase,'cancelled');eq(r.Calls,0)
r=scenario({alreadyConsumed=true});eq(r.Status.Phase,'ready');eq(r.Calls,0);eq(r.Status.Detail,'existing GUI')
os.clock=originalClock;os.time=originalTime
print('PASS: '..n..' real queued bootstrap readiness, delayed bridge, cache, retry, cancellation and deduplication assertions')
