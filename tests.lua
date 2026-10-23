local Core=dofile('Core.lua')
local n=0
local function eq(a,b) n=n+1;assert(a==b,'assertion '..n..': '..tostring(a)..' ~= '..tostring(b)) end
local world={};local folder={Name='Door',Parent=world}
local part={Name='DoorInnerTouch',Parent=folder,IsA=function(_,c)return c=='BasePart'end}
eq(Core.isDoor(part,world),true)
part.Name='Other';eq(Core.isDoor(part,world),false);part.Name='DoorInnerTouch'
folder.Name='Other';eq(Core.isDoor(part,world),false);folder.Name='Door'
-- Matching has no access to position, colour or material fields.
local t=0;local logs={};local events={};local doors={part};local origin='original root/camera'
local actions={}
function actions:doors() return doors end
function actions:distance(p) return p.distance or 10 end
function actions:capture() events[#events+1]='capture';return {Origin=origin} end
function actions:approach(ctx,p) events[#events+1]='teleport';if self.failMove then error('move failure')end end
function actions:valid()return not self.invalid,'removed'end
function actions:aim()events[#events+1]='aim'end
function actions:beginFeedback()self.heard=nil;self.candidate=nil;return self.methods or 2 end
function actions:feedback()return self.heard,self.candidate,true end
function actions:confirmed()events[#events+1]='confirmed'end
function actions:prepareClick(_,_,index)events[#events+1]='prepare'..index;return 'method'..index end
function actions:mouseDown()events[#events+1]='down';if self.failClick then error('input denied')end end
function actions:mouseUp()events[#events+1]='up'end
function actions:restore(ctx) events[#events+1]='restore';eq(ctx.Origin,origin);if self.failReturn then error('dead character')end end
local app=Core.new(actions,function()return t end,function(s)logs[#logs+1]=s end)
local function complete()
 t=t+.36;app:step();t=t+.16;app:step();t=t+.21;app:step();t=t+.16;app:step();t=t+.13;app:step()
 actions.heard={Name='Knock',Id='fixture'};app:step();t=t+.31;app:step();actions.heard=nil
end
eq(app:attempt(true),true);eq(app.Busy,true);eq(app:attempt(true),false)
complete();eq(app.Busy,false);eq(table.concat(events,','),'capture,teleport,aim,up,prepare1,down,up,up,confirmed,restore')
eq(app.Confirmed[part],true)
-- Passive mode honours cooldown, manual mode can retry immediately.
events={};app:setAuto(true);app:step();eq(app.Busy,false)
eq(app:attempt(true),true);complete();eq(app.Busy,false)
app:setAuto(false)
-- Missing objects produce a user-visible log and no movement.
doors={};events={};eq(app:attempt(true),false);eq(#events,0)
eq(logs[#logs]:find('Нет существующих',1,true)~=nil,true)
doors={part};app.Cooldown[part]=nil;app.Visited[part]=nil
-- Cancellation after a mouse press restores input and origin through restore.
app:setAuto(true);app:step();eq(app.Busy,true)
t=t+.36;app:step();t=t+.16;app:step();t=t+.21;app:step();t=t+.16;app:step();eq(app.Phase,'pressed')
app:setAuto(false);eq(app.Busy,false);eq(events[#events],'restore')
-- Errors before/after teleport still restore the captured context.
actions.failMove=true;eq(app:attempt(true),false);eq(app.Busy,false);eq(events[#events],'restore');actions.failMove=false
actions.failClick=true;app:attempt(true);t=t+.36;app:step();t=t+.16;app:step();t=t+.21;app:step();t=t+.16;app:step()
eq(app.Busy,true);eq(app.ClickIndex,2)
t=t+.21;app:step();t=t+.16;app:step();t=t+.16;app:step()
eq(app.Busy,false);eq(events[#events],'restore');actions.failClick=false
app:attempt(true);actions.invalid=true;app:step();eq(app.Busy,false);actions.invalid=false
-- A failed return is logged, never reported as successful.
actions.failReturn=true;app:attempt(true);app:finish();eq(app.Busy,false)
eq(logs[#logs]:find('Возврат не выполнен',1,true)~=nil,true);actions.failReturn=false
-- No acknowledgement must not mark success after mouse-up; bounded retries finish.
app.Confirmed={};app.Visited={};events={};app:attempt(true)
for i=1,100 do t=t+.1;app:step();if not app.Busy then break end end
eq(app.Busy,false);eq(app.Visited[part],nil);eq(app.RetryDoor,part);eq(app.Confirmed[part],nil)
local downs=0;for _,e in ipairs(events)do if e=='down'then downs=downs+1 end end;eq(downs,2)
-- An unknown local effect is tentative and suppresses duplicate clicks.
app:attempt(true)
for i=1,20 do t=t+.1;app:step();if app.Phase=='listen'then break end end
actions.candidate={Name='Sound',Id='unknown'}
t=t+1.9;app:step();eq(app.Phase,'return');eq(app.Confirmed[part],nil)
t=t+.31;app:step();eq(app.Busy,false);eq(app.RetryDoor,part);actions.candidate=nil
-- Start a new run before testing nearest eligible object selection.
app:setAuto(false)
local second={distance=2};part.distance=20;doors={part,second};app.Cooldown={};app.Visited={}
app:setAuto(true);app:step();eq(app.Door,second);complete();app:step();t=t+2.1;app:step();eq(app.Door,part)
app:setAuto(false);app:Destroy();app:Destroy();eq(app.Destroyed,true);eq(app:attempt(true),false)
print('PASS: '..n..' matching, transaction, cancellation, cooldown and failure assertions')
