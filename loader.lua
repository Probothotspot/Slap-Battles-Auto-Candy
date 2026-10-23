-- Draw first, fetch on a separate task, index only after the main GUI mounts.
local URL="https://raw.githubusercontent.com/Probothotspot/Slap-Battles-Auto-Candy/main/auto_candy.lua?v=1.6.3"
local env=type(getgenv)=="function" and getgenv() or _G
local old=env.AutoCandyLoading
if type(old)=="table" and type(old.Destroy)=="function" then old:Destroy() end
local resume=env.AutoCandyResumeSource;env.AutoCandyResumeSource=nil
local previous=env.SlapBattlesAutoCandy
if type(previous)=="table" and type(previous.Destroy)=="function" then previous:Destroy(previous.JobId~=nil and previous.JobId~=game.JobId) end
local player=game:GetService("Players").LocalPlayer
assert(player,"Auto Candy: client required")
local parent=player:WaitForChild("PlayerGui",10);assert(parent,"Auto Candy: PlayerGui unavailable")
local gui=Instance.new("ScreenGui");gui.Name="AutoCandyLoadingGUI";gui.ResetOnSpawn=false
 gui.IgnoreGuiInset=true;gui.DisplayOrder=2000;gui.Parent=parent
local label=Instance.new("TextLabel");label.Size=UDim2.new(1,0,0,30)
label.BackgroundColor3=Color3.fromRGB(28,17,43);label.TextColor3=Color3.fromRGB(240,230,255)
label.Font=Enum.Font.GothamBold;label.TextSize=16;label.Text="loading modules 0/1";label.Parent=gui
local report={State="loading",Started=os.clock(),Connections={}}
env.AutoCandyLoading=report
function report:Destroy()
    if self.Destroyed then return end;self.Destroyed=true
    for _,c in ipairs(self.Connections) do c:Disconnect() end
    gui:Destroy();if env.AutoCandyLoading==self then env.AutoCandyLoading=nil end
end
local function fail(err)
    if report.Destroyed or report.State~="loading" then return end
    report.State="error";report.Error=tostring(err);label.Text="error"
    warn("[AutoCandy loader] "..tostring(err))
end
report.Connections[#report.Connections+1]=game:GetService("RunService").Heartbeat:Connect(function()
    if report.State=="loading" and os.clock()-report.Started>75 then fail("Startup/download timeout") end
end)
report.Connections[#report.Connections+1]=gui.Destroying:Connect(function() report:Destroy() end)
task.spawn(function()
    task.wait() -- allow the loading strip to render before work begins
    local ok,err=pcall(function()
        if report.Destroyed or report.State~="loading" then return end
        report.Phase="waiting_bridge"
        local boot=env.AutoCandyResumeStatus
        local inherited=type(boot)=="table" and boot.Runtime==game and boot.Target==game.JobId and
            boot.Phase=="loading" and boot.BridgeReady==true
        local stableSince=inherited and os.clock()-5 or nil
        local compile
        local probeFile="AutoCandyBridgeProbe-"..tostring(player.UserId)..".txt"
        local marker=tostring(game.JobId)..":"..tostring(report.Started)
        local function api(name)
            local direct={loadstring=loadstring,readfile=readfile,writefile=writefile}
            local fn=direct[name];if type(fn)=="function" then return fn end
            fn=env[name];if type(fn)=="function" then return fn end
        end
        local bridgeReady=false;local last="Runtime not ready"
        while os.clock()-report.Started<45 do
            if report.Destroyed or report.State~="loading" then return end
            local loaded=type(game.IsLoaded)~="function" or game:IsLoaded()
            if loaded and game:GetService("Players").LocalPlayer==player and player:FindFirstChild("PlayerGui")==parent then
                stableSince=stableSince or os.clock()
                if os.clock()-stableSince>=5 then
                    local good,problem=pcall(function()
                        compile=api("loadstring");assert(compile,"loadstring not ready")
                        local probe,why=compile("return true","@AutoCandy/readiness")
                        assert(type(probe)=="function",why or "compiler not ready")
                        assert(probe()==true,"execution bridge not ready")
                        local read,write=api("readfile"),api("writefile")
                        if read or write then
                            assert(read and write,"file bridge incomplete")
                            assert(write(probeFile,marker)~=false,"file bridge refused probe")
                            assert(read(probeFile)==marker,"file bridge not synchronized")
                        else
                            -- A GUI-only backend is allowed, but late API exposure gets a grace period.
                            assert(os.clock()-stableSince>=10,"waiting for optional file APIs")
                        end
                    end)
                    if good then bridgeReady=true;break end
                    last=tostring(problem)
                end
            else stableSince=nil end
            task.wait(.5)
        end
        assert(bridgeReady,"Readiness timeout: "..last)
        report.Phase="downloading"
        local source
        if type(resume)=="table" and resume.Job==game.JobId and type(resume.Source)=="string" and
            resume.Source:sub(1,#"-- Auto Candy v1.6.3 |")=="-- Auto Candy v1.6.3 |" then
            source=resume.Source
        else source=game:HttpGet(URL) end
        if report.Destroyed or report.State~="loading" then return end
        assert(type(source)=="string" and #source>0,"Empty download")
        local chunk,problem=compile(source,"@AutoCandy/auto_candy.lua");assert(chunk,problem)
        if report.Destroyed or report.State~="loading" then return end
        report.Source=source
        local app=chunk()
        assert(type(app)=="table" and app.Gui and app.Gui.Parent,"Main GUI did not appear")
        if report.Destroyed or report.State~="loading" then app:Destroy();return end
        report.App=app;report.State="ready";label.Text="loading modules 1/1";gui.Enabled=false
        report.Connections[#report.Connections+1]=app.Gui.Destroying:Connect(function() report:Destroy() end)
    end)
    if not ok then fail(err) end
end)
return report
