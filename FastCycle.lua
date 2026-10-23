-- Fast client-side dispatch: one door per frame, no sound/reward acknowledgement.
local FastCycle={}
function FastCycle.attach(app,actions,clock,log)
    app.FastCycle=true;app.FastStats={Attempted=0,Dispatched=0,Failed=0}
    local running=false
    local function dispatch(self,manual)
        if self.Destroyed or running then return false end
        running=true
        local ok,result=pcall(function()
            local door
            for _,candidate in ipairs(actions:doors()) do
                if manual or not self:isProcessed(candidate) then door=candidate;break end
            end
            if not door then
                if self.Busy and (manual or actions.Ready) then self:finish("Быстрый обход завершён; награда не проверялась",false) end
                return false
            end
            if not actions:fastAvailable() then
                self:setAuto(false);log("Быстрый цикл остановлен: firetouchinterest недоступен")
                return false
            end
            if not self.Context then
                local captured,ctx=pcall(actions.capture,actions)
                if not captured then
                    self.NextScan=clock()+.25
                    if not self.NextBodyLog or clock()>=self.NextBodyLog then
                        log("Ожидание персонажа: "..tostring(ctx));self.NextBodyLog=clock()+3
                    end
                    return false
                end
                self.Context=ctx;self.Busy=true;self.Phase="fast"
            end
            self.Door=door;self.ManualRun=manual==true
            local valid,why=actions:valid(self.Context,door)
            if not valid then self:finish(why,false);self.NextScan=clock()+.25;return false end
            self.FastStats.Attempted=self.FastStats.Attempted+1
            local sent,problem=pcall(function()
                actions:setHold(self.Context,nil)
                actions:approach(self.Context,door)
                actions:fastTouch(self.Context,door)
            end)
            -- Processed means attempted in this generation, not server-confirmed candy.
            self:markProcessed(door)
            if sent then self.FastStats.Dispatched=self.FastStats.Dispatched+1
            else
                self.FastStats.Failed=self.FastStats.Failed+1
                self:finish("Дверь пропущена: "..tostring(problem),false)
            end
            self.Door=nil
            if manual and self.Busy then self:finish("Touch отправлен; награда не проверялась",false) end
            return sent
        end)
        running=false
        if not ok then
            self:finish("Ошибка быстрого обхода: "..tostring(result),false)
            self:setAuto(false);return false
        end
        return result
    end
    function app:attempt(manual) return dispatch(self,manual==true) end
    function app:step()
        if self.Destroyed or not self.Auto or clock()<self.NextScan then return end
        return dispatch(self,false)
    end
    return app
end
return FastCycle
