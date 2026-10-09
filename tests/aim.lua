local Aim,B,Lease = ...
local checks = 0
local function check(value,message) assert(value,message);checks=checks+1 end
local ffi = require('ffi')
local function fixture()
    local memory = {[100]=B.u32(0),[200]=string.rep('\0',12),
        [300]=string.rep('\0',12),[400]='\0',[500]=string.rep('\0',12)}
    local channel = {writes=0}
    function channel:read(at) return memory[at] end
    function channel:write(at,value)
        self.writes=self.writes+1
        if at == self.failed then return false end
        memory[at]=value;return true
    end
    function channel:floats(values)
        local raw=ffi.new('float[3]')
        for i=1,3 do raw[i-1]=values[i] end
        return ffi.string(raw,12)
    end
    local targeting={flags=100,position=200}
    function targeting.valid() return not targeting.invalid end
    local motor={position=300,engaged=400,fire_position=500}
    function motor.valid() return not motor.invalid end
    return Aim.new(channel,B,Lease),channel,memory,
        {targeting=targeting,aim_motor=motor,weapon_position={0,0,0},weapon_forward={0,1,0}}
end
local function tick(aim,snapshot,camera,forward,automatic,dt)
    return aim:tick(snapshot,camera,forward,automatic,dt or 0.02)
end
local function aligned(memory)
    check(memory[200]==memory[300] and memory[200]==memory[500] and memory[400]=='\1',
        'acquisition, model pitch/yaw and firing receive one point without an attack')
end
local aim,channel,memory,snapshot=fixture()
tick(aim,snapshot,{0,0,0},{0,1,0},true)
check(channel.writes==0 and not aim.lease,'automatic mode leaves native targeting untouched')
local result=tick(aim,snapshot,{0,0,0},{0,1,0},false)
check(memory[100]==B.u32(2),'manual mode skips enemy acquisition and uses explicit point')
check(memory[200]==channel:floats({0,100,0}),'settled forward world point')
check(#aim.lease.items==3,'mode, explicit target and motor activation are leased')
aligned(memory)
check(result.body_rotation[1]==0 and result.body_rotation[2]==0,'lower gun pitch is not applied to body root')
result=tick(aim,snapshot,{0,0,0},{1,0,0},false)
check(result.direction[1]>0 and result.direction[1]<0.1 and result.direction[2]>0.99,
    'camera snaps but physical aiming advances only 180 degrees per second')
aligned(memory)
for _=1,25 do result=tick(aim,snapshot,{0,0,0},{1,0,0},false) end
check(memory[200]==channel:floats({100,0,0}),'settled motor/fire point converges to camera target')
for _=1,30 do result=tick(aim,snapshot,{0,0,0},{0,0,1},false) end
check(memory[200]==channel:floats({0,0,100}),'lower gun motor receives full vertical target')
check(result.body_rotation[1]==0 and result.body_rotation[2]==0,'vertical aiming does not pitch the aircraft')
aligned(memory)
local before_motor=memory[300]
tick(aim,snapshot,{}, {},true)
check(memory[100]==B.u32(0) and memory[200]==string.rep('\0',12),'live ON restores native capture')
check(not aim.lease and not aim.direction,'automatic mode discards stale manual interpolation')
check(memory[300]==before_motor,'producer-owned outputs are not restored to stale pre-control targets')
check(memory[400]=='\0','automatic mode releases manual motor activation')
tick(aim,snapshot,{0,0,0},{0,1,0},false)
check(memory[100]==B.u32(2),'live OFF reacquires manual aim')
aim:clear()
check(memory[100]==B.u32(0) and memory[400]=='\0','exit restores acquisition and motor activation')
local writes=channel.writes;aim:clear()
check(channel.writes==writes,'repeat cleanup is harmless')

-- Camera-to-gun convergence uses the weapon origin, not the player/body origin.
aim,channel,memory,snapshot=fixture()
snapshot.weapon_position={1,2,3}
snapshot.weapon_forward={0,1,0}
for _=1,50 do result=tick(aim,snapshot,{4,5,6},{0,1,0},false) end
check(memory[200]==channel:floats({4,105,6}),'weapon-offset aim converges to the same camera world point')
aligned(memory)
local norm=0;for i=1,3 do norm=norm+result.direction[i]^2 end
check(math.abs(norm-1)<1e-10,'offset convergent shot direction stays normalized')

local function follow(dt,frames,target)
    local direction={0,1,0}
    for _=1,frames do direction=Aim.follow(direction,target,dt) end
    return direction
end
local slow,fast=follow(1/30,3,{1,0,0}),follow(1/120,12,{1,0,0})
for i=1,3 do check(math.abs(slow[i]-fast[i])<1e-8,'turn delay independent of FPS') end
for _,target in ipairs({{0,-1,0},{0,0,1},{0,0,-1},{0.000001,-1,0},{1,0,0}}) do
    local direction=follow(0.01,110,target)
    local magnitude=math.sqrt(target[1]^2+target[2]^2+target[3]^2)
    for i=1,3 do check(math.abs(direction[i]-target[i]/magnitude)<1e-8,'180-degree and vertical turns converge') end
end
result=Aim.follow({0,1,0},{1,0,0},0)
check(result[1]==0 and result[2]==1,'zero time cannot rotate')
local yaw=Aim.turn(math.pi-0.01,-math.pi+0.01,0.01)
check(math.abs(yaw-(math.pi+0.01))<1e-8,'yaw uses shortest turn across angle wrap')
yaw=Aim.turn(0,math.pi,0.02)
check(math.abs(yaw)<=math.pi*0.02+1e-10,'pole crossing cannot snap body yaw 180 degrees')
for _,dt in ipairs({-1,1,0/0,math.huge}) do
    check(not pcall(Aim.follow,{0,1,0},{1,0,0},dt),'invalid aim timing refused')
end

for _,value in ipairs({1,2,4,8}) do
    aim,channel,memory,snapshot=fixture();memory[100]=B.u32(value)
    check(not pcall(tick,aim,snapshot,{0,0,0},{0,1,0},false),'foreign native mode not overwritten')
    check(channel.writes==0,'refusal performs no writes')
end
for _,forward in ipairs({{0,0,0},{0,2,0},{0/0,1,0},{0,math.huge,0},{0,0.5,0}}) do
    aim,channel,memory,snapshot=fixture()
    check(not pcall(tick,aim,snapshot,{0,0,0},forward,false),'invalid direction refused')
    check(channel.writes==0,'invalid direction cannot partially capture targeting')
end
aim,channel,memory,snapshot=fixture()
check(not pcall(tick,aim,snapshot,{math.huge,0,0},{0,1,0},false),'nonfinite camera refused')
check(not pcall(tick,aim,snapshot,{0,0,0},{0,1,0},1),'nonboolean option refused')
snapshot.aim_motor.invalid=true
check(not pcall(tick,aim,snapshot,{0,0,0},{0,1,0},false) and channel.writes==0,
    'missing owned motor refuses before takeover')
snapshot.aim_motor.invalid=false
tick(aim,snapshot,{0,0,0},{0,1,0},false)
memory[100]=B.u32(4)
local outputs={memory[300],memory[400],memory[500]}
check(not pcall(tick,aim,snapshot,{0,0,0},{1,0,0},false),'changed mode stops all manual writes')
check(memory[300]==outputs[1] and memory[400]==outputs[2] and memory[500]==outputs[3],
    'foreign mode cannot reach model or fire consumers')
aim:clear()
check(memory[100]==B.u32(4) and memory[200]==string.rep('\0',12),'foreign mode survives cleanup')

aim,channel,memory,snapshot=fixture()
tick(aim,snapshot,{0,0,0},{0,1,0},false)
snapshot.targeting.invalid=true
local before=channel.writes
check(not pcall(tick,aim,snapshot,{0,0,0},{1,0,0},true),'changed identity refused even for ON')
aim:clear()
check(channel.writes==before+1 and memory[100]==B.u32(2) and memory[400]=='\0',
    'reallocated target is untouched while independently valid motor activation is restored')

for _,failed in ipairs({100,200,300,400,500}) do
    aim,channel,memory,snapshot=fixture();channel.failed=failed
    check(not pcall(tick,aim,snapshot,{0,0,0},{0,1,0},false),'partial capture/consumer failure surfaced')
    channel.failed=nil;aim:clear()
    check(memory[100]==B.u32(0) and not aim.direction,'partial aim capture restores native mode')
end
aim,channel,memory,snapshot=fixture()
tick(aim,snapshot,{0,0,0},{0,1,0},false)
channel.failed=100
check(not pcall(aim.clear,aim) and aim.lease~=nil,'failed restore retained for retry')
channel.failed=nil;aim:clear()
check(memory[100]==B.u32(0) and not aim.lease,'cleanup retries without stale writes')
aim,channel,memory,snapshot=fixture()
tick(aim,snapshot,{0,0,0},{0,1,0},false);snapshot.aim_motor.invalid=true
before=channel.writes
check(not pcall(tick,aim,snapshot,{0,0,0},{1,0,0},false) and before==channel.writes,
    'changed motor identity never writes an old output array')
aim:clear()
check(memory[100]==B.u32(0),'motor failure still releases independent targeting capture')
aim,channel,memory,snapshot=fixture()
snapshot.aim_motor=nil
snapshot.aim_motor_reason='lookat_component_absent'
local outputs={memory[300],memory[400],memory[500]}
local facing=tick(aim,snapshot,{0,0,0},{1,0,0},false)
check(facing and math.abs(facing.body_rotation[3])>0,'absent model motor keeps continuous body aiming')
check(memory[100]==B.u32(2) and memory[200]~=string.rep('\0',12),'fallback updates verified targeting')
check(memory[300]==outputs[1] and memory[400]==outputs[2] and memory[500]==outputs[3],
    'fallback never writes optional model or fire-output addresses')
tick(aim,snapshot,{0,0,0},{0,1,0},true)
check(memory[100]==B.u32(0) and not aim.lease,'automatic mode restores fallback targeting')
aim,channel,memory,snapshot=fixture()
tick(aim,snapshot,{0,0,0},{0,1,0},false)
memory[100],memory[200],memory[400]=B.u32(0),string.rep('\0',12),'\0'
tick(aim,snapshot,{0,0,0},{1,0,0},false)
check(memory[100]==B.u32(2) and memory[400]=='\1','owned native aim reset is recaptured without recall')
aligned(memory)
aim:clear()
check(memory[400]=='\0','recalled drone does not keep manual LookAt activation')
tick(aim,snapshot,{0,0,0},{0,1,0},false)
aligned(memory)
aim:clear()
check(memory[100]==B.u32(0) and memory[400]=='\0','repeated recall/reentry leaves clean aim state')

aim,channel,memory,snapshot=fixture()
snapshot.ownership_key='hot-dog-owner'
tick(aim,snapshot,{0,0,0},{0,1,0},false)
local old_target,old_motor=snapshot.targeting,snapshot.aim_motor
old_target.invalid,old_motor.invalid=true,true
memory[600],memory[700],memory[800]=memory[100],memory[200],memory[400]
snapshot.targeting={flags=600,position=700,valid=function()return true end}
snapshot.aim_motor={engaged=800,valid=function()return true end}
aim:rebind(snapshot);aim:clear()
check(memory[600]==B.u32(0) and memory[800]=='\0','same-owner relocated activation is restored on exit')
check(memory[100]==B.u32(2) and memory[400]=='\1','obsolete output storage is never written during cleanup')
aim,channel,memory,snapshot=fixture()
memory[400]='\1'
tick(aim,snapshot,{0,0,0},{0,1,0},false)
memory[400]='\0'
tick(aim,snapshot,{0,0,0},{1,0,0},false)
check(memory[400]=='\1','native motor reset is recoverable even if initially active')
aim:clear()
check(memory[400]=='\0','latest native motor reset is preserved on exit')
aim,channel,memory,snapshot=fixture()
memory[400]='\2'
check(not pcall(tick,aim,snapshot,{0,0,0},{0,1,0},false) and channel.writes==0,
    'unknown activation flags refuse before partial capture')
return checks
