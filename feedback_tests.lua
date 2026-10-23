local Feedback=dofile('Feedback.lua')
local n=0
local function eq(a,b)n=n+1;assert(a==b,'feedback #'..n..': '..tostring(a)..' ~= '..tostring(b))end
local signals={}
local function signal()
 local s={};signals[#signals+1]=s
 function s:Connect(fn)local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end;self[#self+1]=c;return c end
 function s:Fire()for _,c in ipairs(self)do if c.Connected then c.fn()end end end
 return s
end
local calls=0
local function node(name,parent,class)
 local o={Name=name,Parent=parent,Class=class or 'Folder',Children={},Props={},DescendantAdded=signal(),Played=signal(),Volume=1,SoundId='fixture'}
 function o:IsA(c)return self.Class==c end
 function o:IsDescendantOf(p)local q=self.Parent;while q do if q==p then return true end;q=q.Parent end;return false end
 function o:GetChildren()calls=calls+1;return self.Children end
 function o:GetPropertyChangedSignal(k)self.Props[k]=self.Props[k]or signal();return self.Props[k]end
 if parent then parent.Children[#parent.Children+1]=o end
 return o
end
local root=node('Door');local sound=node('Knock',root,'Sound');local music=node('Knock music',root,'Sound');music.Looped=true
local already=node('OldSound',root,'Sound');already.IsPlaying=true
local other=node('OtherDoor');local unrelated=node('Knock',other,'Sound')
for i=1,2000 do node('Unrelated'..i,other)end
local time=0;local f=Feedback.new(root,function()return time end)
eq(calls,0);f:step();eq(f.Ready,true);eq(f.Count,3)
sound.Played:Fire();eq(f.Result,nil) -- Before click must be ignored.
f:arm();f:step();eq(f.Result,nil);eq(f.Candidate,nil) -- Existing playback ignored.
music.Played:Fire();unrelated.Played:Fire();eq(f.Result,nil)
sound.Played:Fire();eq(f.Result.Name,'Knock');eq(f.Result.Knock,true)
f:arm();time=2.3;sound.Played:Fire();eq(f.Result,nil) -- Late event ignored.
f:arm();already.IsPlaying=false;f:step();already.IsPlaying=true;f:step()
eq(f.Result,nil);eq(f.Candidate.Name,'OldSound') -- Unknown audio is not proven knock.
f:arm();sound.Volume=0;sound.Played:Fire();eq(f.Result,nil);sound.Volume=1
-- A newly cloned already-playing sound is observed without rescanning Workspace.
local clone=node('Knock clone',root,'Sound');clone.IsPlaying=true
for _,c in ipairs(root.DescendantAdded)do if c.Connected then c.fn(clone)end end
eq(f.Result.Name,'Knock clone')
f:arm();sound.IsPlaying=true;sound:GetPropertyChangedSignal('IsPlaying'):Fire();eq(f.Result.Name,'Knock')
f:Destroy();f:Destroy();sound.Played:Fire();eq(f.Destroyed,true)
local active=0;for _,s in ipairs(signals)do for _,c in ipairs(s)do if c.Connected then active=active+1 end end end;eq(active,0)
-- Bounded local indexing and sound subscriptions even for a malformed large Door.
root=node('Door');for i=1,1000 do node('Knock'..i,root,'Sound')end
f=Feedback.new(root,function()return time end)
local frames=0
while not f.Ready do
 local before=calls;f:step();eq(calls-before<=64,true);frames=frames+1;assert(frames<100)
end
eq(f.Scanned,512);eq(f.Count,64);eq(calls<600,true);f:Destroy()
print('PASS: '..n..' playback correlation, ignored audio, cloned sounds, cleanup and budget assertions')
