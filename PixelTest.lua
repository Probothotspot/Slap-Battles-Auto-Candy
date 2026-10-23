-- Separate diagnostic; does not enable farming or server hopping.
local PixelTest={}
function PixelTest.start(Core,Actions,Gui,Feedback,Grid)
    local player=game:GetService('Players').LocalPlayer;assert(player,'Client player required')
    local env=type(getgenv)=='function' and getgenv() or _G
    local key='AutoCandyPixelTest'
    if type(env[key])=='table' and type(env[key].Destroy)=='function' then env[key]:Destroy() end
    local self={Version='1.0.0',Busy=false,Sent=0,Count=500,CPS=30,Phase='idle',Connections={}}
    local view,actions,ctx,door,grid,overlay,label
    local function register(c)self.Connections[#self.Connections+1]=c;return c end
    local function log(s)if view then view:log(s)end end
    local function text(o,n,v) local p=o:FindFirstChild(n,true);if p then p.Text=v end end
    local function progress()
        local s='Клики: '..self.Sent..'/'..self.Target..' | '..self.Backend
        label.Text=s
        if self.LastProgress~=s then self.LastProgress=s;view.State.Text=s end
    end
    function self:finish(reason)
        if not self.Busy then return end
        self.Busy=false;self.Phase='idle'
        local old=ctx;ctx=nil
        local ok,err=pcall(actions.restore,actions,old)
        if old and old.OtherGui and old.OtherGui.Parent then old.OtherGui.Enabled=old.OtherEnabled end
        overlay.Enabled=false
        log((reason or 'Тест завершён')..'. Отправлено '..self.Sent..'/'..(self.Target or self.Count))
        log(self.Knock and ('Замечен стук: '..self.Knock.Id..'; первый после клика '..self.Knock.Click)
            or 'Стук не подтверждён. Отправленный ввод не подтверждает выдачу конфет')
        if not ok then log('Восстановление: '..tostring(err))end
        view.AutoButton.Text='Старт: 500';view.TeleportButton.Text='Стоп'
    end
    local function begin()
        if self.Busy or self.Destroyed or view.Closing then return end
        if not actions.Ready then log('Индекс строится в фоне; повтори через секунду');return end
        local best,distance
        for _,p in ipairs(actions:doors())do
            local d=actions:distance(p)
            if d and (not distance or d<distance)then best,distance=p,d end
        end
        if not best then log('Нет существующих объектов DoorInnerTouch / Door');return end
        local main=env.SlapBattlesAutoCandy
        if type(main)=='table' then
            if main.Hopper then main.Hopper:setEnabled(false)end
            if main.App then main.App:setAuto(false)end
            log('Основной авторежим приостановлен для теста')
        end
        local ok,captured=pcall(actions.capture,actions)
        if not ok then log('Запуск: '..tostring(captured));return end
        ctx=captured;door=best
        if main and main.Gui and main.Gui.Parent then ctx.OtherGui=main.Gui;ctx.OtherEnabled=main.Gui.Enabled;main.Gui.Enabled=false end
        self.Busy=true;self.Sent=0;self.Knock=nil;self.Target=self.Count;self.LastProgress=nil
        local moved,err=pcall(actions.approach,actions,ctx,door)
        if not moved then self:finish('ТП: '..tostring(err));return end
        self.Phase='settle';self.Due=os.clock()+.35
        log('ТП перед дверью. Готовлю 500 разных экранных пикселей')
    end
    function self:Destroy()
        if self.Destroyed then return end
        self:finish('Остановка');self.Destroyed=true
        if actions then actions:Destroy()end
        for _,c in ipairs(self.Connections)do c:Disconnect()end
        self.Connections={}
        if overlay then overlay:Destroy()end
        if view then view:Destroy()end
        if env[key]==self then env[key]=nil end
    end
    env[key]=self
    local ok,err=pcall(function()
        view=Gui.mount(player,register);self.Gui=view.Gui
        view.Gui.Name='AutoCandyPixelTestGUI'
        text(view.Gui,'Title','Door Pixel Test')
        text(view.Gui,'Subtitle','500 разных пикселей • до 30 кликов/с')
        view.AutoButton.Text='Старт: 500';view.TeleportButton.Text='Стоп';view.HopButton.Text='Копировать логи'
        overlay=Instance.new('ScreenGui');overlay.Name='PixelTestHUD';overlay.ResetOnSpawn=false
        overlay.DisplayOrder=1001;overlay.IgnoreGuiInset=true;overlay.Enabled=false;overlay.Parent=player:WaitForChild('PlayerGui')
        label=Instance.new('TextLabel');label.Position=UDim2.fromOffset(10,52);label.Size=UDim2.fromOffset(240,25)
        label.BackgroundColor3=Color3.fromRGB(237,217,255);label.TextColor3=Color3.fromRGB(58,34,83)
        label.Font=Enum.Font.Gotham;label.TextSize=12;label.Parent=overlay
        local stop=Instance.new('TextButton');stop.Name='Stop';stop.Text='Стоп / вернуть персонажа'
        stop.Position=UDim2.fromOffset(10,78);stop.Size=UDim2.fromOffset(240,25)
        stop.BackgroundColor3=Color3.fromRGB(184,138,232);stop.TextColor3=Color3.fromRGB(52,22,77)
        stop.Font=Enum.Font.Gotham;stop.TextSize=12;stop.Parent=overlay
        actions=Actions.new(player,workspace,Core,register,log,function(show)view:clickVisibility(show)end)
        register(view.AutoButton.Activated:Connect(begin))
        register(view.TeleportButton.Activated:Connect(function()self:finish('Остановлено пользователем')end))
        register(stop.Activated:Connect(function()self:finish('Остановлено пользователем')end))
        register(view.HopButton.Activated:Connect(function()
            if type(setclipboard)=='function' then
                local copied,problem=pcall(setclipboard,table.concat(view.Lines,'\n'))
                log(copied and 'Логи скопированы' or ('Буфер: '..tostring(problem)))
            else log('Функция setclipboard недоступна')end
        end))
        register(view.CloseButton.Activated:Connect(function()
            if view.Closing then return end
            self:finish('Закрытие');view:closeAnimated(function()self:Destroy()end)
        end))
        register(view.Gui.Destroying:Connect(function()self:Destroy()end))
        register(game:GetService('RunService').Heartbeat:Connect(function()
            if self.Destroyed then return end
            local worked,problem=pcall(function()
                actions:serviceIndex()
                if not self.Busy then return end
                local valid,why=actions:valid(ctx,door);assert(valid,why)
                local now=os.clock()
                if ctx.Monitor then
                    ctx.Monitor:step()
                    local sound=ctx.Monitor.Result
                    if sound and not self.Knock then self.Knock={Id=sound.Id,Click=self.Sent+(ctx.MouseHeld and 1 or 0)} end
                end
                if self.Phase=='settle' and now>=self.Due then
                    actions:aim(ctx,door)
                    ctx.Method=ctx.Input and {Name='VIM screen',Kind='screen'} or {Name='VirtualInput',Kind='virtual'}
                    assert(ctx.Input or ctx.Virtual,'Нет доступного виртуального ввода')
                    self.Backend=ctx.Method.Name
                    ctx.DoorCF=door.CFrame;ctx.DoorSize=door.Size;ctx.Viewport=ctx.Camera.ViewportSize
                    ctx.CapturedCamera=ctx.Camera.CFrame
                    local scope=door.Parent
                    while scope and scope~=workspace and scope.Name:lower()~='door'do scope=scope.Parent end
                    assert(scope and scope~=workspace,'Контейнер Door исчез')
                    ctx.Monitor=Feedback.new(scope)
                    local cf,size=door.CFrame,door.Size
                    local thinX=size.X<size.Z
                    local axis=thinX and cf.RightVector or cf.LookVector
                    local sign=(ctx.Camera.CFrame.Position-door.Position):Dot(axis)>=0 and 1 or -1
                    grid=Grid.new(function(u,v)
                        local worldPoint
                        if thinX then worldPoint=cf.Position+cf.RightVector*(sign*(size.X/2+.01))
                            +cf.UpVector*((v-.5)*size.Y)+cf.LookVector*((u-.5)*size.Z)
                        else worldPoint=cf.Position+cf.LookVector*(sign*(size.Z/2+.01))
                            +cf.UpVector*((v-.5)*size.Y)+cf.RightVector*((u-.5)*size.X)end
                        return ctx.Camera:WorldToScreenPoint(worldPoint)
                    end,self.Count)
                    self.Phase='grid';overlay.Enabled=true;progress()
                elseif self.Phase=='grid' then
                    grid:step()
                    if grid.Ready then
                        self.Target=#grid.Points;assert(self.Target>0,'На экране нет подходящих пикселей двери')
                        self.PointIndex=1;self.NextDown=now;self.Phase='move';progress()
                        log('Подготовлено '..self.Target..' разных пикселей. Лимит 30 кликов/с')
                    end
                elseif self.Phase=='move' or self.Phase=='hover' or self.Phase=='pressed' then
                    assert(workspace.CurrentCamera==ctx.Camera,'Камера сменилась')
                    assert((ctx.Camera.CFrame.Position-ctx.CapturedCamera.Position).Magnitude<.05
                        and ctx.Camera.CFrame.LookVector:Dot(ctx.CapturedCamera.LookVector)>.9999
                        and ctx.Camera.CFrame.UpVector:Dot(ctx.CapturedCamera.UpVector)>.9999,'Камера сдвинулась: пиксели устарели')
                    assert((door.Position-ctx.DoorCF.Position).Magnitude<.05 and (door.Size-ctx.DoorSize).Magnitude<.01
                        and door.CFrame.RightVector:Dot(ctx.DoorCF.RightVector)>.9999
                        and door.CFrame.UpVector:Dot(ctx.DoorCF.UpVector)>.9999,'Дверь переместилась: пиксели устарели')
                    local viewport=ctx.Camera.ViewportSize
                    assert(viewport.X==ctx.Viewport.X and viewport.Y==ctx.Viewport.Y,'Размер экрана изменился')
                    if type(isrbxactive)=='function'then assert(isrbxactive(),'Окно Roblox не в фокусе')end
                    if self.Phase=='pressed' then
                        if now<self.Due then return end
                        actions:mouseUp(ctx);self.Sent=self.Sent+1;self.PointIndex=self.PointIndex+1;progress()
                        if self.PointIndex>self.Target then self.Phase='listen';self.Due=now+1.8;return end
                        self.Phase='move'
                    end
                    if self.Phase=='move' then
                        ctx.Mouse=grid.Points[self.PointIndex]
                        local moved,why=pcall(function()
                            if ctx.Method.Kind=='virtual'then ctx.Virtual:SendMousePosition(Vector2.new(ctx.Mouse.X,ctx.Mouse.Y))
                            else ctx.Input:SendMouseMoveEvent(ctx.Mouse.X,ctx.Mouse.Y,game)end
                        end)
                        if not moved then
                            if self.Sent==0 and ctx.Method.Kind~='virtual' and ctx.Virtual then
                                ctx.Method={Name='VirtualInput',Kind='virtual'};self.Backend=ctx.Method.Name
                                log('VIM отказал; пробую VirtualInput');return
                            end
                            error(why)
                        end
                        self.Phase='hover';self.Due=now+.016
                    elseif self.Phase=='hover' and now>=self.Due and now>=self.NextDown then
                        local pressed,why=pcall(actions.mouseDown,actions,ctx,door)
                        if not pressed then
                            local released=pcall(actions.mouseUp,actions,ctx)
                            if released and self.Sent==0 and ctx.Method.Kind~='virtual' and ctx.Virtual then
                                ctx.Method={Name='VirtualInput',Kind='virtual'};self.Backend=ctx.Method.Name
                                self.Phase='move';log('VIM нажатие отказало; пробую VirtualInput');return
                            end
                            error(why)
                        end
                        self.NextDown=now+1/self.CPS;self.Phase='pressed';self.Due=now+.016
                    end
                elseif self.Phase=='listen' and now>=self.Due then self:finish()end
            end)
            if not worked then self:finish('Ошибка: '..tostring(problem));log(tostring(problem))end
        end))
        log('Тест готов. Старт → ближайшая дверь → до 500 разных пикселей → возврат')
        log('При 60 FPS обычно до 30 кликов/с; скорость снижается вместе с FPS')
    end)
    if not ok then self:Destroy();error(err)end
    return self
end
return PixelTest
