local Settings=dofile('Settings.lua');local n=0
local function eq(a,b)n=n+1;assert(a==b,'settings #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(t)if type(t)~='table'then return t end;local c={};for k,v in pairs(t)do c[k]=copy(v)end;return c end
local files,objects,logs={},{},{};local writes=0
local c={UserId=123,Log=function(s)logs[#logs+1]=s end,IsFile=function(f)return files[f]~=nil end,
 Read=function(f)return assert(files[f],'missing')end,Write=function(f,s)files[f]=s;writes=writes+1 end,
 Encode=function(v)local id='json:'..tostring(#objects+1);objects[#objects+1]=copy(v);return id end,
 Decode=function(s)local id=tonumber(s:match('^json:(%d+)$'));assert(id and objects[id],'bad json');return copy(objects[id])end}
local a=Settings.new(c);eq(a.Loaded,false);eq(a.Values.DoorDelay,1);eq(a.Values.StopKey,'T');eq(a.Values.Auto,false);eq(a.Values.ServerHop,false)
eq(a.Values.Scale,1);eq(a.Values.Collapsed,false);eq(writes,0)
eq(a:set({DoorDelay=2.5,StopKey='F8',Auto=true,Scale=1.2,Collapsed=true}),true);eq(writes,1)
local b=Settings.new(c);eq(b.Loaded,true);eq(b.Values.DoorDelay,2.5);eq(b.Values.StopKey,'F8');eq(b.Values.Auto,true)
eq(b.Values.Scale,1.2);eq(b.Values.Collapsed,true)
b:set({ServerHop=true});eq(b.Values.Auto,true);eq(b.Values.ServerHop,true)
b:set({Auto=false});eq(b.Values.ServerHop,false);eq(b.Values.Auto,false)
local before=writes;b:set({Auto=false});eq(writes,before)
for _,bad in ipairs({-1,61,0/0,math.huge,-math.huge,'2'})do b:set({DoorDelay=bad});eq(b.Values.DoorDelay,2.5)end
eq(writes,before)
b:set({Scale=0,StopKey='',Auto='true',Collapsed=1,Evil='ignored'});eq(b.Values.Scale,1.2);eq(b.Values.StopKey,'F8');eq(b.Values.Auto,false);eq(b.Values.Collapsed,true);eq(b.Values.Evil,nil)
b:set({DoorDelay=0});eq(b.Values.DoorDelay,0);b:set({DoorDelay=60});eq(b.Values.DoorDelay,60)
b:reset();local r=Settings.new(c);eq(r.Values.DoorDelay,1);eq(r.Values.StopKey,'T');eq(r.Values.Auto,false);eq(r.Values.Scale,1);eq(r.Values.Collapsed,false)
local name=a.File
files[name]=c.Encode({Schema=1,UserId=999,Values={DoorDelay=3}});eq(Settings.new(c).Loaded,false)
files[name]=c.Encode({Schema=99,UserId=123,Values={DoorDelay=3}});eq(Settings.new(c).Loaded,false)
files[name]='broken json';eq(Settings.new(c).Values.DoorDelay,1)
files[name]=string.rep('x',65537);eq(Settings.new(c).Loaded,false)
files[name]=c.Encode({Schema=1,UserId=123,Values={DoorDelay=-20,StopKey=42,Auto='false',Scale=100,Collapsed=false}})
r=Settings.new(c);eq(r.Loaded,true);eq(r.Values.DoorDelay,1);eq(r.Values.StopKey,'T');eq(r.Values.Scale,1)
local oldWrite=c.Write;c.Write=function()error('denied')end
r=Settings.new(c);eq(r:set({DoorDelay=4}),false);eq(r.Values.DoorDelay,4)
local errors=#logs;eq(r:set({DoorDelay=5}),false);eq(#logs,errors)
c.Write=oldWrite;eq(r:save(),true);eq(Settings.new(c).Values.DoorDelay,5)
c.Read=nil;c.Write=nil;r=Settings.new(c);eq(r.Available,false);eq(r:set({DoorDelay=7}),false);eq(r.Values.DoorDelay,7)
errors=#logs;r:set({DoorDelay=8});eq(#logs,errors)
print('PASS: '..n..' validated settings, account isolation, persistence, reset and unavailable-storage assertions')
