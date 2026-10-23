-- Executor name is a label, never proof that an API works in this installed build.
local Caps={}
function Caps.new(env)
    env=env or {};local self={Name='Unknown',Version='',Disabled={}}
    for _,key in ipairs({'identifyexecutor','getexecutorname'})do
        if type(env[key])=='function'then
            local ok,name,version=pcall(env[key])
            if ok and type(name)=='string' and #name>0 then
                self.Name=name:gsub('%c',' '):sub(1,64)
                self.Version=type(version)=='string' and version:gsub('%c',' '):sub(1,32) or '';break
            end
        end
    end
    for _,key in ipairs({'fireclickdetector','firetouchinterest','fireproximityprompt','setclipboard','writefile','isrbxactive'})do
        if type(env[key])=='function'then self[key]=env[key]end
    end
    function self:allowed(key)return not self.Disabled[key]end
    function self:reject(key,err)
        local message=tostring(err):lower()
        for _,term in ipairs({'security','permission','identity','not supported','unavailable','not implemented','capability','denied'})do
            if message:find(term,1,true)then self.Disabled[key]=tostring(err);return true end
        end
        return false
    end
    return self
end
return Caps
