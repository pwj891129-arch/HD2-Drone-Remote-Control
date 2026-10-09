local Pose, B, Lease = ...
local ffi = require('ffi')
local checks = 0
local function check(value, why) assert(value,why); checks = checks+1 end
local function fixture(body)
    local memory = {[100]='\1',[101]='\1',[200]='\1',[201]='\0'}
    local channel = {writes = 0,stale = false,actor_writes = 0}
    function channel:floats(values)
        local out = ffi.new('float[?]',#values)
        for i,v in ipairs(values) do out[i-1] = v end
        return ffi.string(out,#values*4)
    end
    function channel:float(raw, at)
        local out = ffi.new('float[1]'); ffi.copy(out,raw:sub(at+1,at+4),4)
        return tonumber(out[0])
    end
    function channel:read(at,size) return memory[at] end
    function channel:write(at,raw)
        self.writes = self.writes+1
        if at == 100 or at == 101 then self.actor_writes = self.actor_writes+1 end
        if at == self.fail then return false end
        memory[at] = raw; return true
    end
    local original = channel:floats({0,0,0,1})
    memory[300] = original
    local valid = function() return not channel.stale end
    local controls = {key='owned-drone',rotation=300,valid=valid,
        body=body and {enabled=200,override=201,valid=valid}}
    -- Decoy fields must never be claimed or validated by the pose module.
    controls.actor = {enabled=100,override=101,valid=function() error('actor_read') end}
    return Pose.new(channel,B,Lease),channel,memory,controls,original
end
local yaw = {0,0,math.sin(0.4),math.cos(0.4)}
local p,ch,m,controls,original = fixture(true)
p:prepare(controls)
check(ch.writes==0 and m[100]=='\1' and m[101]=='\1','preparation does not write actor or body')
check(m[300]==original and m[200]=='\1','preparation leaves body pose alone')
p:tick(yaw,false)
check(m[200]=='\0' and m[201]=='\0','manual control pauses body Rotator if present')
check(m[300]==ch:floats(yaw),'canonical body pose follows camera without a fire edge')
local root_scene = m[300]
-- A later native pose consumer must see the new quaternion, not the entry pose.
root_scene = m[300]
check(root_scene==ch:floats(yaw) and root_scene~=original,'native cached-pose replay no longer resets yaw')
m[100],m[101]='\0','\0'
p:tick(yaw,false)
check(m[100]=='\0' and m[101]=='\0' and ch.actor_writes==0,'actor changes never recaptured')
m[200]='\1'; m[300]=original
p:tick(yaw,false)
check(m[200]=='\0' and m[300]==ch:floats(yaw),'known entry pose/turn reset recaptured')
local negated={}; for i=1,4 do negated[i]=-yaw[i] end
m[300]=ch:floats(negated)
p:tick(yaw,false)
check(m[300]==ch:floats(yaw),'equivalent quaternion sign accepted')
local rounded={yaw[1],yaw[2],yaw[3]+1e-7,yaw[4]}
m[300]=ch:floats(rounded)
p:tick(yaw,false)
check(m[300]==ch:floats(yaw),'engine normalization roundoff accepted')
p:tick(yaw,true)
check(m[300]==original and m[200]=='\1','automatic aim releases canonical pose/body turn')
check(m[100]=='\0' and ch.actor_writes==0,'automatic mode leaves actor untouched')
p:tick(yaw,false)
check(m[300]==ch:floats(yaw),'manual aim can recapture after automatic mode')
p:clear()
check(m[100]=='\0' and m[101]=='\0' and m[200]=='\1' and m[201]=='\0' and
    ch.actor_writes==0,'only body turn flags restored')
check(m[300]==original and not p.controls,'pose and state restored on exit')
p:clear(); check(not p.body_lease,'cleanup is idempotent')

p,ch,m,controls,original=fixture(false)
p:prepare(controls); p:tick(yaw,false)
check(m[300]==ch:floats(yaw) and m[200]=='\1','absent body Rotator keeps verified spatial path')
p:clear(); check(m[300]==original and ch.actor_writes==0,'fallback releases normally without actor writes')

p,ch,m,controls=fixture(true)
p:prepare(controls)
for _, bad in ipairs({{0,0,0,0},{0,0,0,2},{0,0,0,0/0}}) do
    local before=ch.writes
    check(not pcall(p.tick,p,bad,false) and ch.writes==before,'malformed quaternion never written')
end
p:tick(yaw,false)
m[300]=ch:floats({0,0,math.sin(1),math.cos(1)})
local foreign=m[300]; local before=ch.writes
check(not pcall(p.tick,p,yaw,false) and ch.writes==before,'foreign rotation refused')
p:clear(); check(m[300]==foreign,'foreign rotation not restored')
check(m[100]=='\1' and m[200]=='\1' and ch.actor_writes==0,'independent body flags released without actor writes')

p,ch,m,controls=fixture(true)
p:prepare(controls);p:tick(yaw,false);ch.stale=true
before=ch.writes
check(not pcall(p.tick,p,yaw,false) and ch.writes==before,'replaced identity receives no writes')
p:clear();check(ch.writes==before,'replaced identity never restored')

p,ch,m,controls=fixture(true)
p:prepare(controls);p:tick(yaw,false)
ch.fail=200
check(not pcall(p.clear,p) and p.body_lease~=nil,'failed body restore retained for retry')
ch.fail=nil;p:clear()
check(m[200]=='\1' and not p.body_lease and ch.actor_writes==0,'body restore retry completes')

p,ch,m,controls=fixture(true)
p:prepare(controls);ch.fail=200
check(not pcall(p.tick,p,yaw,false),'partial body capture failure reported')
ch.fail=nil;p:clear()
check(m[201]=='\0' and m[200]=='\1' and ch.actor_writes==0,'partial capture rolled back')

local function relocate(foreign_pose,foreign_flag,new_owner)
    local p,ch,m,controls,original=fixture(true)
    p:prepare(controls);p:tick(yaw,false)
    m[400],m[401],m[500]=m[200],m[201],m[300]
    local valid=function() return true end
    local refreshed={key=new_owner and 'other-drone' or controls.key,rotation=500,valid=valid,
        body={enabled=400,override=401,valid=valid}}
    controls.resolve=function() return refreshed end
    ch.stale=true
    if foreign_pose then m[500]=ch:floats({0,0,math.sin(1),math.cos(1)}) end
    if foreign_flag then m[400]='\2' end
    return p,ch,m,controls,original
end
p,ch,m,controls,original=relocate()
before=ch.writes
p:tick(yaw,false)
check(m[500]==ch:floats(yaw) and ch.writes==before,'unchanged copied pose needs no redundant write after storage move')
local changed_yaw = {0,0,math.sin(0.8),math.cos(0.8)}
p:tick(changed_yaw,false)
check(m[500]==ch:floats(changed_yaw) and ch.writes>before,'copied pose remains controllable after storage move')
p:clear()
check(m[400]=='\1' and m[500]==original and m[200]=='\0','only refreshed buffers restored')
check(ch.actor_writes==0,'storage refresh never touches actor')

p,ch,m,controls,original=relocate()
p:clear()
check(m[400]=='\1' and m[500]==original,'cleanup alone resolves copied paused values')

p,ch,m,controls=relocate(true)
foreign=m[500];p:clear()
check(m[500]==foreign and m[400]=='\1','foreign pose does not prevent independent flag cleanup')

p,ch,m,controls=relocate(false,true)
before=ch.writes;p:clear()
check(m[400]=='\2' and m[200]=='\0' and m[500]==ch:floats(yaw),
    'foreign relocated flag and stale storage never overwritten')

p,ch,m,controls=relocate(false,false,true)
before=ch.writes;p:clear()
check(ch.writes==before and m[400]=='\0','different drone cannot inherit restoration writes')
return checks
