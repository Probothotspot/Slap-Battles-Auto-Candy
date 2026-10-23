local Registry={}
function Registry.new(ctx,door,scope,world,actions,caps,clock)
    clock=clock or os.clock
    local self={Stack={{Node=scope}},Scanned=0,Ready=false,Methods={},Skipped={},Targets={}}
    local counts={};local touches={}
    local function add(m)self.Methods[#self.Methods+1]=m end
    local function skip(name,reason)self.Skipped[#self.Skipped+1]={Method=name,Status='SKIP',Reason=reason}end
    local function held(release)ctx.InteractionRelease=release end
    local function touchTarget(o)
        local p=o.Parent
        if not p or not p:IsA('BasePart') or touches[p]then return end
        touches[p]=true
        if p.CanTouch~=true then skip('Touch '..p.Name,'CanTouch выключен');return end
        if caps.firetouchinterest then
            local fn=caps.firetouchinterest
            add({Id='touch:'..#self.Methods,Name='firetouchinterest / '..p.Name,API='firetouchinterest',Hold=.2,
                Begin=function()held(function()fn(ctx.Root,p,1)end);fn(ctx.Root,p,0)end})
        else skip('firetouchinterest','Функция отсутствует')end
        if p.CanCollide==false then
            local stage=ctx.Root.CFrame
            add({Id='contact:'..#self.Methods,Name='Контакт персонажем / '..p.Name,API='PhysicalContact',Hold=.25,
                Begin=function()
                    held(function()
                        local valid,why=actions:valid(ctx,door);assert(valid,why)
                        ctx.Character:PivotTo(stage*ctx.Root.CFrame:ToObjectSpace(ctx.Character:GetPivot()))
                        ctx.Root.AssemblyLinearVelocity=Vector3.zero;ctx.Root.AssemblyAngularVelocity=Vector3.zero
                    end)
                    ctx.Character:PivotTo(CFrame.new(p.Position)*ctx.Root.CFrame:ToObjectSpace(ctx.Character:GetPivot()))
                    ctx.Root.AssemblyLinearVelocity=Vector3.zero;ctx.Root.AssemblyAngularVelocity=Vector3.zero
                end})
        else skip('Контакт персонажем','Деталь имеет коллизию; контакт внутрь не выполняется')end
    end
    local function inspect(o)
        local class=o:IsA('ClickDetector') and 'ClickDetector' or o:IsA('ProximityPrompt') and 'ProximityPrompt'
            or o:IsA('TouchTransmitter') and 'TouchTransmitter'
        if not class or not o:IsDescendantOf(scope)then return end
        counts[class]=(counts[class]or 0)+1
        if counts[class]>4 then return end
        self.Targets[#self.Targets+1]=o
        if class=='TouchTransmitter'then touchTarget(o)
        elseif class=='ClickDetector'then
            if caps.fireclickdetector then
                add({Id='detector:'..#self.Methods,Name='fireclickdetector / '..o.Parent.Name,API='fireclickdetector',Hold=.05,
                    Begin=function()assert(o:IsDescendantOf(scope),'ClickDetector исчез');caps.fireclickdetector(o)end})
            else skip('fireclickdetector','Функция отсутствует')end
        else
            if o.Enabled~=true then skip('ProximityPrompt','Объект выключен');return end
            local duration=o.HoldDuration
            if type(duration)~='number' or duration<0 or duration>5 then skip('ProximityPrompt','HoldDuration вне диапазона 0–5 секунд');return end
            local function validPrompt()assert(o:IsDescendantOf(scope) and o.Enabled,'ProximityPrompt недоступен')end
            if caps.fireproximityprompt and duration==0 then
                add({Id='prompt-fire:'..#self.Methods,Name='fireproximityprompt / '..o.Name,API='fireproximityprompt',Hold=.05,
                    Begin=function()validPrompt();caps.fireproximityprompt(o)end})
            else skip('fireproximityprompt',not caps.fireproximityprompt and 'Функция отсутствует' or 'Ненулевой HoldDuration: используется штатное удержание')end
            add({Id='prompt-hold:'..#self.Methods,Name='ProximityPrompt InputHold / '..o.Name,API='Prompt.InputHold',Hold=math.max(.12,duration+.1),
                Begin=function()validPrompt();held(function()o:InputHoldEnd()end);o:InputHoldBegin()end})
            if o.KeyboardKeyCode and o.KeyboardKeyCode~=Enum.KeyCode.Unknown then
                local code=o.KeyboardKeyCode
                if ctx.Input then
                    add({Id='key-vim:'..#self.Methods,Name='Клавиша prompt / VIM / '..tostring(code),API='VIM.Key',Hold=math.max(.12,duration+.1),
                        Begin=function()validPrompt();held(function()ctx.Input:SendKeyEvent(false,code,false,game)end);ctx.Input:SendKeyEvent(true,code,false,game)end})
                end
                if ctx.Virtual then
                    add({Id='key-vi:'..#self.Methods,Name='Клавиша prompt / VirtualInput / '..tostring(code),API='VI.Key',Hold=math.max(.12,duration+.1),
                        Begin=function()validPrompt();held(function()ctx.Virtual:SendKey(false,code,false)end);ctx.Virtual:SendKey(true,code,false)end})
                end
            end
        end
    end
    local function finish()
        if not counts.ClickDetector then skip('ClickDetector','На выбранной двери нет объекта ClickDetector')end
        if not counts.ProximityPrompt then skip('ProximityPrompt','На выбранной двери нет объекта ProximityPrompt')end
        if not counts.TouchTransmitter then skip('Touch','На выбранной двери нет TouchTransmitter')end
        local function mouse(name,kind,api)
            add({Id=api..':'..kind,Name=name,API=api,Hold=.12,
                Prepare=function()
                    ctx.Method={Name=name,Kind=kind}
                    local point,visible
                    if kind=='viewport'then point,visible=ctx.Camera:WorldToViewportPoint(door.Position)
                    else point,visible=ctx.Camera:WorldToScreenPoint(door.Position)end
                    assert(visible and point.Z>0,'Дверь вне экрана')
                    ctx.Mouse={X=math.floor(point.X+.5),Y=math.floor(point.Y+.5)}
                    ctx.CursorMoved=true
                    if kind=='virtual'then ctx.Virtual:SendMousePosition(Vector2.new(ctx.Mouse.X,ctx.Mouse.Y))
                    else ctx.Input:SendMouseMoveEvent(ctx.Mouse.X,ctx.Mouse.Y,game)end
                end,
                Begin=function()actions:mouseDown(ctx,door)end})
        end
        if ctx.Virtual then mouse('VirtualInput mouse','virtual','VI.Mouse')else skip('VirtualInput','CreateVirtualInput не вернул объект')end
        if ctx.Input then mouse('VIM screen','screen','VIM.Mouse');mouse('VIM viewport','viewport','VIM.Mouse')
        else skip('VIM','Сервис недоступен')end
        self.Ready=true
    end
    function self:step()
        if self.Ready then return end
        local start=clock();local work=0
        while #self.Stack>0 and work<64 and clock()-start<.001 do
            work=work+1;local f=self.Stack[#self.Stack]
            if not f.Children then f.Children=f.Node:GetChildren();f.Index=1
            elseif f.Index>#f.Children then table.remove(self.Stack)
            else
                local o=f.Children[f.Index];f.Index=f.Index+1;self.Scanned=self.Scanned+1;inspect(o)
                if self.Scanned<512 then self.Stack[#self.Stack+1]={Node=o}else self.Stack={};break end
            end
        end
        if #self.Stack==0 then finish()end
    end
    function self:release()
        if ctx.InteractionRelease then ctx.InteractionRelease();ctx.InteractionRelease=nil end
        actions:mouseUp(ctx)
    end
    return self
end
return Registry
