local Actions={}
function Actions.new(player,world,core,register,log,setClickVisibility)
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
        local input=game:GetService("VirtualInputManager")
        return {Character=c,Root=r,Humanoid=h,Origin=r.CFrame,Camera=camera,CameraCF=camera.CFrame,
            CameraFocus=camera.Focus,CameraType=camera.CameraType,CameraSubject=camera.CameraSubject,Input=input}
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
        setClickVisibility(false); ctx.UIHidden=true
    end
    function self:mouseDown(ctx,door)
        assert(world.CurrentCamera==ctx.Camera,"Камера сменилась")
        assert((ctx.Root.Position-door.Position).Magnitude<20,"Сервер отменил ТП или дверь переместилась")
        local point,visible=ctx.Camera:WorldToViewportPoint(door.Position)
        assert(visible and point.Z>0,"Дверь не попала в экран")
        ctx.Mouse={X=point.X,Y=point.Y}; ctx.MouseHeld=true
        ctx.Input:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
    end
    function self:mouseUp(ctx)
        if ctx.MouseHeld then
            local m=ctx.Mouse
            ctx.Input:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)
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
