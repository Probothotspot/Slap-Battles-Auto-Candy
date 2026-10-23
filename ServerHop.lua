-- Resume requires executor-provided queue_on_teleport plus readfile/writefile.
-- Processed generations track bounded interactions/local feedback, not verified candy rewards.
local Hop={}
local serial=0
local HEADER="-- Auto Candy v1.6.2 |"
local FILE="AutoCandyHop-v1.json"
local URL="https://raw.githubusercontent.com/Probothotspot/Slap-Battles-Auto-Candy/main/loader.lua"
function Hop.choose(data,current,visited,now)
    local best
    for _,s in ipairs(type(data)=="table" and data or {}) do
        if type(s)=="table" and type(s.id)=="string" and #s.id>0 and #s.id<=128 and s.id~=current
            and type(s.playing)=="number" and type(s.maxPlayers)=="number"
            and s.playing>=0 and s.playing<s.maxPlayers
            and (not visited[s.id] or now-visited[s.id]>1800) then
            if not best or s.playing<best.playing then best=s end
        end
    end
    return best and best.id
end
function Hop.new(c)
    local clock=c.Clock or os.clock
    local epoch=c.Epoch or os.time
    local cacheFile="AutoCandyResume-v1.6.2-"..tostring(c.UserId)..".lua"
    local log=c.Log
    serial=serial+1
    local session=c.SessionId or (tostring(c.JobId)..":"..tostring(epoch())..":"..tostring(clock())..":"..serial)
    local stateFile="AutoCandyHop-v2-"..tostring(c.UserId).."-"..tostring(c.PlaceId)..".json"
    local self={Enabled=false,Pending=false,Searching=false,Generation=0,Failures=0,NextTry=0,Visited={},SessionId=session,StateFile=stateFile,Sequence=0,Stage="off"}
    local function valid(s)
        return type(s)=="table" and s.Schema==1 and s.PlaceId==c.PlaceId and s.UserId==c.UserId
            and type(s.SavedAt)=="number" and math.abs(epoch()-s.SavedAt)<600
    end
    local function loadState()
        if type(c.Read)~="function" then return nil end
        local ok,s=pcall(function() return c.Decode(c.Read(stateFile)) end)
        if not ok then ok,s=pcall(function() return c.Decode(c.Read(FILE)) end) end
        return ok and valid(s) and s or nil
    end
    local resume=loadState()
    if resume and type(resume.VisitedJobs)=="table" then
        local n=0
        for job,t in pairs(resume.VisitedJobs) do
            if n>=200 then break end
            if type(job)=="string" and #job<=128 and type(t)=="number" and epoch()-t<1800 then
                self.Visited[job]=t;n=n+1
            end
        end
    end
    self.ShouldResume=resume and resume.Enabled==true and resume.ResumeJobId==c.JobId or false
    function self:stage(name,reason)
        if self.Stage==name and self.Reason==reason then return end
        self.Stage=name;self.Reason=reason;self.StageSince=clock()
        if c.Observe then pcall(c.Observe,name,reason) end
    end
    function self:save(target,claim)
        assert(not c.Active or c.Active(),"Устаревший игровой контекст")
        local current
        if type(c.Read)=="function" then
            local ok,value=pcall(function()return c.Decode(c.Read(stateFile))end)
            if ok and type(value)=="table" and value.Schema==1 and value.UserId==c.UserId and value.PlaceId==c.PlaceId then current=value end
        end
        assert(claim or not current or not current.OwnerSession or current.OwnerSession==session,
            "Устаревшая сессия: состояние уже принадлежит другому запуску")
        local pruned={};local n=0
        for job,t in pairs(self.Visited) do
            if epoch()-t<1800 and n<199 then pruned[job]=t;n=n+1 end
        end
        pruned[c.JobId]=epoch();self.Visited=pruned
        local written=c.Write(stateFile,c.Encode({Schema=1,Enabled=self.Enabled,PlaceId=c.PlaceId,UserId=c.UserId,
            SavedAt=epoch(),ResumeJobId=target,ResumeToken=target and self.Token or nil,
            OwnerJobId=c.JobId,OwnerSession=session,VisitedJobs=pruned}))
        assert(written~=false,"writefile вернула false: состояние перехода не сохранено")
    end
    function self:setEnabled(value)
        if self.Destroyed or (c.Active and not c.Active()) then return false end
        self.Generation=self.Generation+1;self.Searching=false;self.QuietSince=nil
        c.App.HopMode=false
        if value then
            if type(c.Queue)~="function" or type(c.Read)~="function" or type(c.Write)~="function" then
                log("Смена серверов недоступна: нужны queue_on_teleport, readfile и writefile")
                return false
            end
            self.Enabled=true;self.StartedAt=clock();self.NextTry=0;self.Failures=0
        else self.Enabled=false;self.Pending=false;self.Target=nil end
        local ok,err=pcall(self.save,self,nil,value==true)
        if not ok then self.Enabled=false;log("Не удалось сохранить режим: "..tostring(err));return false end
        c.App.HopMode=self.Enabled
        self:stage(self.Enabled and "starting" or "off")
        if self.Enabled then c.App:setAuto(true) end
        log(self.Enabled and ("Смена серверов: ON | Очередь: "..tostring(c.QueueName or "queue_on_teleport")) or "Смена серверов: OFF")
        return true
    end
    function self:failed(reason,fatal)
        if self.Destroyed then return end
        self:stage("error",tostring(reason))
        self.Generation=self.Generation+1;self.Pending=false;self.Searching=false
        self.Failures=self.Failures+1;self.NextTry=clock()+math.min(60,10*2^(self.Failures-1))
        pcall(self.save,self,nil)
        log("Переход не выполнен: "..tostring(reason))
        if fatal or tostring(reason):find("writefile вернула false",1,true) then
            self:setEnabled(false);self:stage("error",tostring(reason))
            log("Автопереход остановлен: очередь или сохранение отказали")
        elseif self.Failures>=5 then
            self.NextTry=clock()+120
            log("Ошибки перехода: пауза 120 с, затем новая попытка. Режим остаётся включённым")
        end
    end
    local function payload(target)
        local code=[=[
local EXPECTED_PLACE,EXPECTED_USER,EXPECTED_JOB,EXPECTED_TOKEN=__PLACE__,__USER__,__JOB__,__TOKEN__
local STATE_FILE,CACHE_FILE,HEADER=__STATE__,__CACHE__,__HEADER__
local EMBEDDED_LOADER,LOADER_URL=__LOADER__,__URL__
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local function liveHere()
 local player=game:GetService('Players').LocalPlayer
 local live=env.SlapBattlesAutoCandy
 return player and type(live)=='table' and live.Ready==true and live.JobId==game.JobId and
  live.PlaceId==game.PlaceId and live.UserId==player.UserId and live.Gui and
  live.Gui.Parent==player:FindFirstChild('PlayerGui')
end
local workers=type(env.AutoCandyResumeWorkers)=='table' and env.AutoCandyResumeWorkers or {}
for token,item in pairs(workers)do
 if type(item)~='table' or item.Runtime~=game or os.clock()-(item.Updated or 0)>90 then workers[token]=nil end
end
env.AutoCandyResumeWorkers=workers
local current=workers[EXPECTED_TOKEN]
if current and ((current.Phase=='ready' and liveHere()) or
 ((current.Phase=='waiting' or current.Phase=='loading' or current.Phase=='retry') and os.clock()-current.Updated<90)) then return end
local status={Target=EXPECTED_JOB,Token=EXPECTED_TOKEN,Runtime=game,Phase='waiting',Started=os.clock(),Updated=os.clock(),Attempt=0}
workers[EXPECTED_TOKEN]=status
local old=env.AutoCandyResumeStatus
if type(old)~='table' or old.Runtime~=game then env.AutoCandyResumeStatus=status end
local function api(name)
 local direct={readfile=readfile,writefile=writefile,loadstring=loadstring}
 local fn=direct[name];if type(fn)=='function' then return fn end
 fn=env[name];if type(fn)=='function' then return fn end
 fn=_G[name];if type(fn)=='function' then return fn end
end
local function note(phase,detail)
 status.Phase=phase;status.Detail=detail;status.Updated=os.clock()
 if phase=='loading' or phase=='ready' or env.AutoCandyResumeStatus==status then env.AutoCandyResumeStatus=status end
 if env.AutoCandyResumeStatus~=status then return end
 local write=api('writefile')
 if write then pcall(function()
  write('AutoCandyResumeStatus-'..tostring(EXPECTED_USER)..'-'..tostring(EXPECTED_PLACE)..'.json',game:GetService('HttpService'):JSONEncode({
   Phase=phase,Detail=tostring(detail or ''),Target=EXPECTED_JOB,Token=EXPECTED_TOKEN,Attempt=status.Attempt,At=os.time()}))
 end) end
end
local function validState(loading)
 local read=api('readfile');if not read then return nil,'readfile not ready' end
 local ok,s=pcall(function()return game:GetService('HttpService'):JSONDecode(read(STATE_FILE))end)
 if not ok then return nil,'resume file not ready' end
 if type(s)~='table' or s.Schema~=1 or s.PlaceId~=EXPECTED_PLACE or s.UserId~=EXPECTED_USER or
  type(s.SavedAt)~='number' or math.abs(os.time()-s.SavedAt)>=600 then return false,'invalid or stale state' end
 if s.Enabled~=true then return false,'resume cancelled' end
 if s.ResumeJobId~=EXPECTED_JOB or s.ResumeToken~=EXPECTED_TOKEN then
  local live=env.SlapBattlesAutoCandy
  if not (loading and s.ResumeJobId==nil and liveHere() and live.Hopper and live.Hopper.Enabled and
   s.OwnerSession==live.SessionId) then return false,'destination/token changed' end
 end
 return true
end
local function fail(why)
 if env.AutoCandyResumeStatus==status then env.AutoCandyResumeBooted=nil end;note('error',tostring(why))
 warn('[AutoCandy resume] '..tostring(why))
end
local function run()
 note('waiting','waiting for destination runtime')
 local ready=false;local last='game/player/PlayerGui not ready'
 -- Queue handlers may run before LocalPlayer, JobId and the file bridge exist.
 -- Wait first; do not silently reject the destination during that startup window.
 while os.clock()-status.Started<60 do
  if workers[EXPECTED_TOKEN]~=status then return end
  status.Updated=os.clock()
  local players=game:GetService('Players');local player=players.LocalPlayer
  local loaded=game:IsLoaded()
  if loaded and player and player:FindFirstChild('PlayerGui') and game.JobId==EXPECTED_JOB and game.PlaceId==EXPECTED_PLACE then
   if player.UserId~=EXPECTED_USER then note('cancelled','different account');return end
   local permitted,why=validState();last=why
   if permitted==false and os.clock()-status.Started>=5 then note('cancelled',why);return end
   if permitted then ready=true;break end
  end
  task.wait(.2)
 end
 assert(ready,'Startup timeout: '..tostring(last))
 local live=env.SlapBattlesAutoCandy
 if liveHere() then
  env.AutoCandyResumeBooted=EXPECTED_JOB;note('ready','existing GUI');return
 end
 for attempt=1,3 do
  local allowed,why=validState()
  if allowed==false then note('cancelled',why);return end
  status.Attempt=attempt;note('loading','starting loader')
  local ok,result=pcall(function()
   assert(allowed,'resume state unavailable')
   -- A versioned local bundle avoids a second network dependency after teleport.
   env.AutoCandyResumeSource=nil
   local read=api('readfile')
   if read and attempt==1 then
    local cached,source=pcall(read,CACHE_FILE)
    if cached and type(source)=='string' and source:sub(1,#HEADER)==HEADER and #source<=2097152 then
     env.AutoCandyResumeSource={Job=EXPECTED_JOB,Source=source}
    end
   end
   local source=EMBEDDED_LOADER
   if source=='' then source=game:HttpGet(LOADER_URL) end
   local compile=api('loadstring') or loadstring
   assert(type(compile)=='function','loadstring unavailable')
   local chunk,problem=compile(source,'@AutoCandy/resume-loader');assert(chunk,problem)
   local report=chunk()
   assert(type(report)=='table','loader did not return a report')
   local began=os.clock()
   while report.State=='loading' and os.clock()-began<30 do
    status.Updated=os.clock()
    if workers[EXPECTED_TOKEN]~=status then return end
    local permitted,reason=validState(true)
    if permitted==false then
     if type(report.Destroy)=='function' then report:Destroy() end
     error('Resume cancelled: '..tostring(reason))
    end
    task.wait(.1)
   end
   if report.State~='ready' or not liveHere() or env.SlapBattlesAutoCandy~=report.App then
    local problem=report.Error or 'main GUI not ready'
    if type(report.Destroy)=='function' then report:Destroy() end
    error(problem)
   end
   return report
  end)
  env.AutoCandyResumeSource=nil
  if ok then env.AutoCandyResumeBooted=EXPECTED_JOB;note('ready','main GUI mounted');return end
  note('retry',tostring(result))
  if attempt==3 then error(result) end
  task.wait(2)
 end
end
local function worker()local ok,why=pcall(run);if not ok then fail(why)end end
if type(task)=='table' and type(task.spawn)=='function' then task.spawn(worker)
else fail('task.spawn unavailable after teleport')end
]=]
        local replacements={PLACE=tostring(c.PlaceId),USER=tostring(c.UserId),JOB=string.format('%q',target),
            TOKEN=string.format('%q',self.Token),STATE=string.format('%q',stateFile),CACHE=string.format('%q',cacheFile),HEADER=string.format('%q',HEADER),
            LOADER=string.format('%q',c.LoaderSource or Hop.LoaderSource or ''),URL=string.format('%q',URL)}
        return (code:gsub('__([A-Z]+)__',function(key)return assert(replacements[key],key)end))
    end
    function self:begin()
        if self.Destroyed or not self.Enabled or self.Pending or self.Searching then return end
        self:stage("searching")
        self.Searching=true;self.SearchStarted=clock();self.Generation=self.Generation+1
        local generation=self.Generation
        c.Spawn(function()
            local fatal=false
            local ok,err=pcall(function()
                local cursor,target=nil,nil
                for _=1,5 do
                    if not self.Enabled or generation~=self.Generation then return end
                    local url="https://games.roblox.com/v1/games/"..tostring(c.PlaceId)
                        .."/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
                    if cursor then url=url.."&cursor="..c.UrlEncode(cursor) end
                    local page=c.Decode(c.Get(url))
                    assert(type(page)=="table" and type(page.data)=="table","Некорректный список серверов")
                    target=Hop.choose(page.data,c.JobId,self.Visited,epoch())
                    if target then break end
                    cursor=page.nextPageCursor
                    if type(cursor)~="string" or cursor=="" then break end
                end
                if not self.Enabled or generation~=self.Generation then return end
                assert(target,"Свободный непосещённый сервер не найден")
                self.Sequence=self.Sequence+1;self.Token=session..":"..tostring(self.Sequence)
                self:save(target)
                self:stage("saved",target)
                if type(c.Source)=='string' and c.Source:sub(1,#HEADER)==HEADER then
                    local cached,problem=pcall(c.Write,cacheFile,c.Source)
                    cached=cached and problem~=false
                    log(cached and "Резервная копия для автозапуска сохранена" or ("Кэш автозапуска: "..tostring(problem)))
                end
                local queued=c.Queue(payload(target))
                if queued==false then fatal=true end
                assert(queued~=false,"queue_on_teleport вернула false: переход отменён")
                self:stage("queued",target)
                if type(c.Wait)=="function" then c.Wait(.3) end
                if not self.Enabled or generation~=self.Generation then return end
                self.Pending=true;self.Searching=false;self.PendingSince=clock();self.Target=target
                self.Visited[target]=epoch()
                log("Очередь приняла загрузчик: "..tostring(c.QueueName or "queue_on_teleport")..". Переход; выполнение проверяется на новом сервере")
                self:stage("teleporting",target)
                c.Teleport(target)
            end)
            if generation~=self.Generation then return end
            if not ok then self:failed(err,fatal) end
        end)
    end
    function self:step()
        if self.Destroyed or not self.Enabled then return end
        if not c.App.Auto then self:setEnabled(false);return end
        if self.Pending then
            if clock()-self.PendingSince>30 then self:failed("Таймаут телепорта") end
            return
        end
        if self.Searching then
            if clock()-self.SearchStarted>20 then self:failed("Таймаут списка серверов") end
            return
        end
        local blocked=c.App.RetryDoor and "Повтор той же двери" or c.App.Busy and "Взаимодействие с дверью" or
            c.App.PendingManual and "Задержка новой двери" or not c.Actions.Ready and "Индексация" or
            not c.Actions:body() and "Персонаж недоступен"
        if blocked then self:stage("blocked",blocked);self.QuietSince=nil;return end
        if clock()-self.StartedAt<20 or clock()<self.NextTry then self:stage("cooldown");return end
        local doors=c.Actions:doors()
        for _,door in ipairs(doors) do
            local processed
            if c.App.isProcessed then processed=c.App:isProcessed(door) else processed=c.App.Visited[door] end
            if not processed then self:stage("blocked","Остались необработанные двери");self.QuietSince=nil;return end
        end
        self:stage("quiet","Ожидание новых дверей: 10 с")
        if not self.QuietSince then self.QuietSince=clock();log("Дверей нет или все обработаны. Ожидание новых: 10 сек.") end
        if clock()-self.QuietSince>=10 then self:begin() end
    end
    function self:Destroy(preserve)
        if self.Destroyed then return end
        self.Destroyed=true;self.Generation=self.Generation+1;self.Searching=false
        if not preserve then self.Enabled=false;pcall(self.save,self,nil) end
    end
    return self
end
return Hop
