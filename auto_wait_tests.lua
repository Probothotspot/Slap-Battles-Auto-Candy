local Core=dofile('Core.lua');local n=0
local function eq(a,b)n=n+1;assert(a==b,'auto wait #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local time=0;local logs={};local calls=0;local returns=0
local actions={Ready=true,Found={},Generations={}}
function actions:doors()return self.Found end
function actions:generation(p)return self.Generations[p]or 0 end
function actions:distance(p)return p.Distance end
function actions:capture()calls=calls+1;return{}end
function actions:approach()end
function actions:valid()return true end
function actions:aim()end
function actions:beginFeedback()return 1 end
function actions:prepareClick()return 'fixture touch'end
function actions:mouseDown(ctx)ctx.Sent=true end
function actions:mouseUp()end
function actions:confirmed()end
function actions:feedback(ctx)if ctx.Sent then return{Name='Knock',Id='fixture'},nil,true end;return nil,nil,true end
function actions:restore()returns=returns+1 end
local app=Core.new(actions,function()return time end,function(s)logs[#logs+1]=s end)
local function tick(dt)time=time+dt;app:step()end
local function complete()
 for _=1,50 do if not app.Busy then return end;tick(.2)end;error('operation timeout')
end
app:setAuto(true);app:step();eq(app.Waiting,true);eq(app.Auto,true);eq(app.Busy,false)
tick(3600);eq(app.Auto,true);eq(calls,0)
local a={Distance=3};actions.Generations[a]=1;actions.Found={a}
tick(2.1);eq(app.Busy,true);eq(app.Door,a);complete();eq(app:isProcessed(a),true)
tick(2.1);eq(app.Waiting,true);eq(app.Auto,true)
for _=1,10 do tick(300)end;eq(calls,1);eq(app.Auto,true) -- No once-only shutdown or repeat of old doors.
local b={Distance=1};actions.Generations[b]=1;actions.Found={a,b}
tick(2.1);eq(app.Door,b);complete();eq(app:isProcessed(b),true);eq(calls,2);eq(returns,2)
app.HopMode=true;app.HopMode=false;tick(2.1);eq(app.Waiting,true);eq(app.Auto,true)
-- The same instance may be removed/reinserted; a new generation ignores old visit/cooldown.
actions.Generations[b]=2;tick(2.1);eq(app.Busy,true);eq(app.Door,b);complete()
eq(app:isProcessed(b),true);eq(calls,3)
actions.Generations[b]=3;tick(2.1);eq(app.Busy,true)
actions.Generations[b]=4;tick(.1);eq(app.Busy,false);eq(app:isProcessed(b),false)
app:setAuto(false);local before=calls;tick(50);eq(calls,before);eq(app.Waiting,false)
eq(app:attempt(true),true);complete();eq(app:isProcessed(b),true)
app:Destroy()
print('PASS: '..n..' persistent auto waiting, later doors, hop-off, regeneration and cancellation assertions')
