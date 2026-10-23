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
    local self={Auto=false,Busy=false,Destroyed=false,Phase="idle",Visited=setmetatable({},{__mode="k"}),Confirmed=setmetatable({},{__mode="k"}),Cooldown=setmetatable({},{__mode="k"}),NextScan=0}
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
    function self:nextClick(problem)
        -- Never start another backend while a prior mouse button remains held.
        local released,err=pcall(actions.mouseUp,actions,self.Context)
        if not released then self:finish("Не удалось отпустить мышь: "..tostring(err));return end
        if problem then message(problem) end
        self.ClickIndex=(self.ClickIndex or 0)+1
        if self.ClickIndex>(self.ClickCount or 0) then
            self.Visited[self.Door]=true
            message("Стук не подтверждён: способы исчерпаны. Конфеты не считаются полученными")
            self.Phase="return";self.Due=clock()+.15
        else
            self.Phase="prepare";self.Due=clock()+.2
        end
    end
    function self:step()
        if self.Destroyed then return end
        if self.Busy then
            local valid,reason=actions:valid(self.Context,self.Door)
            if not valid then self:finish(reason or "Дверь или персонаж недоступны"); return end
            local heard,candidate,ready=actions:feedback(self.Context)
            if heard and self.Phase~="return" then
                actions:mouseUp(self.Context)
                actions:confirmed(self.Context)
                self.Visited[self.Door]=true;self.Confirmed[self.Door]=true
                message("Стук обнаружен: "..heard.Name.." | "..heard.Id.." | "..tostring(self.ClickMethod))
                self.Phase="return";self.Due=clock()+.3
            end
            if clock()<self.Due then return end
            local ok,err=pcall(function()
                if self.Phase=="settle" then
                    actions:aim(self.Context,self.Door)
                    self.ClickCount=actions:beginFeedback(self.Context,self.Door)
                    self.ClickIndex=0;self.Phase="observe";self.Due=clock()+.15;self.ObserveDeadline=clock()+1
                elseif self.Phase=="observe" then
                    if ready==false and clock()<self.ObserveDeadline then self.Due=clock()+.05;return end
                    self:nextClick()
                elseif self.Phase=="prepare" then
                    self.ClickMethod=actions:prepareClick(self.Context,self.Door,self.ClickIndex)
                    message("Наведение: "..self.ClickMethod.." ("..self.ClickIndex.."/"..self.ClickCount..")")
                    self.Phase="hover";self.Due=clock()+.15
                elseif self.Phase=="hover" then
                    actions:mouseDown(self.Context,self.Door)
                    self.Phase="pressed"; self.Due=clock()+.12
                elseif self.Phase=="pressed" then
                    actions:mouseUp(self.Context)
                    message("Взаимодействие отправлено: "..self.ClickMethod..". Ожидание стука…")
                    self.Phase="listen";self.Due=clock()+1.8
                elseif self.Phase=="listen" then
                    if candidate then
                        self.Visited[self.Door]=true
                        message("Звук двери: "..candidate.Name.." | "..candidate.Id..". Тип звука неизвестен; повтор отменён")
                        self.Phase="return";self.Due=clock()+.3
                    else self:nextClick("Стук не обнаружен; проверяю следующий способ") end
                elseif self.Phase=="return" then self:finish() end
            end)
            if not ok then
                if self.Phase=="prepare" or self.Phase=="hover" then self:nextClick("Ввод: "..tostring(err))
                else self:finish("Ошибка: "..tostring(err)) end
            end
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
