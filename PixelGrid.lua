-- Incremental, deterministic coverage of a projected door face; one sample per pixel.
local Grid={}
local function halton(i,base)
    local value,weight=0,1
    while i>0 do weight=weight/base;value=value+(i%base)*weight;i=math.floor(i/base) end
    return value
end
function Grid.new(project,count,clock)
    assert(type(count)=='number' and count>=1 and count<=500)
    local self={Points={},Seen={},Candidates=0,Ready=false,Target=count}
    clock=clock or os.clock
    function self:step()
        if self.Ready then return end
        local start=clock();local work=0
        while #self.Points<self.Target and self.Candidates<32000 and work<128 and clock()-start<.001 do
            self.Candidates=self.Candidates+1;work=work+1
            local p,visible=project(.01+.98*halton(self.Candidates,2),.01+.98*halton(self.Candidates,3))
            if p and visible and p.Z>0 then
                local x,y=math.floor(p.X+.5),math.floor(p.Y+.5)
                local key=x..':'..y
                -- The test HUD occupies this small rectangle. Never click its Stop button.
                if x>=0 and y>=0 and not (x<260 and y>=48 and y<112) and not self.Seen[key] then
                    self.Seen[key]=true;self.Points[#self.Points+1]={X=x,Y=y}
                end
            end
        end
        self.Ready=#self.Points>=self.Target or self.Candidates>=32000
    end
    return self
end
return Grid
