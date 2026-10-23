local Actions={}
function Actions.new(player,world,core,register,log,setClickVisibility,Feedback)
    local self={Doors=setmetatable({},{__mode="k"}),Ready=false,Destroyed=false,Scanned=0,
        Stack={{Node=world}},Pending={}}
    local function index(o)
        if o:IsDescendantOf(world) and core.isDoor(o,world) then self.Doors[o]=true end
    end
    register(world.DescendantAdded:Connect(function(o)
        -- Constant-time event callback. Ancestor inspection runs in the budgeted worker.
        if not self.Destroyed and o:IsA("BasePart") and o.Name:lower()=="doorinnertouch" then self.Pending[o]=true end
    end))
    register(world.DescendantRemoving:Connect(function(o) self.Doors[o]=nil;self.Pending[o]=nil end))
    function self:serviceIndex()
        if self.Destroyed then return end
        local began=os.clock();local work=0
        -- DFS keeps only the active ancestor chain. No whole-Workspace GetDescendants allocation.
        while #self.Stack>0 and work<128 and os.clock()-began<.002 do
            local frame=self.Stack[#self.Stack]
            work=work+1
            if not frame.Children then
                frame.Children=frame.Node:GetChildren();frame.Index=1
            elseif frame.Index>#frame.Children then
                table.remove(self.Stack)
            else
                local o=frame.Children[frame.Index];frame.Index=frame.Index+1
                self.Scanned=self.Scanned+1
                if o:IsDescendantOf(world) then
                    index(o);self.Stack[#self.Stack+1]={Node=o}
                end
            end
        end
        local handled=0
        for o in pairs(self.Pending) do
            if handled>=32 or os.clock()-began>=.002 then break end
            self.Pending[o]=nil;index(o);handled=handled+1
        end
        if #self.Stack==0 and not self.Ready then self.Ready=true;log("Индекс дверей готов: проверено "..self.Scanned.." объектов") end
    end
    function self:doors()
        if not self.Ready then return {} end
        local found={}
        for p in pairs(self.Doors) do
            if p:IsDescendantOf(world) and core.isDoor(p,world) then found[#found+1]=p
            else self.Doors[p]=nil end
        end
        return found
    end
    function self:body()
        local c=player.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local r=c and c:FindFirstChild("HumanoidRootPart")
        if h and h.Health>0 and r and r:IsA("BasePart") then return c,r,h end
    end
    function self:distance(p)
        local _,r=self:body(); return r and (r.Position-p.Position).Magnitude
    end
    function self:capture()
        local c,r,h=self:body(); assert(r,"Персонаж недоступен")
        assert(not h.Sit,"Выйди из сиденья перед запуском")
        local camera=world.CurrentCamera; assert(camera,"Камера недоступна")
        local _,input=pcall(game.GetService,game,"VirtualInputManager")
        local userInput=game:GetService("UserInputService")
        local virtualOK,virtual=pcall(function() return userInput:CreateVirtualInput() end)
        local mouseOK,mouse=pcall(function() return userInput:GetMouseLocation() end)
        return {Character=c,Root=r,Humanoid=h,Origin=r.CFrame,Camera=camera,CameraCF=camera.CFrame,
            CameraFocus=camera.Focus,CameraType=camera.CameraType,CameraSubject=camera.CameraSubject,
            Input=type(input)~="string" and input or nil,UserInput=userInput,MouseBehavior=userInput.MouseBehavior,
            OriginalMouse=mouseOK and mouse or nil,Virtual=virtualOK and virtual or nil}
    end
    local function pivot(context,cf)
        local c,r=context.Character,context.Root
        c:PivotTo(cf*r.CFrame:ToObjectSpace(c:GetPivot()))
        r.AssemblyLinearVelocity=Vector3.zero; r.AssemblyAngularVelocity=Vector3.zero
    end
    function self:approach(ctx,door)
        -- Use the thin local horizontal axis, then choose the closer face.
        -- No fixed world position, colour, material or house-name check.
        local axis=door.Size.X<door.Size.Z and door.CFrame.RightVector or door.CFrame.LookVector
        local normal=Vector3.new(axis.X,0,axis.Z)
        assert(normal.Magnitude>.1,"Не удалось определить горизонтальную сторону двери")
        normal=normal.Unit
        if (ctx.Origin.Position-door.Position):Dot(normal)<0 then normal=-normal end
        local candidates={normal,-normal}
        local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances={ctx.Character,door}; ray.RespectCanCollide=true
        local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances={ctx.Character}; overlap.RespectCanCollide=true
        local halfY=math.abs(door.CFrame.RightVector.Y)*door.Size.X/2
            +math.abs(door.CFrame.UpVector.Y)*door.Size.Y/2+math.abs(door.CFrame.LookVector.Y)*door.Size.Z/2
        for _,direction in ipairs(candidates) do
            local extent=math.abs(direction:Dot(door.CFrame.RightVector))*door.Size.X/2
                +math.abs(direction:Dot(door.CFrame.UpVector))*door.Size.Y/2
                +math.abs(direction:Dot(door.CFrame.LookVector))*door.Size.Z/2
            local offset=door.Position+direction*(extent+2)
            local baseY=door.Position.Y-halfY
            local hit=world:Raycast(Vector3.new(offset.X,baseY+8,offset.Z),Vector3.new(0,-24,0),ray)
            if hit and hit.Normal.Y>.7 then
                local height=math.max(3,ctx.Humanoid.HipHeight+ctx.Root.Size.Y/2)
                local position=Vector3.new(offset.X,hit.Position.Y+height+.1,offset.Z)
                local blocks=world:GetPartBoundsInBox(CFrame.new(position),Vector3.new(2.5,4,2.5),overlap)
                if #blocks==0 then
                    pivot(ctx,CFrame.lookAt(position,Vector3.new(door.Position.X,position.Y,door.Position.Z)))
                    return
                end
            end
        end
        error("Нет свободной площадки в 2 studs от двери")
    end
    function self:valid(ctx,door)
        local c,r=self:body()
        if c~=ctx.Character or r~=ctx.Root then return false,"Персонаж погиб или сменился" end
        if not door:IsDescendantOf(world) then return false,"Дверь исчезла" end
        return true
    end
    function self:aim(ctx,door)
        assert(world.CurrentCamera==ctx.Camera,"Камера сменилась")
        local camera=ctx.Camera
        camera.CameraType=Enum.CameraType.Scriptable; ctx.CameraChanged=true
        -- Camera is briefly placed near the player, looking at the touch part.
        local view=ctx.Root.Position+Vector3.new(0,1.5,0)
        camera.CFrame=CFrame.lookAt(view,door.Position)
        camera.Focus=CFrame.new(door.Position)
        ctx.UserInput.MouseBehavior=Enum.MouseBehavior.Default;ctx.MouseBehaviorChanged=true
        setClickVisibility(false); ctx.UIHidden=true
    end
    function self:beginFeedback(ctx,door)
        local scope=door.Parent
        while scope and scope~=world and scope.Name:lower()~="door" do scope=scope.Parent end
        assert(scope and scope~=world,"Контейнер Door исчез")
        ctx.Scope=scope;ctx.Methods={}
        if Feedback then ctx.Monitor=Feedback.new(scope) end
        -- Only use a detector that actually exists on this door, never invent remotes.
        local detector=door:FindFirstChildOfClass("ClickDetector") or scope:FindFirstChildOfClass("ClickDetector")
        if detector and type(fireclickdetector)=="function" then
            ctx.Methods[#ctx.Methods+1]={Name="ClickDetector",Detector=detector}
        end
        if ctx.Input then ctx.Methods[#ctx.Methods+1]={Name="VIM screen",Kind="screen"} end
        if ctx.Virtual then ctx.Methods[#ctx.Methods+1]={Name="VirtualInput",Kind="virtual"} end
        if ctx.Input then ctx.Methods[#ctx.Methods+1]={Name="VIM viewport",Kind="viewport"} end
        for i,method in ipairs(ctx.Methods) do
            if method.Name==self.PreferredBackend then table.remove(ctx.Methods,i);table.insert(ctx.Methods,1,method);break end
        end
        assert(#ctx.Methods>0,"Нет доступного способа ввода")
        log("Проверка клика: "..#ctx.Methods.." способов; слушаю Sound выбранной двери")
        return #ctx.Methods
    end
    function self:confirmed(ctx) self.PreferredBackend=ctx.Method and ctx.Method.Name end
    function self:feedback(ctx)
        if not ctx.Monitor then return nil end
        ctx.Monitor:step()
        if ctx.Monitor.Ready and not ctx.MonitorLogged then
            ctx.MonitorLogged=true
            log(ctx.Monitor.Count>0 and ("Звуков в Door: "..ctx.Monitor.Count)
                or "В Door нет Sound: локальный слушатель не сможет подтвердить стук")
        end
        return ctx.Monitor.Result,ctx.Monitor.Candidate,ctx.Monitor.Ready
    end
    function self:prepareClick(ctx,door,index)
        local method=assert(ctx.Methods[index],"Способы клика закончились")
        ctx.Method=method
        assert(world.CurrentCamera==ctx.Camera,"Камера сменилась")
        if type(isrbxactive)=="function" then assert(isrbxactive(),"Окно Roblox не в фокусе") end
        if method.Detector then return method.Name end
        local point,visible
        if method.Kind=="viewport" then point,visible=ctx.Camera:WorldToViewportPoint(door.Position)
        else point,visible=ctx.Camera:WorldToScreenPoint(door.Position) end
        assert(visible and point.Z>0,"Дверь не попала в экран")
        ctx.Mouse={X=math.floor(point.X+.5),Y=math.floor(point.Y+.5)}
        if method.Kind=="virtual" then
            ctx.Virtual:SendMousePosition(Vector2.new(ctx.Mouse.X,ctx.Mouse.Y))
        else
            ctx.Input:SendMouseMoveEvent(ctx.Mouse.X,ctx.Mouse.Y,game)
        end
        return method.Name
    end
    function self:mouseDown(ctx,door)
        assert(world.CurrentCamera==ctx.Camera,"Камера сменилась")
        assert((ctx.Root.Position-door.Position).Magnitude<20,"Сервер отменил ТП или дверь переместилась")
        if ctx.Monitor then ctx.Monitor:arm() end
        local method=ctx.Method
        if method.Detector then
            assert(method.Detector:IsDescendantOf(ctx.Scope),"ClickDetector исчез")
            fireclickdetector(method.Detector)
        else
            ctx.MouseHeld=true
            if method.Kind=="virtual" then
                ctx.Virtual:SendMouseButton(Vector2.new(ctx.Mouse.X,ctx.Mouse.Y),Enum.UserInputType.MouseButton1,true,0)
            else ctx.Input:SendMouseButtonEvent(ctx.Mouse.X,ctx.Mouse.Y,0,true,game,0) end
        end
    end
    function self:mouseUp(ctx)
        if ctx.MouseHeld then
            local m=ctx.Mouse
            if ctx.Method.Kind=="virtual" then
                ctx.Virtual:SendMouseButton(Vector2.new(m.X,m.Y),Enum.UserInputType.MouseButton1,false,0)
            else ctx.Input:SendMouseButtonEvent(m.X,m.Y,0,false,game,0) end
            ctx.MouseHeld=false
        end
    end
    function self:restore(ctx)
        if not ctx then return end
        local problems={}
        local function attempt(fn)
            local ok,err=pcall(fn); if not ok then problems[#problems+1]=tostring(err) end
        end
        attempt(function() self:mouseUp(ctx) end)
        if ctx.Monitor then attempt(function() ctx.Monitor:Destroy() end) end
        if ctx.MouseBehaviorChanged then attempt(function() ctx.UserInput.MouseBehavior=ctx.MouseBehavior end) end
        if ctx.OriginalMouse and ctx.Method and not ctx.Method.Detector then
            attempt(function()
                local p=ctx.OriginalMouse
                if ctx.Method.Kind=="virtual" then ctx.Virtual:SendMousePosition(p)
                else ctx.Input:SendMouseMoveEvent(p.X,p.Y,game) end
            end)
        end
        if ctx.CameraChanged then
            attempt(function()
                if world.CurrentCamera==ctx.Camera then
                    ctx.Camera.CameraSubject=ctx.CameraSubject
                    ctx.Camera.CFrame=ctx.CameraCF;ctx.Camera.Focus=ctx.CameraFocus
                    ctx.Camera.CameraType=ctx.CameraType
                end
            end)
        end
        if ctx.UIHidden then attempt(function() setClickVisibility(true) end) end
        attempt(function()
            local c,r=self:body()
            assert(c==ctx.Character and r==ctx.Root,"Возвращать новый/мёртвый персонаж нельзя")
            pivot(ctx,ctx.Origin)
        end)
        if #problems>0 then error(table.concat(problems,"; ")) end
    end
    function self:Destroy() self.Destroyed=true;self.Doors={};self.Pending={};self.Stack={} end
    return self
end
return Actions
