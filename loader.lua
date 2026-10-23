-- Draw first, fetch on a separate task, index only after the main GUI mounts.
local URL="https://raw.githubusercontent.com/Probothotspot/Slap-Battles-Auto-Candy/main/auto_candy.lua?v=1.5.0"
local env=type(getgenv)=="function" and getgenv() or _G
local old=env.AutoCandyLoading
if type(old)=="table" and type(old.Destroy)=="function" then old:Destroy() end
local previous=env.SlapBattlesAutoCandy
if type(previous)=="table" and type(previous.Destroy)=="function" then previous:Destroy() end
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
    if report.State=="loading" and os.clock()-report.Started>25 then fail("Download timeout") end
end)
report.Connections[#report.Connections+1]=gui.Destroying:Connect(function() report:Destroy() end)
task.spawn(function()
    task.wait() -- allow the loading strip to render before work begins
    local ok,err=pcall(function()
        if report.Destroyed or report.State~="loading" then return end
        assert(type(loadstring)=="function","loadstring unavailable")
        local source=game:HttpGet(URL)
        if report.Destroyed or report.State~="loading" then return end
        assert(type(source)=="string" and #source>0,"Empty download")
        local chunk,problem=loadstring(source,"@AutoCandy/auto_candy.lua");assert(chunk,problem)
        if report.Destroyed or report.State~="loading" then return end
        local app=chunk()
        assert(type(app)=="table" and app.Gui and app.Gui.Parent,"Main GUI did not appear")
        if report.Destroyed or report.State~="loading" then app:Destroy();return end
        report.App=app;report.State="ready";label.Text="loading modules 1/1";gui.Enabled=false
        report.Connections[#report.Connections+1]=app.Gui.Destroying:Connect(function() report:Destroy() end)
    end)
    if not ok then fail(err) end
end)
return report
