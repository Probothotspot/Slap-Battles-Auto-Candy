local Test={}
function Test.start(Core,Actions,Gui,Feedback,Caps,Registry)
    local player=game:GetService('Players').LocalPlayer;assert(player,'Client player required')
    local env=_G
    if type(getgenv)=='function'then local ok,v=pcall(getgenv);if ok and type(v)=='table'then env=v end end
    local key='AutoCandyMethodTest'
    if type(env[key])=='table' and type(env[key].Destroy)=='function'then env[key]:Destroy()end
    local functions={identifyexecutor=identifyexecutor,getexecutorname=getexecutorname,
        fireclickdetector=fireclickdetector,firetouchinterest=firetouchinterest,fireproximityprompt=fireproximityprompt,
        setclipboard=setclipboard,writefile=writefile,isrbxactive=isrbxactive}
    for name in pairs({identifyexecutor=true,getexecutorname=true,fireclickdetector=true,firetouchinterest=true,
        fireproximityprompt=true,setclipboard=true,writefile=true,isrbxactive=true})do
        if type(functions[name])~='function' and type(env[name])=='function'then functions[name]=env[name]end
    end
    local caps=Caps.new(functions)
    local self={Version='1.0.0',Busy=false,Phase='idle',Caps=caps,Connections={},Report={Executor=caps.Name,Results={}}}
    local view,actions,ctx,door,registry,hud,label,active,result
    local function register(c)self.Connections[#self.Connections+1]=c;return c end
    local function log(s)if view and not view.Destroyed then view:log(s)end end
    local function reportJSON()
        local ok,value=pcall(function()return game:GetService('HttpService'):JSONEncode(self.Report)end)
        return ok and value or table.concat(view.Lines,'\n'),ok
    end
    local function save()
        if caps.writefile then
            local data,encoded=reportJSON()
            if not encoded then log('JSON недоступен; текстовый отчёт можно скопировать');return end
            local ok,err=pcall(caps.writefile,'AutoCandyMethods-v1.json',data)
            if not ok then log('Сохранение отчёта: '..tostring(err))end
        end
    end
    local function record(status,detail)
        result.Status=status;result.Detail=tostring(detail or '')
        if not result.Recorded then result.Recorded=true;self.Report.Results[#self.Report.Results+1]=result end
        log(result.Method..' — '..status..(detail and (': '..tostring(detail))or ''))
    end
    function self:finish(reason)
        if not self.Busy then return end
        self.Busy=false;self.Phase='idle'
        if result and not result.Recorded then record('CANCELLED',reason)end
        local old=ctx;ctx=nil
        local released,releaseError=true,nil
        if registry then released,releaseError=pcall(registry.release,registry)end
        local restored,restoreError=pcall(actions.restore,actions,old)
        if old and old.OtherGui and old.OtherGui.Parent then old.OtherGui.Enabled=old.OtherEnabled end
        if old and old.PixelGui and old.PixelGui.Parent then old.PixelGui.Enabled=old.PixelEnabled end
        hud.Enabled=false
        self.Report.FinishedAt=os.time();self.Report.Outcome=reason or 'FINISHED'
        self.Report.Released=released;self.Report.Restored=restored
        if not released then log('Освобождение ввода: '..tostring(releaseError))end
        if not restored then log('Восстановление: '..tostring(restoreError))end
        log(reason or 'Проверка завершена')
        log(self.Report.Best and ('Стук замечен после: '..self.Report.Best) or 'Подтверждённого стука нет')
        save();active=nil;result=nil
    end
    local function nextMethod()
        local released,err=pcall(registry.release,registry)
        if not released then self:finish('Не удалось освободить ввод: '..tostring(err));return end
        self.Index=(self.Index or 0)+1
        active=registry.Methods[self.Index];result=nil
        if not active then self:finish('Все доступные методы проверены');return end
        if not caps:allowed(active.API)then
            self.Report.Results[#self.Report.Results+1]={Method=active.Name,API=active.API,Status='SKIP',Reason='API ранее отказал: '..caps.Disabled[active.API]}
            log('Пропуск '..active.Name..': API уже отказал')
            active=nil;self.Phase='next';self.Due=os.clock()+.05;return
        end
        result={Method=active.Name,API=active.API,Status='PENDING'}
        label.Text=self.Index..'/'..#registry.Methods..' | '..active.Name
        log('Проверка '..self.Index..'/'..#registry.Methods..': '..active.Name)
        self.Phase='prepare';self.Due=os.clock()+.25
    end
    function self:Start()
        if self.Busy or self.Destroyed or view.Closing then return end
        if self.InTick then log('Предыдущий вызов ещё не завершён');return end
        if not actions.Ready then log('Индекс строится в фоне; повтори через секунду');return end
        local best,distance
        for _,p in ipairs(actions:doors())do local d=actions:distance(p);if d and(not distance or d<distance)then best,distance=p,d end end
        if not best then log('Нет существующих объектов DoorInnerTouch / Door');return end
        for _,oldKey in ipairs({'AutoCandyPixelTest'})do
            local previous=env[oldKey]
            if type(previous)=='table' and previous.Busy and type(previous.finish)=='function'then previous:finish('Запущен тест методов')end
        end
        local main=env.SlapBattlesAutoCandy
        if type(main)=='table'then
            if main.Hopper then main.Hopper:setEnabled(false)end
            if main.App then main.App:setAuto(false)end
        end
        local ok,captured=pcall(actions.capture,actions)
        if not ok then log('Запуск: '..tostring(captured));return end
        ctx=captured;door=best;registry=nil;active=nil;result=nil;self.Index=0;self.Busy=true
        if type(main)=='table' and main.Gui and main.Gui.Parent then ctx.OtherGui=main.Gui;ctx.OtherEnabled=main.Gui.Enabled;main.Gui.Enabled=false end
        local pixel=env.AutoCandyPixelTest
        if type(pixel)=='table' and pixel.Gui and pixel.Gui.Parent then ctx.PixelGui=pixel.Gui;ctx.PixelEnabled=pixel.Gui.Enabled;pixel.Gui.Enabled=false end
        self.Report={Executor=caps.Name,ExecutorVersion=caps.Version,StartedAt=os.time(),PlaceId=game.PlaceId,
            Door=door:GetFullName(),Results={},RewardConfirmed=false}
        local moved,why=pcall(actions.approach,actions,ctx,door)
        if not moved then self:finish('ТП: '..tostring(why));return end
        self.Phase='settle';self.Due=os.clock()+.35;self.Deadline=os.clock()+90
        log('Исполнитель: '..caps.Name..'. Совместимость проверяется вызовом API')
    end
    function self:Destroy()
        if self.Destroyed then return end
        self:finish('Остановка');self.Destroyed=true
        if actions then actions:Destroy()end
        for _,c in ipairs(self.Connections)do c:Disconnect()end
        self.Connections={}
        if hud then hud:Destroy()end
        if view then view:Destroy()end
        if env[key]==self then env[key]=nil end
    end
    env[key]=self
    local ok,problem=pcall(function()
        view=Gui.mount(player,register);self.Gui=view.Gui;view.Gui.Name='AutoCandyMethodTestGUI'
        view.Gui:FindFirstChild('Title',true).Text='Door Test | '..caps.Name:sub(1,18)
        view.Gui:FindFirstChild('Title',true).TextSize=15
        view.Gui:FindFirstChild('Subtitle',true).Text='Объекты двери → методы → проверка стука'
        view.AutoButton.Text='Тест методов';view.TeleportButton.Text='Стоп';view.HopButton.Text='Копировать отчёт'
        hud=Instance.new('ScreenGui');hud.Name='DoorMethodHUD';hud.ResetOnSpawn=false;hud.DisplayOrder=1001
        hud.IgnoreGuiInset=true;hud.Enabled=false;hud.Parent=player:WaitForChild('PlayerGui')
        label=Instance.new('TextLabel');label.Size=UDim2.fromOffset(300,27);label.Position=UDim2.fromOffset(10,52)
        label.BackgroundColor3=Color3.fromRGB(137,83,196);label.TextColor3=Color3.fromRGB(255,247,255)
        label.TextSize=12;label.TextWrapped=true;label.Font=Enum.Font.Gotham;label.Parent=hud
        local stop=Instance.new('TextButton');stop.Name='Stop';stop.Text='Стоп / вернуть персонажа'
        stop.Size=UDim2.fromOffset(300,27);stop.Position=UDim2.fromOffset(10,80)
        stop.BackgroundColor3=Color3.fromRGB(161,106,218);stop.TextColor3=Color3.fromRGB(255,247,255)
        stop.Font=Enum.Font.Gotham;stop.TextSize=12;stop.Parent=hud
        actions=Actions.new(player,workspace,Core,register,log,function(show)view:clickVisibility(show)end)
        register(view.AutoButton.Activated:Connect(function()self:Start()end))
        register(view.TeleportButton.Activated:Connect(function()self:finish('Остановлено пользователем')end))
        register(stop.Activated:Connect(function()self:finish('Остановлено пользователем')end))
        register(view.HopButton.Activated:Connect(function()
            if caps.setclipboard then local data=reportJSON();local copied,err=pcall(caps.setclipboard,data);log(copied and 'Отчёт скопирован' or tostring(err))
            else log('setclipboard отсутствует')end
        end))
        register(view.CloseButton.Activated:Connect(function()
            if view.Closing then return end
            self:finish('Закрытие');view:closeAnimated(function()self:Destroy()end)
        end))
        register(view.Gui.Destroying:Connect(function()self:Destroy()end))
        register(game:GetService('RunService').Heartbeat:Connect(function()
            if self.Destroyed or self.InTick then return end
            self.InTick=true
            local worked,why=pcall(function()
                actions:serviceIndex();if not self.Busy then return end
                local valid,reason=actions:valid(ctx,door);assert(valid,reason)
                if os.clock()>self.Deadline then self:finish('Лимит времени теста');return end
                if ctx.Monitor then
                    ctx.Monitor:step()
                    if result and not result.Recorded then
                        local sound=ctx.Monitor.Result
                        if sound then
                            record('KNOCK',sound.Id);self.Report.Best=active.Name;self.Report.SoundId=sound.Id
                            self:finish('Обнаружен локальный стук; повтор остановлен');return
                        end
                    end
                end
                if os.clock()<self.Due then return end
                if self.Phase=='settle'then
                    actions:aim(ctx,door)
                    local scope=door.Parent;while scope and scope~=workspace and scope.Name:lower()~='door'do scope=scope.Parent end
                    assert(scope and scope~=workspace,'Контейнер Door исчез')
                    ctx.Scope=scope;ctx.Monitor=Feedback.new(scope)
                    registry=Registry.new(ctx,door,scope,workspace,actions,caps)
                    self.Phase='scan';self.Due=os.clock()+.05
                elseif self.Phase=='scan'then
                    registry:step()
                    if not registry.Ready or not ctx.Monitor.Ready then return end
                    for _,row in ipairs(registry.Skipped)do self.Report.Results[#self.Report.Results+1]=row;log('Пропуск '..row.Method..': '..row.Reason)end
                    log('Методов для проверки: '..#registry.Methods);hud.Enabled=true;nextMethod()
                elseif self.Phase=='next'then nextMethod()
                elseif self.Phase=='prepare'then
                    if caps.isrbxactive then assert(caps.isrbxactive(),'Окно Roblox не в фокусе')end
                    local prepared,err=pcall(function()if active.Prepare then active.Prepare()end end)
                    if not self.Busy then return end
                    if not prepared then caps:reject(active.API,err);record('ERROR',err);nextMethod();return end
                    self.Phase='begin';self.Due=os.clock()+.15
                elseif self.Phase=='begin'then
                    ctx.Monitor:arm()
                    ctx.Monitor.Until=os.clock()+active.Hold+2.1
                    local oldRegistry=registry
                    local called,err=pcall(active.Begin)
                    if not self.Busy then pcall(oldRegistry.release,oldRegistry);return end
                    if not called then caps:reject(active.API,err);record('ERROR',err);nextMethod();return end
                    result.CallReturned=true;log('API вызван без ошибки; ожидаю ответ двери')
                    self.Phase='held';self.Due=os.clock()+active.Hold
                elseif self.Phase=='held'then
                    registry:release();self.Phase='listen';self.Due=os.clock()+1.8
                elseif self.Phase=='listen'then
                    local sound=ctx.Monitor.Candidate
                    if sound then record('LOCAL_SOUND',sound.Name..' | '..sound.Id);self:finish('Тип звука неизвестен; повтор остановлен')
                    else record('NO_RESPONSE','Наблюдаемого стука нет');nextMethod()end
                end
            end)
            self.InTick=false
            if not worked then self:finish('Ошибка: '..tostring(why));log(tostring(why))end
        end))
        log('Door Methods готов | '..caps.Name)
        log('Нет обещанного списка по бренду: API и объекты проверяются в этой сессии')
    end)
    if not ok then self:Destroy();error(problem)end
    return self
end
return Test
