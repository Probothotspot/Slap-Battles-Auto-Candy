local Grid=dofile('PixelGrid.lua');local n=0
local function eq(a,b)n=n+1;assert(a==b,'pixel #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local calls=0;local quads={}
local g=Grid.new(function(u,v)
 calls=calls+1;return{X=300+u*400,Y=150+v*600,Z=3},true
end,500,function()return 0 end)
eq(calls,0)
while not g.Ready do local before=calls;g:step();eq(calls-before<=128,true)end
eq(#g.Points,500)
local unique={}
for _,p in ipairs(g.Points)do
 local key=p.X..':'..p.Y;eq(unique[key],nil);unique[key]=true
 local quadrant=(p.X>=500 and 1 or 0)+(p.Y>=450 and 2 or 0);quads[quadrant]=(quads[quadrant]or 0)+1
end
for i=0,3 do eq(quads[i]>100,true)end
-- Clipped / tiny faces terminate honestly rather than duplicating pixels to 500.
g=Grid.new(function()return{X=500,Y=400,Z=3},true end,500,function()return 0 end)
local frames=0;while not g.Ready do g:step();frames=frames+1;assert(frames<=250)end
eq(#g.Points,1);eq(g.Candidates,32000)
g=Grid.new(function()return{X=500,Y=400,Z=-1},true end,500,function()return 0 end)
while not g.Ready do g:step()end;eq(#g.Points,0)
g=Grid.new(function()return{X=20,Y=65,Z=1},true end,1,function()return 0 end)
while not g.Ready do g:step()end;eq(#g.Points,0)
print('PASS: '..n..' unique pixels, spread, frame budget, clipping and bounded completion assertions')
