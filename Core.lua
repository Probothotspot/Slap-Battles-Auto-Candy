local Core={}
function Core.isDoor(part,world)
    if not part:IsA("BasePart") or part.Name:lower()~="doorinnertouch" then return false end
    local p=part.Parent
    while p and p~=world do
        if p.Name:lower()=="door" then return true end
        p=p.Parent
    end
    return false
end
function Core.new(actions,clock,log)
    clock=clock or os.clock; log=log or function() end
    local self={Auto=false,Busy=false,Destroyed=false,Phase="idle",Visited=setmetatable({},{__mode="k"}),Cooldown=setmetatable({},{__mode="k"}),NextScan=0}
    local function message(s) log(s) end
    function self:finish(reason)
        if not self.Busy then return end
        local context=self.Context
        -- Release pointer and camera even when teleport/click raised an error.
        local ok,err=pcall(actions.restore,actions,context)
        self.Busy=false; self.Phase="idle"; self.Context=nil; self.Door=nil
        if reason then message(reason) end
        message(ok and "Возврат в исходную позицию выполнен" or ("Возврат не выполнен: "..tostring(err)))
    end
    function self:attempt(manual)
        if self.Destroyed or self.Busy then return false end
        if actions.Ready==false then
            if manual then message("Индекс дверей ещё строится, попробуй через секунду") end
            return false
        end
        local ok,doorOrError=pcall(function()
            local found=actions:doors()
            local best,bestDistance
            for _,door in ipairs(found) do
                if manual or ((not self.HopMode or not self.Visited[door]) and (self.Cooldown[door] or 0)<=clock()) then
                    local distance=actions:distance(door)
                    if distance and (not bestDistance or distance<bestDistance) then best,bestDistance=door,distance end
                end
            end
            if not best then
                if manual or #found==0 then
                    if manual or clock()>=(self.NextEmptyLog or 0) then
                        message("Нет существующих объектов DoorInnerTouch / Door")
                        self.NextEmptyLog=clock()+10
                    end
                end
                return nil
            end
            return best
        end)
        if not ok then message("Поиск: "..tostring(doorOrError)); return false end
        local door=doorOrError; if not door then return false end
        self.Cooldown[door]=clock()+120
        local good,context=pcall(actions.capture,actions)
        if not good then message("Запуск: "..tostring(context)); return false end
        self.Busy=true; self.Context=context; self.Door=door
        local moved,err=pcall(actions.approach,actions,context,door)
        if not moved then self:finish("ТП: "..tostring(err)); return false end
        self.Phase="settle"; self.Due=clock()+.35
        message("Дверь найдена. ТП на 2 studs от поверхности")
        return true
    end
    function self:setAuto(value)
        if self.Destroyed then return end
        self.Auto=value==true
        message(self.Auto and "Авто: ON — пассивное ожидание дверей" or "Авто: OFF")
        if not self.Auto then self:finish("Операция отменена") end
        self.NextScan=0
    end
    function self:step()
        if self.Destroyed then return end
        if self.Busy then
            local valid,reason=actions:valid(self.Context,self.Door)
            if not valid then self:finish(reason or "Дверь или персонаж недоступны"); return end
            if clock()<self.Due then return end
            local ok,err=pcall(function()
                if self.Phase=="settle" then
                    actions:aim(self.Context,self.Door)
                    self.Phase="aim"; self.Due=clock()+.12
                elseif self.Phase=="aim" then
                    actions:mouseDown(self.Context,self.Door)
                    self.Phase="pressed"; self.Due=clock()+.08
                elseif self.Phase=="pressed" then
                    actions:mouseUp(self.Context)
                    self.Visited[self.Door]=true
                    message("Один виртуальный клик отправлен; выдачу конфет определяет игра")
                    self.Phase="return"; self.Due=clock()+.4
                elseif self.Phase=="return" then self:finish() end
            end)
            if not ok then self:finish("Ошибка: "..tostring(err)) end
        elseif self.Auto and clock()>=self.NextScan then
            self.NextScan=clock()+2; self:attempt(false)
        end
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Auto=false; self:finish("Остановка скрипта"); self.Destroyed=true
    end
    return self
end
return Core
