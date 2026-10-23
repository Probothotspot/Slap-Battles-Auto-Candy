-- Observe playback inside the selected Door only; never record microphone audio.
local Feedback={}
function Feedback.isKnownKnockId(value)
    local id=tostring(value or ''):match('^rbxassetid://(%d+)$')
        or tostring(value or ''):match('[?&]id=(%d+)') or tostring(value or ''):match('^(%d+)$')
    -- Confirmed by the user's successful Xeno door interaction and playback report.
    return id=='4093874915'
end
function Feedback.new(scope,clock)
    clock=clock or os.clock
    local self={Stack={{Node=scope}},Sounds={},Connections={},Pending={},Count=0,Scanned=0,Ready=false}
    local function connect(signal,fn)
        self.Connections[#self.Connections+1]=signal:Connect(fn)
    end
    local function heard(sound)
        if self.Destroyed or not self.Armed or self.Result or clock()>self.Until then return end
        if not sound:IsDescendantOf(scope) or sound.Looped or sound.Volume==0 then return end
        -- Named knock is stronger evidence; an unnamed local effect stays tentative.
        local name=sound.Name:lower()
        local knock=name:find('knock',1,true) or name:find('стук',1,true)
        local evidence={Name=sound.Name,Id=tostring(sound.SoundId),Knock=knock~=nil or Feedback.isKnownKnockId(sound.SoundId)}
        if evidence.Knock then self.Result=evidence else self.Candidate=evidence end
    end
    local function watch(o,isNew)
        if self.Sounds[o] or not o:IsA('Sound') or not o:IsDescendantOf(scope) or self.Count>=64 then return end
        self.Count=self.Count+1;self.Sounds[o]={Playing=o.IsPlaying==true}
        connect(o.Played,function() heard(o) end)
        connect(o:GetPropertyChangedSignal('IsPlaying'),function()
            if o.IsPlaying then heard(o) end
        end)
        -- A newly replicated Sound can already be playing when it arrives.
        if isNew and o.IsPlaying then heard(o) end
    end
    connect(scope.DescendantAdded,function(o)
        if not self.Destroyed and o:IsA('Sound') then watch(o,true) end
    end)
    function self:step()
        if self.Destroyed then return end
        local start=clock();local work=0
        while #self.Stack>0 and work<64 and clock()-start<.001 do
            work=work+1
            local f=self.Stack[#self.Stack]
            if not f.Children then f.Children=f.Node:GetChildren();f.Index=1
            elseif f.Index>#f.Children then table.remove(self.Stack)
            else
                local o=f.Children[f.Index];f.Index=f.Index+1;self.Scanned=self.Scanned+1
                watch(o,false)
                if self.Scanned<512 then self.Stack[#self.Stack+1]={Node=o}
                else self.Stack={};break end
            end
        end
        self.Ready=#self.Stack==0
        for sound,state in pairs(self.Sounds) do
            if not sound:IsDescendantOf(scope) then self.Sounds[sound]=nil
            else
                local playing=sound.IsPlaying==true
                if playing and not state.Playing then heard(sound) end
                state.Playing=playing
            end
        end
    end
    function self:arm()
        self.Armed=true;self.Until=clock()+2.2;self.Result=nil;self.Candidate=nil
        -- Existing playback is not a response to this click.
        for sound,state in pairs(self.Sounds) do state.Playing=sound.IsPlaying==true end
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true;self.Armed=false
        for _,c in ipairs(self.Connections) do c:Disconnect() end
        self.Connections={};self.Sounds={};self.Stack={}
    end
    return self
end
return Feedback
