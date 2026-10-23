local Gui={}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function make(class,props,parent)
    local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function round(o,n) make("UICorner",{CornerRadius=UDim.new(0,n or 10)},o) end
function Gui.mount(player,register)
    local self={Lines={},Collapsed=false,Destroyed=false,Tweens={}}
    local tween=game:GetService("TweenService")
    local input=game:GetService("UserInputService")
    local gui=make("ScreenGui",{Name="AutoCandyGUI",ResetOnSpawn=false,DisplayOrder=1000,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
    self.Gui=gui
    local safe=make("Frame",{Name="SafeArea",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make("Frame",{Name="Window",Size=UDim2.fromOffset(340,402),Position=UDim2.new(.5,-170,.5,-201),
        BackgroundColor3=rgb(66,32,102),BorderSizePixel=0,ClipsDescendants=true},safe);round(window,16)
    local scale=make("UIScale",{Scale=1},window)
    make("UIStroke",{Color=rgb(188,119,255),Thickness=1,Transparency=.3},window)
    local gradient=make("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,rgb(116,59,177)),
        ColorSequenceKeypoint.new(.5,rgb(55,30,84)),ColorSequenceKeypoint.new(1,rgb(30,23,47))}),Rotation=0},window)
    local function text(parent,name,value,x,y,w,h,size)
        return make("TextLabel",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundTransparency=1,TextColor3=rgb(245,233,255),Font=Enum.Font.Gotham,TextSize=size or 12,
            TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},parent)
    end
    local function button(name,value,x,y,w,h,parent)
        local b=make("TextButton",{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundColor3=rgb(96,53,145),TextColor3=rgb(255,245,255),Font=Enum.Font.GothamBold,
            TextSize=14,BorderSizePixel=0,AutoButtonColor=true},parent or window);round(b,9);return b
    end
    local title=text(window,"Title","Auto Candy",15,5,230,38,20);title.Font=Enum.Font.GothamBold;title.Active=true
    local collapse=button("Collapse","−",265,10,28,28)
    local close=button("Close","×",302,10,28,28)
    local body=make("Frame",{Name="Body",Position=UDim2.fromOffset(0,46),Size=UDim2.new(1,0,1,-46),BackgroundTransparency=1},window)
    text(body,"Subtitle","Поиск → ТП → один клик → возврат",15,0,310,24,11)
    self.AutoButton=button("Auto","Авто: OFF",15,34,148,42,body)
    self.TeleportButton=button("Teleport","Телепорт",177,34,148,42,body)
    self.HopButton=button("ServerHop","Смена серверов: OFF",15,84,310,38,body)
    self.State=text(body,"State","Ожидание",15,130,310,30,12)
    text(body,"LogTitle","ЛОГИ",15,166,310,18,10)
    local scroll=make("ScrollingFrame",{Name="LogPanel",Position=UDim2.fromOffset(15,188),Size=UDim2.fromOffset(310,130),
        BackgroundColor3=rgb(19,16,29),BackgroundTransparency=.15,BorderSizePixel=0,ScrollBarThickness=3,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},body);round(scroll,10)
    local logs=make("TextLabel",{Name="LogText",Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-22,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=Enum.Font.Code,TextSize=11,
        TextColor3=rgb(220,203,240),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true,Text="",RichText=false},scroll)
    local credit=text(body,"Credit","By: Probothotspot",15,327,310,16,10)
    credit.TextXAlignment=Enum.TextXAlignment.Center
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
            self.AutoButton.BackgroundColor3=app.Auto and rgb(145,77,200) or rgb(96,53,145)
        end
        local hop=hopper and hopper.Enabled or false
        if self.HopShown~=hop then self.HopShown=hop;self.HopButton.Text=hop and "Смена серверов: ON" or "Смена серверов: OFF" end
        if self.BusyShown~=app.Busy then self.BusyShown=app.Busy;self.TeleportButton.Text=app.Busy and "Выполняется…" or "Телепорт" end
        local state=actions and not actions.Ready and ("Индексация в фоне: "..actions.Scanned.." объектов") or self.LastMessage or "Ожидание"
        if self.LastShownState~=state then self.LastShownState=state;self.State.Text=state end
    end
    function self:clickVisibility(show) if not self.Destroyed then gui.Enabled=show end end
    local function fit()
        local area=safe.AbsoluteSize
        if area.X<=0 or area.Y<=0 then return end
        local h=self.Collapsed and 46 or 402
        scale.Scale=math.max(.1,math.min(1,(area.X-16)/340,(area.Y-16)/h))
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset
        local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-340*scale.Scale)),
            math.clamp(y,0,math.max(0,area.Y-h*scale.Scale)))
    end
    register(safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    register(collapse.Activated:Connect(function()
        self.Collapsed=not self.Collapsed;body.Visible=not self.Collapsed
        window.Size=UDim2.fromOffset(340,self.Collapsed and 46 or 402)
        collapse.Text=self.Collapsed and "+" or "−";fit()
    end))
    local drag,pointer,origin
    register(title.InputBegan:Connect(function(e)
        if e.UserInputType==Enum.UserInputType.MouseButton1 or e.UserInputType==Enum.UserInputType.Touch then
            drag,pointer,origin=e,e.Position,window.Position
        end
    end))
    register(input.InputChanged:Connect(function(e)
        if not drag then return end
        if e~=drag and not (drag.UserInputType==Enum.UserInputType.MouseButton1 and e.UserInputType==Enum.UserInputType.MouseMovement) then return end
        local delta=e.Position-pointer
        window.Position=UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y);fit()
    end))
    register(input.InputEnded:Connect(function(e) if e==drag then drag=nil end end))
    register(input.WindowFocusReleased:Connect(function() drag=nil end))
    local shimmer=tween:Create(gradient,TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Rotation=360})
    local creditShimmer=tween:Create(credit,TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{TextColor3=rgb(155,155,170)})
    self.Tweens={shimmer,creditShimmer};shimmer:Play();creditShimmer:Play()
    self.CloseButton=close
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        for _,t in ipairs(self.Tweens) do t:Cancel() end
        gui:Destroy()
    end
    fit();return self
end
return Gui
