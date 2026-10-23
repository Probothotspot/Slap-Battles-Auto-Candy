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
    local self={Auto=false,Busy=false,Destroyed=false,Waiting=false,Phase="idle",Visited=setmetatable({},{__mode="k"}),
        VisitedGeneration=setmetatable({},{__mode="k"}),AttemptGeneration=setmetatable({},{__mode="k"}),
        Confirmed=setmetatable({},{__mode="k"}),Cooldown=setmetatable({},{__mode="k"}),NextScan=0,NewDoorDelay=1}
    local function message(s) log(s) end
    local function generation(door) return actions.generation and actions:generation(door) or 0 end
    function self:isProcessed(door)
        return self.Visited[door]==true and (self.VisitedGeneration[door] or 0)==generation(door)
    end
    function self:markProcessed(door)
        self.Visited[door]=true;self.VisitedGeneration[door]=generation(door)
    end
    function self:scheduleRetry(door,manual)
        self.RetryDoor=door;self.RetryGeneration=generation(door);self.RetryManual=manual==true
        self.RetryAt=clock()+3;self.Cooldown[door]=self.RetryAt;self.PendingManual=false
        message("Взаимодействие не подтверждено. Повтор той же двери через 3 с")
    end
    function self:finish(reason,retry)
        if not self.Busy then return end
        local context=self.Context
        local door,manual=self.Door,self.ManualRun
        if retry==nil then retry=self.RetryNeeded end
        self.RetryNeeded=false
        -- Release pointer and camera even when teleport/click raised an error.
        local ok,err=pcall(actions.restore,actions,context)
        self.Busy=false; self.Phase="idle"; self.Context=nil; self.Door=nil
        if reason then message(reason) end
        message(ok and "Возврат в исходную позицию выполнен" or ("Возврат не выполнен: "..tostring(err)))
        if retry and door then self:scheduleRetry(door,manual) end
    end
    function self:attempt(manual,forcedDoor)
        if self.Destroyed or self.Busy then return false end
        if manual and not forcedDoor then self.RetryDoor=nil end
        if actions.Ready==false then
            if manual then message("Индекс дверей ещё строится, попробуй через секунду") end
            return false
        end
        local ok,doorOrError=pcall(function()
            local found=actions:doors()
            local best,bestDistance,earliest,waitingForBody
            for _,door in ipairs(found) do
                if self.AttemptGeneration[door]~=generation(door) then self.Cooldown[door]=nil end
                if (not forcedDoor or door==forcedDoor) and
                    (forcedDoor or manual or (not self:isProcessed(door) and (self.Cooldown[door] or 0)<=clock())) then
                    local wait=actions.waitRemaining and actions:waitRemaining(door,self.NewDoorDelay,clock()) or 0
                    if wait>0 then earliest=math.min(earliest or math.huge,clock()+wait)
                    else
                        local distance=actions:distance(door)
                        if distance and (not bestDistance or distance<bestDistance) then best,bestDistance=door,distance end
                        if not distance and forcedDoor then earliest=clock()+3;waitingForBody=true end
                    end
                end
            end
            if not best then
                if earliest then
                    self.PendingManual=manual==true and not forcedDoor
                    self.NextScan=earliest
                    if forcedDoor then self.RetryAt=earliest end
                    if not self.Waiting or manual then
                        message(waitingForBody and "Персонаж недоступен: повтор через 3 с" or
                            ("Новая дверь: ожидание "..string.format("%.2f",earliest-clock()).." с"))
                    end
                elseif manual then message("Нет существующих объектов DoorInnerTouch / Door")
                elseif not self.Waiting or clock()>=(self.NextEmptyLog or 0) then
                    message("Авто: ожидание новых дверей — наблюдение продолжается")
                    self.NextEmptyLog=clock()+15
                end
                self.Waiting=earliest~=nil or not manual
                if not earliest then self.PendingManual=false end
                if forcedDoor and not earliest then self.RetryDoor=nil end
                return nil
            end
            return best
        end)
        if not ok then
            message("Поиск: "..tostring(doorOrError))
            if forcedDoor then self:scheduleRetry(forcedDoor,manual) end
            return false
        end
        local door=doorOrError; if not door then return false end
        self.RetryDoor=nil;self.RetryNeeded=false;self.ManualRun=manual==true
        self.Waiting=false;self.PendingManual=false;self.AttemptGeneration[door]=generation(door)
        local good,context=pcall(actions.capture,actions)
        if not good then message("Запуск: "..tostring(context));self:scheduleRetry(door,manual);return false end
        self.Cooldown[door]=clock()+120
        self.Busy=true; self.Context=context; self.Door=door
        local moved,err=pcall(actions.approach,actions,context,door)
        if not moved then self:finish("ТП: "..tostring(err),true); return false end
        self.Phase="settle"; self.Due=clock()+.35
        message("Дверь найдена. ТП на 2 studs от поверхности")
        return true
    end
    function self:setAuto(value)
        if self.Destroyed then return end
        self.Auto=value==true
        self.Waiting=false
        if not self.Auto then self.PendingManual=false;self.RetryDoor=nil end
        message(self.Auto and "Авто: ON — пассивное ожидание дверей" or "Авто: OFF")
        if not self.Auto then self:finish("Операция отменена",false) end
        self.NextScan=0
    end
    function self:nextClick(problem)
        -- Never start another backend while a prior mouse button remains held.
        local released,err=pcall(actions.mouseUp,actions,self.Context)
        if not released then self:finish("Не удалось отпустить мышь: "..tostring(err),true);return end
        if problem then message(problem) end
        self.ClickIndex=(self.ClickIndex or 0)+1
        if self.ClickIndex>(self.ClickCount or 0) then
            self.RetryNeeded=true
            message("Стук не подтверждён: способы исчерпаны. Конфеты не считаются полученными")
            self.Phase="return";self.Due=clock()+.15
        else
            self.Phase="prepare";self.Due=clock()+.2
        end
    end
    function self:step()
        if self.Destroyed then return end
        if self.IndexRevision~=actions.Revision then
            self.IndexRevision=actions.Revision
            if self.Auto or self.PendingManual then self.NextScan=0 end
        end
        if self.Busy then
            local valid,reason=actions:valid(self.Context,self.Door)
            if not valid then self:finish(reason or "Дверь или персонаж недоступны",true); return end
            if self.AttemptGeneration[self.Door]~=generation(self.Door) then
                self:finish('Дверь появилась заново; старая попытка отменена',false);return
            end
            local heard,candidate,ready=actions:feedback(self.Context)
            if heard and self.Phase~="return" then
                actions:mouseUp(self.Context)
                actions:confirmed(self.Context)
                self:markProcessed(self.Door);self.Confirmed[self.Door]=true
                self.RetryNeeded=false
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
                        self.RetryNeeded=true
                        message("Звук двери: "..candidate.Name.." | "..candidate.Id..". Тип звука неизвестен; стук не подтвержден")
                        self.Phase="return";self.Due=clock()+.3
                    else self:nextClick("Стук не обнаружен; проверяю следующий способ") end
                elseif self.Phase=="return" then self:finish() end
            end)
            if not ok then
                if self.Phase=="prepare" or self.Phase=="hover" then self:nextClick("Ввод: "..tostring(err))
                else self:finish("Ошибка: "..tostring(err),true) end
            end
        elseif self.RetryDoor then
            local door=self.RetryDoor;local exists=false
            if generation(door)==self.RetryGeneration then
                for _,candidate in ipairs(actions:doors()) do if candidate==door then exists=true;break end end
            end
            if not exists then
                self.RetryDoor=nil;self.NextScan=0;message("Дверь повтора исчезла или появилась заново")
            elseif clock()>=self.RetryAt then self:attempt(self.RetryManual,door) end
        elseif (self.Auto or self.PendingManual) and clock()>=self.NextScan then
            local manual=self.PendingManual==true
            self.NextScan=clock()+2; self:attempt(manual)
        end
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Auto=false;self.PendingManual=false;self.RetryDoor=nil;self:finish("Остановка скрипта",false); self.Destroyed=true
    end
    return self
end
return Core
