local Gui={}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function make(class,props,parent)
    local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function round(o,n) make("UICorner",{CornerRadius=UDim.new(0,n or 10)},o) end
function Gui.mount(player,register)
    local self={Lines={},Collapsed=false,Destroyed=false,Tweens={},Motion={},UserScale=1,Buttons={}}
    local tween=game:GetService("TweenService")
    local input=game:GetService("UserInputService")
    local gui=make("ScreenGui",{Name="AutoCandyGUI",ResetOnSpawn=false,DisplayOrder=1000,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
    self.Gui=gui
    local safe=make("Frame",{Name="SafeArea",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make("CanvasGroup",{Name="Window",Size=UDim2.fromOffset(340,402),Position=UDim2.new(.5,-170,.5,-201),
        GroupTransparency=1,BackgroundColor3=rgb(255,255,255),BorderSizePixel=0,ClipsDescendants=true},safe);round(window,16)
    local scale=make("UIScale",{Scale=1},window)
    local function animate(object,key,props,duration)
        local channels=self.Motion[object] or {};self.Motion[object]=channels
        if channels[key] then channels[key]:Cancel() end
        local motion=tween:Create(object,TweenInfo.new(duration or .18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props)
        channels[key]=motion;motion:Play();return motion
    end
    make("UIStroke",{Color=rgb(168,102,226),Thickness=1,Transparency=.3},window)
    local gradient=make("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,rgb(247,238,255)),
        ColorSequenceKeypoint.new(.5,rgb(222,199,249)),ColorSequenceKeypoint.new(1,rgb(241,225,255))}),Rotation=0},window)
    local function text(parent,name,value,x,y,w,h,size)
        return make("TextLabel",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundTransparency=1,TextColor3=rgb(58,34,83),Font=Enum.Font.Gotham,TextSize=size or 12,
            TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},parent)
    end
    local function button(name,value,x,y,w,h,parent)
        local b=make("TextButton",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundColor3=rgb(184,138,232),TextColor3=rgb(52,22,77),Font=Enum.Font.GothamBold,
            TextSize=14,BorderSizePixel=0,AutoButtonColor=false},parent or window);round(b,9)
        local size=make("UIScale",{Scale=1},b)
        local state={Object=b,Scale=size,Base=rgb(184,138,232)};self.Buttons[b]=state
        local function paint()
            animate(size,"size",{Scale=state.Pressed and .96 or state.Hover and 1.025 or 1},.14)
            animate(b,"color",{BackgroundColor3=state.Hover and rgb(196,153,245) or state.Base},.18)
        end
        state.Paint=paint
        register(b.MouseEnter:Connect(function() if not self.Closing then state.Hover=true;paint() end end))
        register(b.MouseLeave:Connect(function() state.Hover=false;state.Pressed=false;paint() end))
        register(b.InputBegan:Connect(function(e)
            if not self.Closing and (e.UserInputType==Enum.UserInputType.MouseButton1 or e.UserInputType==Enum.UserInputType.Touch) then
                state.Pressed=true;paint()
            end
        end))
        return b
    end
    local title=text(window,"Title","Auto Candy",15,5,230,38,20);title.Font=Enum.Font.GothamBold;title.Active=true
    local collapse=button("Collapse","−",265,10,28,28)
    local close=button("Close","×",302,10,28,28)
    local body=make("CanvasGroup",{Name="Body",Position=UDim2.fromOffset(0,46),Size=UDim2.fromOffset(340,356),GroupTransparency=0,BackgroundTransparency=1},window)
    text(body,"Subtitle","Поиск → ТП → клик → проверка стука",15,0,310,24,11)
    self.AutoButton=button("Auto","Авто: OFF",15,34,148,42,body)
    self.TeleportButton=button("Teleport","Телепорт",177,34,148,42,body)
    self.HopButton=button("ServerHop","Смена серверов: OFF",15,84,310,38,body)
    self.State=text(body,"State","Ожидание",15,130,310,30,12)
    text(body,"LogTitle","ЛОГИ",15,166,310,18,10)
    local scroll=make("ScrollingFrame",{Name="LogPanel",Position=UDim2.fromOffset(15,188),Size=UDim2.fromOffset(310,130),
        BackgroundColor3=rgb(251,247,255),BackgroundTransparency=.15,BorderSizePixel=0,ScrollBarThickness=3,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},body);round(scroll,10)
    local logs=make("TextLabel",{Name="LogText",Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-22,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=Enum.Font.Code,TextSize=11,
        TextColor3=rgb(72,44,101),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true,Text="",RichText=false},scroll)
    local credit=text(body,"Credit","By: Probothotspot",15,327,310,16,10)
    credit.TextXAlignment=Enum.TextXAlignment.Center
    local resize=button("Resize","↘",313,375,22,22)
    resize.TextSize=17;resize.BackgroundTransparency=.25
    function self:log(message)
        if self.Destroyed then return end
        self.Lines[#self.Lines+1]=os.date("%H:%M:%S").."  "..tostring(message)
        if #self.Lines>50 then table.remove(self.Lines,1) end
        logs.Text=table.concat(self.Lines,"\n")
        self.LastMessage=tostring(message)
        self.State.Text=self.LastMessage;self.LastShownState=self.LastMessage
    end
    function self:update(app,hopper,actions)
        if self.Destroyed then return end
        if self.AutoShown~=app.Auto then
            self.AutoShown=app.Auto
            self.AutoButton.Text=app.Auto and "Авто: ON" or "Авто: OFF"
            local state=self.Buttons[self.AutoButton]
            state.Base=app.Auto and rgb(185,139,237) or rgb(184,138,232);state.Paint()
        end
        local hop=hopper and hopper.Enabled or false
        if self.HopShown~=hop then self.HopShown=hop;self.HopButton.Text=hop and "Смена серверов: ON" or "Смена серверов: OFF" end
        if self.BusyShown~=app.Busy then self.BusyShown=app.Busy;self.TeleportButton.Text=app.Busy and "Выполняется…" or "Телепорт" end
        local state=actions and not actions.Ready and ("Индексация в фоне: "..actions.Scanned.." объектов") or self.LastMessage or "Ожидание"
        if self.LastShownState~=state then self.LastShownState=state;self.State.Text=state end
    end
    function self:clickVisibility(show)
        if not self.Destroyed then
            gui.Enabled=show
            if show and not self.Closing then window.GroupTransparency=.2;animate(window,"fade",{GroupTransparency=0},.16) end
        end
    end
    local function fit(smooth)
        local area=safe.AbsoluteSize
        if area.X<=0 or area.Y<=0 then return end
        local h=self.Collapsed and 46 or 402
        local target=math.max(.1,math.min(self.UserScale,(area.X-16)/340,(area.Y-16)/h))
        if smooth then animate(scale,"resize",{Scale=target},.08)
        else
            local channels=self.Motion[scale];if channels and channels.resize then channels.resize:Cancel() end
            scale.Scale=target
        end
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset
        local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-340*target)),
            math.clamp(y,0,math.max(0,area.Y-h*target)))
    end
    register(safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit(false) end))
    register(collapse.Activated:Connect(function()
        if self.Closing then return end
        self.Collapsed=not self.Collapsed;body.Visible=true;resize.Visible=not self.Collapsed
        animate(body,"fade",{GroupTransparency=self.Collapsed and 1 or 0},.16)
        animate(window,"height",{Size=UDim2.fromOffset(340,self.Collapsed and 46 or 402)},.25)
        self.CollapseDue=os.clock()+.26
        collapse.Text=self.Collapsed and "+" or "−";fit(true)
    end))
    local drag,pointer,origin,resizing
    register(title.InputBegan:Connect(function(e)
        if not self.Closing and (e.UserInputType==Enum.UserInputType.MouseButton1 or e.UserInputType==Enum.UserInputType.Touch) then
            drag,pointer,origin=e,e.Position,window.Position
        end
    end))
    register(resize.InputBegan:Connect(function(e)
        if not self.Collapsed and not self.Closing and (e.UserInputType==Enum.UserInputType.MouseButton1 or e.UserInputType==Enum.UserInputType.Touch) then
            resizing={Input=e,Pointer=e.Position,Scale=scale.Scale};drag=nil
        end
    end))
    register(input.InputChanged:Connect(function(e)
        if self.Closing then return end
        if resizing then
            if e~=resizing.Input and e.UserInputType~=Enum.UserInputType.MouseMovement then return end
            local delta=e.Position-resizing.Pointer
            local dx,dy=delta.X/340,delta.Y/402
            self.UserScale=math.clamp(resizing.Scale+(math.abs(dx)>math.abs(dy) and dx or dy),.65,1.6)
            fit(true);return
        end
        if not drag then return end
        if e~=drag and not (drag.UserInputType==Enum.UserInputType.MouseButton1 and e.UserInputType==Enum.UserInputType.MouseMovement) then return end
        local delta=e.Position-pointer
        window.Position=UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y);fit()
    end))
    register(input.InputEnded:Connect(function(e)
        if e==drag then drag=nil end
        if resizing and e==resizing.Input then resizing=nil end
        if e.UserInputType==Enum.UserInputType.MouseButton1 or e.UserInputType==Enum.UserInputType.Touch then
            for _,s in pairs(self.Buttons) do if s.Pressed then s.Pressed=false;s.Paint() end end
        end
    end))
    register(input.WindowFocusReleased:Connect(function()
        drag=nil;resizing=nil
        for _,s in pairs(self.Buttons) do s.Pressed=false;s.Hover=false;s.Paint() end
    end))
    function self:closeAnimated(done)
        if self.Closing or self.Destroyed then return end
        self.Closing=true;drag=nil;resizing=nil;self.CloseDone=done;self.CloseDue=os.clock()+.23
        animate(window,"fade",{GroupTransparency=1},.22)
        local p=window.Position
        animate(window,"position",{Position=UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+14)},.22)
    end
    register(game:GetService("RunService").Heartbeat:Connect(function()
        if self.Destroyed then return end
        if self.CollapseDue and os.clock()>=self.CollapseDue then self.CollapseDue=nil;body.Visible=not self.Collapsed end
        if self.CloseDue and os.clock()>=self.CloseDue then
            self.CloseDue=nil;local done=self.CloseDone;self.CloseDone=nil;if done then done() end
        end
    end))
    local shimmer=tween:Create(gradient,TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Rotation=360})
    local creditShimmer=tween:Create(credit,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{TextColor3=rgb(106,83,126)})
    self.Tweens={shimmer,creditShimmer};shimmer:Play();creditShimmer:Play()
    self.CloseButton=close
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        for _,t in ipairs(self.Tweens) do t:Cancel() end
        for _,channels in pairs(self.Motion) do for _,t in pairs(channels) do t:Cancel() end end
        self.Motion={};self.CloseDone=nil
        gui:Destroy()
    end
    fit(false)
    local p=window.Position;window.Position=UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+14)
    animate(window,"position",{Position=p},.3);animate(window,"fade",{GroupTransparency=0},.3)
    return self
end
return Gui
