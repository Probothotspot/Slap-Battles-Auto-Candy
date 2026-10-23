-- Bundled by build.py into auto_candy.lua; no runtime module dependencies.
local Main={}
function Main.start(Core,Actions,Gui,ServerHop,Feedback,Settings)
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
    if type(env[key])=="table" and type(env[key].Destroy)=="function" then env[key]:Destroy() end
    local connections={};local app,view,actions,hopper,settings;local destroyed=false
    local function register(c) connections[#connections+1]=c;return c end
    local handle={Version="1.6.1"}
    local function dispose(preserve)
        if destroyed then return end;destroyed=true
        if hopper then hopper:Destroy(preserve==true) end
        if app then app:Destroy() end
        if actions then actions:Destroy() end
        for _,c in ipairs(connections) do c:Disconnect() end
        if view then view:Destroy() end
        if env[key]==handle then env[key]=nil end
    end
    function handle:Destroy() dispose(false) end
    env[key]=handle
    local ok,err=pcall(function()
        view=Gui.mount(player,register,{Hotkey=true})
        local http=game:GetService("HttpService")
        settings=Settings.new({UserId=player.UserId,Read=type(readfile)=="function" and readfile or env.readfile,
            Write=type(writefile)=="function" and writefile or env.writefile,IsFile=isfile or env.isfile,
            Encode=function(v) return http:JSONEncode(v) end,Decode=function(v) return http:JSONDecode(v) end,
            Log=function(s) view:log(s) end})
        handle.Settings=settings
        view:applyPreferences(settings.Values)
        view.OnPreferencesChanged=function() settings:set(view:preferences()) end
        actions=Actions.new(player,workspace,Core,register,function(s) view:log(s) end,function(show) view:clickVisibility(show) end,Feedback)
        app=Core.new(actions,os.clock,function(s) view:log(s) end)
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
        hopper=ServerHop.new({App=app,Actions=actions,PlaceId=game.PlaceId,JobId=game.JobId,UserId=player.UserId,
            Log=function(s) view:log(s) end,Queue=queue,QueueName=queueName,Read=read,Write=write,Spawn=task.spawn,Wait=task.wait,
            Source=type(loading)=="table" and loading.Source or nil,
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
        local input=game:GetService("UserInputService")
        local keyNames={}
        for _,code in ipairs(Enum.KeyCode:GetEnumItems()) do
            if code~=Enum.KeyCode.Unknown then keyNames[code.Name:lower()]=code end
        end
        local stopKey=keyNames[settings.Values.StopKey:lower()] or Enum.KeyCode.T
        view.StopKey.Text=stopKey.Name
        settings:set({StopKey=stopKey.Name})
        local function saveModes() settings:set({Auto=app.Auto,ServerHop=hopper.Enabled}) end
        local function stop()
            if hopper.Enabled or hopper.Pending or hopper.Searching then hopper:setEnabled(false) end
            app:setAuto(false);saveModes()
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
            if app.Auto and hopper.Enabled then hopper:setEnabled(false) end
            app:setAuto(not app.Auto);saveModes();view:update(app,hopper,actions)
        end))
        register(view.HopButton.Activated:Connect(function()
            if view.Closing then return end
            hopper:setEnabled(not hopper.Enabled);saveModes();view:update(app,hopper,actions)
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
            local good,problem=pcall(function()
                actions:serviceIndex()
                if os.clock()<nextTick then return end
                nextTick=os.clock()+.05
                if not hopper.Pending and not hopper.Searching then app:step() end
                hopper:step()
            end)
            if not good then
                if hopper.Enabled then hopper:setEnabled(false) end
                app:finish("Ошибка: "..tostring(problem),false);app:setAuto(false);view:log(tostring(problem))
            end
            if not destroyed then saveModes();view:update(app,hopper,actions) end
        end))
        if settings.Values.ServerHop or (not settings.Loaded and hopper.ShouldResume) then
            view:log("Восстановление смены серверов")
            hopper:setEnabled(true)
        elseif settings.Values.Auto then app:setAuto(true) end
        saveModes();view:update(app,hopper,actions)
        view:log("Auto Candy готов. Настройки "..(settings.Loaded and "загружены" or "по умолчанию"))
    end)
    if not ok then dispose(false);error("[AutoCandy] "..tostring(err)) end
    return handle
end
return Main
