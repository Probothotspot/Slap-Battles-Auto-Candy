-- Resume requires executor-provided queue_on_teleport plus readfile/writefile.
-- A door is "processed" after a click was sent, not after a verified candy reward.
local Hop={}
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
    local log=c.Log
    local self={Enabled=false,Pending=false,Searching=false,Generation=0,Failures=0,NextTry=0,Visited={}}
    local function valid(s)
        return type(s)=="table" and s.Schema==1 and s.PlaceId==c.PlaceId and s.UserId==c.UserId
            and type(s.SavedAt)=="number" and math.abs(epoch()-s.SavedAt)<600
    end
    local function loadState()
        if type(c.Read)~="function" then return nil end
        local ok,s=pcall(function() return c.Decode(c.Read(FILE)) end)
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
    function self:save(target)
        local pruned={};local n=0
        for job,t in pairs(self.Visited) do
            if epoch()-t<1800 and n<199 then pruned[job]=t;n=n+1 end
        end
        pruned[c.JobId]=epoch();self.Visited=pruned
        c.Write(FILE,c.Encode({Schema=1,Enabled=self.Enabled,PlaceId=c.PlaceId,UserId=c.UserId,
            SavedAt=epoch(),ResumeJobId=target,VisitedJobs=pruned}))
    end
    function self:setEnabled(value)
        self.Generation=self.Generation+1;self.Searching=false;self.QuietSince=nil
        c.App.HopMode=false
        if value then
            if type(c.Queue)~="function" or type(c.Read)~="function" or type(c.Write)~="function" then
                log("Смена серверов недоступна: нужны queue_on_teleport, readfile и writefile")
                return false
            end
            self.Enabled=true;self.StartedAt=clock();self.NextTry=0;self.Failures=0
        else self.Enabled=false;self.Pending=false;self.Target=nil end
        local ok,err=pcall(self.save,self,nil)
        if not ok then self.Enabled=false;log("Не удалось сохранить режим: "..tostring(err));return false end
        c.App.HopMode=self.Enabled
        if self.Enabled then c.App:setAuto(true) end
        log(self.Enabled and "Смена серверов: ON. Двери обрабатываются один раз на сервер" or "Смена серверов: OFF")
        return true
    end
    function self:failed(reason)
        self.Generation=self.Generation+1;self.Pending=false;self.Searching=false
        self.Failures=self.Failures+1;self.NextTry=clock()+math.min(60,10*2^(self.Failures-1))
        pcall(self.save,self,nil)
        log("Переход не выполнен: "..tostring(reason))
        if self.Failures>=5 then self:setEnabled(false);log("Пять ошибок подряд — режим остановлен") end
    end
    local function payload()
        return string.format([=[
local ok,err=pcall(function()
 if type(readfile)~="function" then return end
 local state=game:GetService("HttpService"):JSONDecode(readfile(%q))
 local player=game:GetService("Players").LocalPlayer
 if not player or type(state)~="table" or state.Schema~=1 or state.Enabled~=true
  or state.PlaceId~=game.PlaceId or state.UserId~=player.UserId or state.ResumeJobId~=game.JobId
  or type(state.SavedAt)~="number" or math.abs(os.time()-state.SavedAt)>=600 then return end
 local env=type(getgenv)=="function" and getgenv() or _G
 if env.AutoCandyResumeBooted==game.JobId then return end
 env.AutoCandyResumeBooted=game.JobId
 local loaded,problem=pcall(function()
  if not game:IsLoaded() then game.Loaded:Wait() end
  local source=game:HttpGet(%q)
  local chunk,compileError=loadstring(source,"@AutoCandy/resume")
  assert(chunk,compileError);chunk()
 end)
 if not loaded then env.AutoCandyResumeBooted=nil;error(problem) end
end)
if not ok then warn("[AutoCandy resume] "..tostring(err)) end
]=],FILE,URL)
    end
    function self:begin()
        if not self.Enabled or self.Pending or self.Searching then return end
        self.Searching=true;self.SearchStarted=clock();self.Generation=self.Generation+1
        local generation=self.Generation
        c.Spawn(function()
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
                self:save(target)
                c.Queue(payload())
                if not self.Enabled or generation~=self.Generation then return end
                self.Pending=true;self.Searching=false;self.PendingSince=clock();self.Target=target
                self.Visited[target]=epoch()
                log("Переход на другой сервер. Автозапуск поставлен в очередь")
                c.Teleport(target)
            end)
            if generation~=self.Generation then return end
            if not ok then self:failed(err) end
        end)
    end
    function self:step()
        if not self.Enabled then return end
        if not c.App.Auto then self:setEnabled(false);return end
        if self.Pending then
            if clock()-self.PendingSince>30 then self:failed("Таймаут телепорта") end
            return
        end
        if self.Searching then
            if clock()-self.SearchStarted>20 then self:failed("Таймаут списка серверов") end
            return
        end
        if c.App.Busy or not c.Actions.Ready or not c.Actions:body() then self.QuietSince=nil;return end
        if clock()-self.StartedAt<20 or clock()<self.NextTry then return end
        local doors=c.Actions:doors()
        for _,door in ipairs(doors) do
            if not c.App.Visited[door] then self.QuietSince=nil;return end
        end
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
