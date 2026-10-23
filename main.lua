-- Bundled by build.py into auto_candy.lua; no runtime module dependencies.
local Main={}
function Main.start(Core,Actions,Gui,ServerHop,Feedback)
    local players=game:GetService("Players")
    local player=players.LocalPlayer;assert(player,"Auto Candy requires a client player")
    local env=_G
    if type(getgenv)=="function" then local ok,v=pcall(getgenv);if ok and type(v)=="table" then env=v end end
    local key="SlapBattlesAutoCandy"
    if type(env[key])=="table" and type(env[key].Destroy)=="function" then env[key]:Destroy() end
    local connections={};local app,view,actions,hopper;local destroyed=false
    local function register(c) connections[#connections+1]=c;return c end
    local handle={Version="1.2.0"}
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
        view=Gui.mount(player,register)
        actions=Actions.new(player,workspace,Core,register,function(s) view:log(s) end,function(show) view:clickVisibility(show) end,Feedback)
        app=Core.new(actions,os.clock,function(s) view:log(s) end)
        handle.App=app;handle.Gui=view.Gui
        local http=game:GetService("HttpService")
        local teleport=game:GetService("TeleportService")
        local queue=queue_on_teleport or queueonteleport or (type(syn)=="table" and syn.queue_on_teleport)
        local send=request or http_request or (type(syn)=="table" and syn.request)
        hopper=ServerHop.new({App=app,Actions=actions,PlaceId=game.PlaceId,JobId=game.JobId,UserId=player.UserId,
            Log=function(s) view:log(s) end,Queue=queue,Read=readfile,Write=writefile,Spawn=task.spawn,
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
        register(teleport.TeleportInitFailed:Connect(function(p,_,message,placeId)
            if p==player and hopper.Pending and placeId==game.PlaceId then hopper:failed(message) end
        end))
        register(view.AutoButton.Activated:Connect(function()
            if view.Closing then return end
            if app.Auto and hopper.Enabled then hopper:setEnabled(false) end
            app:setAuto(not app.Auto);view:update(app,hopper,actions)
        end))
        register(view.HopButton.Activated:Connect(function()
            if view.Closing then return end
            hopper:setEnabled(not hopper.Enabled);view:update(app,hopper,actions)
        end))
        register(view.TeleportButton.Activated:Connect(function()
            if view.Closing then return end
            if app.Busy or hopper.Pending or hopper.Searching then view:log("Дождись завершения текущей операции");return end
            app:attempt(true);view:update(app,hopper,actions)
        end))
        register(view.CloseButton.Activated:Connect(function()
            if view.Closing then return end
            -- Stop input and save mode-off immediately; only the window fade is delayed.
            hopper:setEnabled(false);app:setAuto(false)
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
                app.Auto=false;app:finish("Ошибка: "..tostring(problem));view:log(tostring(problem))
            end
            view:update(app,hopper,actions)
        end))
        view:log("Auto Candy готов. Авто выключено")
        if hopper.ShouldResume then
            view:log("Возобновление после смены сервера")
            hopper:setEnabled(true)
        end
    end)
    if not ok then dispose(false);error("[AutoCandy] "..tostring(err)) end
    return handle
end
return Main
