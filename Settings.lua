-- Data-only, account-scoped settings. No downloaded code or executable configuration.
local Settings={}
local defaults={DoorDelay=1,StopKey='T',Auto=false,ServerHop=false,Scale=1,Collapsed=false}
local function copy(t)local out={};for k,v in pairs(t)do out[k]=v end;return out end
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function clean(k,v)
    if k=='DoorDelay' then return finite(v) and v>=0 and v<=60 and v or nil end
    if k=='Scale' then return finite(v) and v>=.65 and v<=1.6 and v or nil end
    if k=='StopKey' then return type(v)=='string' and #v>0 and #v<=64 and v or nil end
    if k=='Auto' or k=='ServerHop' or k=='Collapsed' then if type(v)=='boolean' then return v end end
end
function Settings.new(c)
    local self={Values=copy(defaults),Loaded=false,Dirty=false,Revision=0,Available=type(c.Read)=='function' and type(c.Write)=='function'}
    self.File='AutoCandySettings-v1-'..tostring(c.UserId)..'.json'
    local function report(s)if c.Log then c.Log(s)end end
    local exists=true
    if type(c.IsFile)=='function' then local ok,v=pcall(c.IsFile,self.File);exists=not ok or v==true end
    if type(c.Read)=='function' and exists then
        local ok,data=pcall(function()
            local raw=c.Read(self.File)
            assert(type(raw)=='string' and #raw<=65536,'Некорректный размер файла настроек')
            return c.Decode(raw)
        end)
        if ok and type(data)=='table' and data.Schema==1 and data.UserId==c.UserId and type(data.Values)=='table' then
            for k in pairs(defaults)do local v=clean(k,data.Values[k]);if v~=nil then self.Values[k]=v end end
            if self.Values.ServerHop then self.Values.Auto=true end
            self.Loaded=true
        elseif ok then report('Файл настроек не подходит — загружены значения по умолчанию')
        elseif type(c.IsFile)=='function' then report('Не удалось прочитать настройки — используются значения по умолчанию') end
    end
    function self:save()
        self.Dirty=true
        if c.Active and not c.Active() then return false end
        if self.Saving then return false end
        if not self.Available then
            if not self.Warned then self.Warned=true;report('Сохранение недоступно: нужны readfile и writefile. Настройки действуют до перезапуска') end
            return false
        end
        self.Saving=true
        local revision=self.Revision
        local snapshot=copy(self.Values)
        local ok,why=pcall(function()
            local raw=c.Encode({Schema=1,UserId=c.UserId,Values=snapshot})
            assert(not c.Active or c.Active(),'Устаревшая сессия настроек')
            local result=c.Write(self.File,raw)
            assert(result~=false,'writefile вернула false')
            assert(c.Read(self.File)==raw,'Проверка записи настроек не прошла')
        end)
        self.Saving=false
        if ok and self.Revision==revision then self.Dirty=false end
        if not ok then
            if not self.WriteError then report('Не удалось сохранить настройки: '..tostring(why)) end
            self.WriteError=true
        else self.WriteError=false end
        return ok
    end
    function self:set(patch)
        local changed=false
        local nextValues=copy(self.Values)
        for k,v in pairs(patch)do if defaults[k]~=nil then
            local value=clean(k,v)
            if value~=nil then nextValues[k]=value end
        end end
        if patch.Auto==false then nextValues.ServerHop=false
        elseif nextValues.ServerHop then nextValues.Auto=true end
        for k,v in pairs(nextValues)do if self.Values[k]~=v then changed=true end end
        self.Values=nextValues
        if changed then self.Revision=self.Revision+1 end
        if changed or self.Dirty then return self:save() end
        return true
    end
    function self:service(now)
        if not self.Dirty or self.Saving or now<(self.NextRetry or 0) then return end
        self.NextRetry=now+3
        return self:save()
    end
    function self:reset()self.Values=copy(defaults);self.Revision=self.Revision+1;return self:save()end
    if not self.Available then self:save() end
    return self
end
return Settings
