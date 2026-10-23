-- Bundled by build.py into auto_candy.lua; no runtime module dependencies.
local Main={}
function Main.start(Core,Actions,Gui,ServerHop,Feedback,Settings,FastCycle)
    local players=game:GetService("Players")
    local player=players.LocalPlayer;assert(player,"Auto Candy requires a client player")
    local env=_G
    if type(getgenv)=="function" then local ok,v=pcall(getgenv);if ok and type(v)=="table" then env=v end end
    -- The production window takes over from older diagnostic windows and input.
    for _,diagnostic in ipairs({"AutoCandyMethodTest","AutoCandyPixelTest"}) do
        local old=env[diagnostic]
        if type(old)=="table" and type(old.Destroy)=="function" then old:Destroy() end
    end
    local key="SlapBattlesAutoCandy"
    if type(env[key])=="table" and type(env[key].Destroy)=="function" then env[key]:Destroy(env[key].JobId~=nil and env[key].JobId~=game.JobId) end
    local connections={};local app,view,actions,hopper,settings;local destroyed=false
    local function register(c) connections[#connections+1]=c;return c end
    local handle={Version="1.6.3",JobId=game.JobId,PlaceId=game.PlaceId,UserId=player.UserId,Ready=false}
    handle.SessionId=tostring(handle.JobId)..":"..tostring(os.clock())..":"..tostring({})
    local function dispose(preserve)
        if destroyed then return end;destroyed=true;handle.Ready=false
        if hopper then hopper:Destroy(preserve==true) end
        if app then app:Destroy() end
        if actions then actions:Destroy() end
        for _,c in ipairs(connections) do c:Disconnect() end
        if view then view:Destroy() end
        if env[key]==handle then env[key]=nil end
    end
    function handle:Destroy(preserve) dispose(preserve==true and handle.JobId~=game.JobId) end
    env[key]=handle
    local ok,err=pcall(function()
        view=Gui.mount(player,register,{Hotkey=true})
        local http=game:GetService("HttpService")
        local guidOK,guid=pcall(function()return http:GenerateGUID(false)end)
        if guidOK and type(guid)=="string" then handle.SessionId=guid end
        settings=Settings.new({UserId=player.UserId,Active=function()return not destroyed and env[key]==handle and game.JobId==handle.JobId end,Read=type(readfile)=="function" and readfile or env.readfile,
            Write=type(writefile)=="function" and writefile or env.writefile,IsFile=isfile or env.isfile,
            Encode=function(v) return http:JSONEncode(v) end,Decode=function(v) return http:JSONDecode(v) end,
            Log=function(s) view:log(s) end})
        handle.Settings=settings
        view:applyPreferences(settings.Values)
        view.OnPreferencesChanged=function()
            if not destroyed and env[key]==handle and game.JobId==handle.JobId then settings:set(view:preferences()) end
        end
        actions=Actions.new(player,workspace,Core,register,function(s) view:log(s) end,function(show) view:clickVisibility(show) end,Feedback)
        app=Core.new(actions,os.clock,function(s) view:log(s) end)
        local fast=env.AutoCandyFastCycle
        if fast==nil then fast=_G.AutoCandyFastCycle end
        if fast~=false then
            actions:enableFastIndex();FastCycle.attach(app,actions,os.clock,function(s)view:log(s)end)
            view:log("Быстрый цикл: одна дверь за кадр; без ожидания звука и подтверждения награды")
        end
        handle.App=app;handle.Gui=view.Gui
        app.NewDoorDelay=settings.Values.DoorDelay
        view.DoorDelay.Text=tostring(app.NewDoorDelay)
        local teleport=game:GetService("TeleportService")
        local queue,queueName
        local function candidate(fn,name)
            if not queue and type(fn)=="function" then queue,queueName=fn,name end
        end
        candidate(queue_on_teleport,"queue_on_teleport");candidate(queueonteleport,"queueonteleport")
        candidate(env.queue_on_teleport,"getgenv().queue_on_teleport");candidate(env.queueonteleport,"getgenv().queueonteleport")
        local directNamespaces={syn=syn,fluxus=fluxus}
        for _,namespace in ipairs({"syn","fluxus"}) do
            local space=directNamespaces[namespace]
            if type(space)~="table" then space=type(env[namespace])=="table" and env[namespace] or _G[namespace] end
            if type(space)=="table" then
                candidate(space.queue_on_teleport,namespace..".queue_on_teleport")
                candidate(space.queueonteleport,namespace..".queueonteleport")
            end
        end
        local read=type(readfile)=="function" and readfile or env.readfile
        local write=type(writefile)=="function" and writefile or env.writefile
        local loading=env.AutoCandyLoading
        local send=request or http_request or (type(syn)=="table" and syn.request)
        local traceFile="AutoCandyTrace-"..tostring(player.UserId).."-"..tostring(game.PlaceId)..".json"
        local events={}
        if type(read)=="function" then
            local good,old=pcall(function() return http:JSONDecode(read(traceFile)) end)
            if good and type(old)=="table" and type(old.Events)=="table" then
                for i=math.max(1,#old.Events-39),#old.Events do
                    local e=old.Events[i]
                    if type(e)=="table" and type(e.Stage)=="string" and type(e.Job)=="string" then
                        events[#events+1]={Stage=e.Stage:sub(1,64),Job=e.Job:sub(1,128),At=tonumber(e.At),Detail=tostring(e.Detail or ""):sub(1,512)}
                    end
                end
            end
        end
        local function observe(stage,detail)
            if env[key]~=handle or game.JobId~=handle.JobId then return end
            events[#events+1]={Stage=stage,Detail=tostring(detail or ""):sub(1,512),Job=handle.JobId,At=os.time()}
            if #events>50 then table.remove(events,1) end
            if type(write)=="function" then pcall(function() write(traceFile,http:JSONEncode({Events=events})) end) end
        end
        hopper=ServerHop.new({App=app,Actions=actions,Fast=app.FastCycle==true,PlaceId=game.PlaceId,JobId=game.JobId,UserId=player.UserId,
            Log=function(s) view:log(s) end,Queue=queue,QueueName=queueName,Read=read,Write=write,Spawn=task.spawn,Wait=task.wait,
            Source=type(loading)=="table" and loading.Source or nil,SessionId=handle.SessionId,Observe=observe,
            Active=function()return env[key]==handle and game.JobId==handle.JobId end,
            Encode=function(v) return http:JSONEncode(v) end,Decode=function(v) return http:JSONDecode(v) end,
            UrlEncode=function(v) return http:UrlEncode(v) end,
            Get=function(url)
                if type(send)=="function" then
                    local response=send({Url=url,Method="GET",Timeout=12})
                    assert(type(response)=="table" and response.StatusCode==200,
                        "HTTP "..tostring(type(response)=="table" and response.StatusCode or "нет ответа"))
                    return response.Body
                end
                return game:HttpGet(url)
            end,
            Teleport=function(job) teleport:TeleportToPlaceInstance(game.PlaceId,job,player) end,
        })
        handle.Hopper=hopper
        view:log(queueName and ("Автозапуск: найдена очередь "..queueName.."; выполнение после ТП ещё не подтверждено") or
            "Автозапуск: очередь перехода не найдена")
        local resumed=env.AutoCandyResumeStatus
        if type(resumed)=="table" and resumed.Target==game.JobId then view:log("Загрузка после перехода: GUI открыт") end
        local function doorPath(door)
            if not door then return nil end
            local good,path=pcall(function()return door:GetFullName()end)
            return good and path or tostring(door)
        end
        function handle:GetDiagnostics()
            local status=env.AutoCandyResumeStatus
            if type(status)~="table" then
                pcall(function() status=http:JSONDecode(read("AutoCandyResumeStatus-"..player.UserId.."-"..handle.PlaceId..".json")) end)
            end
            local saved
            pcall(function()
                local state=http:JSONDecode(read(hopper.StateFile))
                saved={OwnerSession=state.OwnerSession,OwnerJob=state.OwnerJobId,Enabled=state.Enabled,
                    Target=state.ResumeJobId,Token=state.ResumeToken,SavedAt=state.SavedAt}
            end)
            local boot
            if type(status)=="table" then boot={Phase=status.Phase,Target=status.Target,Token=status.Token,Detail=status.Detail,Attempt=status.Attempt} end
            return {Version=handle.Version,Job=handle.JobId,Place=handle.PlaceId,Session=handle.SessionId,Ready=handle.Ready,
                CurrentGui=handle.Gui and handle.Gui.Parent==player:FindFirstChild("PlayerGui"),
                LastHeartbeatAge=handle.LastHeartbeat and os.clock()-handle.LastHeartbeat,
                FastCycle=app.FastCycle==true,FastStats=app.FastStats,RequestedAuto=settings.Values.Auto,RequestedHop=settings.Values.ServerHop,SettingsDirty=settings.Dirty,
                Auto=app.Auto,Phase=app.Phase,Busy=app.Busy,IndexReady=actions.Ready,Scanned=actions.Scanned,
                Door=doorPath(app.Door),RetryDoor=doorPath(app.RetryDoor),RetryIn=app.RetryAt and math.max(0,app.RetryAt-os.clock()),
                Hop={Enabled=hopper.Enabled,Stage=hopper.Stage,Reason=hopper.Reason,StageAge=hopper.StageSince and os.clock()-hopper.StageSince,
                    Failures=hopper.Failures,Pending=hopper.Pending,Searching=hopper.Searching,RetryAfter=math.max(0,hopper.NextTry-os.clock()),Target=hopper.Target,Token=hopper.Token,Queue=queueName,StateFile=hopper.StateFile},
                Resume=boot,SavedState=saved,Events=events,RecentLogs=view.Lines}
        end
        register(view.DiagnosticButton.Activated:Connect(function()
            local good,report=pcall(function()return http:JSONEncode(handle:GetDiagnostics())end)
            if not good then view:log("Отчёт: "..tostring(report));return end
            local clipboard=type(setclipboard)=="function" and setclipboard or env.setclipboard
            if type(clipboard)=="function" then
                local copied,result=pcall(clipboard,report)
                if copied and result~=false then view:log("Диагностика скопирована");return end
            end
            local file="AutoCandyReport-"..player.UserId.."-"..handle.PlaceId..".json"
            local saved,result=pcall(function()return write(file,report)end)
            view:log(saved and result~=false and ("Отчёт сохранён: "..file) or "Буфер и сохранение отчёта недоступны")
        end))
        local input=game:GetService("UserInputService")
        local keyNames={}
        for _,code in ipairs(Enum.KeyCode:GetEnumItems()) do
            if code~=Enum.KeyCode.Unknown then keyNames[code.Name:lower()]=code end
        end
        local stopKey=keyNames[settings.Values.StopKey:lower()] or Enum.KeyCode.T
        view.StopKey.Text=stopKey.Name
        -- Persist the user's requested modes, never a temporary runtime failure.
        local function saveModes(auto,hop)
            if not destroyed and env[key]==handle and game.JobId==handle.JobId then settings:set({Auto=auto,ServerHop=hop}) end
        end
        local function stop()
            if hopper.Enabled or hopper.Pending or hopper.Searching then hopper:setEnabled(false) end
            app:setAuto(false);saveModes(false,false)
        end
        register(view.DoorDelay.FocusLost:Connect(function()
            if destroyed or view.Closing then return end
            local value=tonumber((view.DoorDelay.Text:gsub(",",".")))
            if value and value==value and value>=0 and value<=60 then
                app.NewDoorDelay=value;app.NextScan=0
                settings:set({DoorDelay=value});view:log("Задержка новой двери: "..tostring(value).." с")
            else view:log("Задержка: введи число от 0 до 60 секунд") end
            view.DoorDelay.Text=tostring(app.NewDoorDelay)
        end))
        register(view.ResetButton.Activated:Connect(function()
            if destroyed or view.Closing then return end
            stop()
            local saved=settings:reset()
            stopKey=Enum.KeyCode.T;app.NewDoorDelay=settings.Values.DoorDelay;app.NextScan=0
            view.StopKey.Text=stopKey.Name;view.DoorDelay.Text=tostring(app.NewDoorDelay)
            view:applyPreferences(settings.Values)
            view:log(saved and "Настройки сброшены и сохранены" or "Настройки сброшены; сохранение недоступно")
            view:update(app,hopper,actions)
        end))
        register(view.StopKey.FocusLost:Connect(function()
            if destroyed or view.Closing then return end
            local name=view.StopKey.Text:match("^%s*(.-)%s*$"):lower()
            local selected=keyNames[name]
            if selected then
                stopKey=selected;settings:set({StopKey=stopKey.Name});view:log("Клавиша остановки: "..stopKey.Name)
            else view:log("Неизвестная клавиша. Пример: T, F8, LeftShift") end
            view.StopKey.Text=stopKey.Name
        end))
        register(input.InputBegan:Connect(function(e,processed)
            if destroyed or view.Closing or processed or input:GetFocusedTextBox() then return end
            if e.UserInputType~=Enum.UserInputType.Keyboard or e.KeyCode~=stopKey then return end
            -- Disable queued resume/search before cancelling held input and noclip.
            -- An already accepted server teleport cannot be revoked by this key.
            stop()
            view:log("Остановлено клавишей "..stopKey.Name)
            view:update(app,hopper,actions)
        end))
        register(teleport.TeleportInitFailed:Connect(function(p,_,message,placeId)
            if p==player and hopper.Pending and placeId==game.PlaceId then hopper:failed(message) end
        end))
        register(view.AutoButton.Activated:Connect(function()
            if view.Closing then return end
            local enabled=not settings.Values.Auto
            saveModes(enabled,false)
            if hopper.Enabled or hopper.Transitioning then hopper:setEnabled(false) end
            app:setAuto(enabled);view:update(app,hopper,actions)
        end))
        register(view.HopButton.Activated:Connect(function()
            if view.Closing then return end
            local enabled=not settings.Values.ServerHop
            saveModes(enabled or settings.Values.Auto,enabled)
            hopper:setEnabled(enabled);view:update(app,hopper,actions)
        end))
        register(view.TeleportButton.Activated:Connect(function()
            if view.Closing then return end
            if app.Busy or hopper.Pending or hopper.Searching then view:log("Дождись завершения текущей операции");return end
            app:attempt(true);view:update(app,hopper,actions)
        end))
        register(view.CloseButton.Activated:Connect(function()
            if view.Closing then return end
            -- Stop input and save mode-off immediately; only the window fade is delayed.
            stop()
            view:closeAnimated(function() dispose(false) end)
        end))
        -- Roblox destroys the old GUI during a pending server transition. Preserve
        -- the queued resume only for that path; explicit close always disables it.
        register(view.Gui.Destroying:Connect(function() dispose(hopper.Pending and hopper.Enabled) end))
        local nextTick=0
        register(game:GetService("RunService").Heartbeat:Connect(function()
            if env[key]~=handle or game.JobId~=handle.JobId or game:GetService("Players").LocalPlayer~=player then dispose(true);return end
            handle.LastHeartbeat=os.clock()
            -- File bridges can yield during restore; do not run a half-initialized controller.
            if not handle.Ready or hopper.Transitioning then return end
            local good,problem=pcall(function()
                actions:serviceIndex()
                if os.clock()<nextTick then return end
                nextTick=os.clock()+(app.FastCycle and 0 or .05)
                if not hopper.Pending and not hopper.Searching then app:step() end
                hopper:step()
            end)
            if not good then
                if hopper.Enabled then hopper:setEnabled(false) end
                observe("runtime_error",tostring(problem))
                app:finish("Ошибка: "..tostring(problem),false);app:setAuto(false);view:log(tostring(problem))
            end
            if not destroyed then
                settings:service(os.clock())
                view:update(app,hopper,actions)
            end
        end))
        if hopper.ShouldResume or settings.Values.ServerHop then
            view:log("Восстановление смены серверов")
            -- A fresh destination handoff takes precedence over an older OFF snapshot.
            saveModes(true,true)
            if not hopper:setEnabled(true) then
                view:log("Режим ON сохранён; запуск переходов не удался. Подробности в логе")
            end
        elseif settings.Values.Auto then app:setAuto(true) end
        view:update(app,hopper,actions)
        handle.Ready=true;observe("ready","main GUI mounted")
        view:log("Auto Candy готов. Настройки "..(settings.Loaded and "загружены" or "по умолчанию"))
    end)
    if not ok then dispose(false);error("[AutoCandy] "..tostring(err)) end
    return handle
end
return Main
