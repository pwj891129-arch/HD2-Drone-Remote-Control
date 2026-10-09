local checks = 0
local function check(value, message) assert(value,message); checks = checks+1 end
local B, Lease, Flight, Controller, Hotkey, Cooperation, Aim, Pose, SeekerControl, SeekerHotkey = ...
local memory = {}; local writes = 0; local failed, stolen = nil,false
local channel = {}
local ffi = require('ffi')
local function floats(values)
    local raw = ffi.new('float[?]',#values)
    for i,value in ipairs(values) do raw[i-1] = value end
    return ffi.string(raw,#values*4)
end
local function command()
    local raw = ffi.new('float[4]')
    ffi.copy(raw,memory[1600],16)
    return {tonumber(raw[0]),tonumber(raw[1]),tonumber(raw[2]),tonumber(raw[3])}
end
function channel:read(at,size) return memory[at] end
function channel:float(raw,at)
    local value = ffi.new('float[1]');ffi.copy(value,raw:sub(at+1,at+4),4)
    return tonumber(value[0])
end
function channel:write(at,value)
    writes = writes+1
    if at == failed then return false end
    memory[at] = value; return true
end
memory[100],memory[200] = 'abcd','efgh'
local lease = Lease.new(channel)
local first = lease:claim(100,'abcd','1234',function() return not stolen end)
check(memory[100] == '1234','claim')
lease:set(first,'5678'); check(memory[100] == '5678','set')
check(lease:release() and memory[100] == 'abcd','restore')
lease = Lease.new(channel)
first = lease:claim(100,'abcd','1234',function() return not stolen end)
memory[100] = 'abcd'
lease:reassert(first)
check(memory[100]=='1234','known reset reasserted')
memory[100] = 'OTHER'
check(not pcall(lease.reassert,lease,first),'unknown reset refused')
memory[100]='abcd';stolen=true
check(not pcall(lease.reassert,lease,first),'reset on replaced identity refused')
stolen=false
check(not pcall(Lease.new(channel).reassert,Lease.new(channel),first),'foreign lease item refused')
lease:reassert(first);lease:release()
lease = Lease.new(channel)
first = lease:claim(100,'abcd','1234',function() return true end)
failed = 100
check(not pcall(lease.set,lease,first,'5678'),'write failure')
failed = nil
check(lease:release() and memory[100] == 'abcd','rollback after set failure')
lease = Lease.new(channel)
first = lease:claim(100,'abcd','1234',function() return true end)
memory[100] = 'OTHER'
check(lease:release() and memory[100] == 'OTHER' and lease.conflicts == 1,'foreign write preserved')
lease = Lease.new(channel)
memory[100] = 'abcd'
lease:claim(100,'abcd','1234',function() return not stolen end)
stolen = true
check(lease:release() and memory[100] == '1234','reallocated identity never written')
stolen = false
lease = Lease.new(channel)
memory[100] = 'abcd'
first = lease:claim(100,'abcd','1234',function() return not stolen end)
memory[200] = '1234'
local before_rebind = writes
check(not pcall(lease.rebind,lease,first,200,function() return true end),
    'still-valid source cannot move to a duplicate target')
stolen = true
lease:rebind(first,200,function() return true end)
check(writes==before_rebind and first.original=='abcd','rebind preserves original without writing')
check(lease:release() and memory[200]=='abcd' and memory[100]=='1234','relocated copied bytes restored, stale source untouched')
check(not pcall(lease.rebind,lease,first,200,function() return true end),'released item cannot be rebound')
stolen = false
lease = Lease.new(channel)
memory[100] = 'abcd'
first = lease:claim(100,'abcd','1234',function() return not stolen end)
stolen = true
for _, target in ipairs({201,202}) do
    memory[201] = 'OTHER'
    check(not pcall(lease.rebind,lease,first,target,function() return true end),
        'foreign or unreadable relocation is refused')
end
memory[200]='1234'
check(not pcall(lease.rebind,lease,first,200,function() return false end),'unverified replacement refused')
lease:release();stolen=false
check(Flight.distance({0,0,0},{3,4,0}) == 5,'distance')
check(Flight.color(80)[3] == 225,'green through 80')
check(Flight.color(80.01)[3] == 165,'orange above 80')
check(Flight.color(90)[3] == 165,'orange through 90')
check(Flight.color(90.01)[3] == 65,'red above 90')
local input = {forward=1,back=0,left=0,right=1,up=1,down=0}
local pos,yaw,pitch,cam,quat = Flight.step({0,0,0},0,0,input,0.05)
check(math.abs(Flight.distance(pos,{0,0,0})-0.06)<1e-8,'normalized gradual thrust')
check(math.abs(quat[4]-1)<1e-8 and quat[1] == 0,'identity quaternion')
check(not pcall(Flight.step,{0,0,0},0,0,input,1),'large frame gap refused')
pos=Flight.step({0,0,0},0,0,input,0)
check(Flight.distance(pos,{0,0,0})==0,'zero delta keeps position still')
local still={forward=0,back=0,left=0,right=0,up=0,down=0}
local function velocity_after(dt,frames,keys,velocity)
    local speed
    for _=1,frames do
        local _,_,_,_,_,_,command,next_velocity=Flight.step({0,0,0},0,0,keys,dt,velocity)
        velocity,speed=next_velocity,command[4]
    end
    return velocity,speed
end
local v,slow=velocity_after(0.02,5,input)
local fast=velocity_after(0.01,10,input)
check(math.abs(slow-2.4)<1e-8,'acceleration is bounded in metres per second squared')
for i=1,3 do check(math.abs(v[i]-fast[i])<1e-8,'thrust independent of frame rate') end
v,slow=velocity_after(0.02,50,input,v)
check(math.abs(slow-8)<1e-8,'diagonal maximum speed is eight metres per second')
v,slow=velocity_after(0.02,1,still,v)
check(slow>0 and slow<8,'key release retains inertia')
v,slow=velocity_after(0.02,25,still,v)
check(slow==0,'braking finishes without indefinite drift')
check(not pcall(Flight.step,{0,0,0},0,0,input,0.02,{0/0,0,0}),'nonfinite velocity refused')
local _,_,_,_,q,f=Flight.step({0,0,0},0.6,0.3,still,0.02)
local qforward={2*(q[1]*q[2]-q[3]*q[4]),1-2*(q[1]*q[1]+q[3]*q[3]),2*(q[2]*q[3]+q[1]*q[4])}
for i=1,3 do check(math.abs(f[i]-qforward[i])<1e-8,'body forward agrees with camera quaternion') end

local function fixture(globals,state,aim,options,avoidance)
    local pressed = {}; local emitted = {}; local restored = 0
    channel.time,channel.commands = 0,{}
    local brain = {address=1000}
    function brain.valid() return not brain.invalid end
    local motion = {address=1500,enabled='\1'}
    function motion.valid() return not motion.invalid end
    memory[1000],memory[1100],memory[1284],memory[1300],memory[2000] = B.u32(190),'\4\0','POS','ROT','KEY'
    memory[1500] = '\1'
    local movement = {address=1600,original=floats({0,1,0,2})}
    function movement.valid() return not movement.invalid end
    memory[1600] = movement.original
    memory[2100],memory[2200],memory[2300] = 'MOVE','FIRE','VIEW'
    local snapshot = {brain=brain,motion=motion,movement=movement,
        weapon_position={0,5,2},weapon_forward={0,1,0},
        camera=10000,camera_row=1100,drone_position={0,5,2},actor_position={0,0,0},
        deployed=true,menu_active=false,token='identity',ownership_key='owner',heat=0,reserve=3,overheated=false,
        drone_name='ROVER',behavior_kind=190,feed='heat',exhausted=false,
        fire_valid=function() return true end,camera_valid=function() return true end,
        unit_valid=function() return true end,docked=false}
    local keys = {aim_mode=70,backpack=84,fire=1,forward=87,back=83,left=65,right=68,up=32,down=17,
        binding_token='bindings',pack_entries={{2000,'KEY'}},
        input_entries={{2100,'MOVE'},{2200,'FIRE'},{2300,'VIEW'}},valid=function() return true end}
    local reader = {}
    memory[3000],memory[3001],memory[3002] = '\1','\0',floats({0,0,0,1})
    function reader:rotation_controls(sample)
        check(sample==snapshot,'rotation capture uses current owned snapshot')
        return {rotation=3002,valid=snapshot.unit_valid}
    end
    function reader:bindings() return keys end
    function reader:snapshot() return snapshot end
    function reader:raw(at,size) return memory[at] or 'FORWARD' end
    function reader:word(at) return B.word(memory[at],0) end
    function channel:foreground() return true end
    function channel:now() return self.time end
    function channel:down(key) return pressed[key] == true end
    function channel:mouse_delta() return self.mouse_x or 0,self.mouse_y or 0 end
    function channel:vector() return {0,1,0} end
    function channel:floats(values) return floats(values) end
    function channel:fire(_,down) emitted[#emitted+1] = down end
    function channel:key(key,down)
        if down then
            check(key==keys.backpack and memory[2000]=='KEY','configured backpack input after binding restore')
            check(memory[1000]==B.u32(snapshot.behavior_kind) and memory[1100]=='\4\0','recall/deploy never capture AI or camera')
            check(memory[1500]=='\1','recall/deploy leave autonomous flight enabled')
            check(memory[2100]=='MOVE' and memory[2200]=='FIRE' and memory[2300]=='VIEW',
                'recall/deploy never suppress player movement/fire')
        end
        self.commands[#self.commands+1]={key=key,down=down}
        pressed[key]=down
        if not down then
            snapshot.docked=not snapshot.docked
            snapshot.deployed=not snapshot.docked
            snapshot.drone_position=snapshot.docked and {0,0,0.8} or {0,5,2}
        end
        return true
    end
    local engine = {moved=0}
    function engine:prepare() end
    function engine:observe()
        return {docked=snapshot.docked,airborne=not snapshot.docked,free=not snapshot.docked,
            position=snapshot.drone_position,distance=Flight.distance(snapshot.drone_position,snapshot.actor_position)}
    end
    function engine:capture_input() end
    function engine:clear() restored=restored+1 end
    function engine:move(_,position,rotation,_,automatic)
        check(memory[1000]==B.u32(0) and memory[1500]=='\0','both AI and autonomous flight paused before movement')
        check(memory[3000]=='\1' and memory[3001]=='\0','actor rotation flags untouched during flight/fire')
        if not automatic then
            check(memory[3002]==floats(rotation),'canonical pose published before scene rotation')
        end
        self.moved=self.moved+1
        self.command=command()
        self.rotation=rotation
        self.position=position
    end
    function engine:hud(_,_,_,surface_ready) self.surface_ready=surface_ready end
    local cooperation = globals and Cooperation.new(globals,state)
    local c = Controller.new(channel,reader,engine,B,Lease,Flight,Hotkey,function() end,cooperation,aim,options,
        Pose.new(channel,B,Lease),avoidance)
    local tick=c.tick
    function c:tick(dt) channel.time=channel.time+dt;return tick(self,dt) end
    return c,pressed,snapshot,engine,emitted,function() return restored end,reader
end
local function enter(c,pressed)
    local original_behavior = memory[1000]
    c:tick(0.02)
    pressed[70]=true;c:tick(0.02)
    pressed[84]=true;c:tick(0.02)
    check(not c.active and c.pending and memory[1000]==original_behavior,'entry starts preparation without player takeover')
    pressed[70],pressed[84]=false,false
    for _=1,200 do
        c:tick(0.02)
        if c.active then return end
    end
    error('entry never completed')
end
local c,pressed,snapshot,engine,emitted,restored = fixture()
enter(c,pressed)
check(c.active and memory[1000] == B.u32(0) and memory[1100] == '\0\0','entry without native stratagem menu')
check(memory[1500]=='\0','owned Boids simulation paused during control')
check(memory[3000]=='\1','entry never captures actor rotation')
check(command()[4]==0,'takeover clears residual native movement speed')
check(c.input_lease and c.keys.inputs_suppressed and memory[2100]==B.u32(0) and
    memory[2200]==B.u32(0) and memory[2300]==B.u32(0),'player controls disabled only after deployment')
pressed[84]=false;pressed[70]=false;pressed[1]=true;c:tick(0.02)
check(c.active and engine.moved == 1 and emitted[#emitted] == true,'movement and fire')
pressed[1]=false;c:tick(0.02)
check(emitted[#emitted] == false,'fire released')
pressed[84]=true;c:tick(0.02)
check(not c.active and memory[1000] == B.u32(190) and memory[1100] == '\4\0','fresh backpack exits')
check(memory[1500]=='\1','exit restores autonomous flight')
check(memory[3000]=='\1' and memory[3001]=='\0' and memory[3002]==floats({0,0,0,1}),
    'exit leaves actor rotation alone and restores original body pose')
check(memory[1600]==snapshot.movement.original,'exit restores the owned Mover command')
check(memory[2000] == 'KEY' and restored() == 1,'bindings and focus restored')
check(not c.input_lease and memory[2100]=='MOVE' and memory[2200]=='FIRE' and memory[2300]=='VIEW',
    'exit restores player bindings')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
local first_row=snapshot.camera_row
for i=1,40 do
    local row=30000+i*0xE8
    memory[row],memory[row+0xB8],memory[row+0xC8]='\4\0','POS'..i,'ROT'..i
    snapshot.camera_row=row
    c:tick(0.02)
    check(c.active and memory[row]=='\0\0','new actor camera request remains in control')
    check(#c.session.camera_lease.items==3 and #c.session.lease.items==3,'camera claims stay bounded')
end
check(memory[first_row]=='\4\0' and memory[first_row+0xB8]=='POS','old camera row restored before replacement')
local final_row=snapshot.camera_row
c:stop('camera_refresh_done')
check(memory[final_row]=='\4\0' and memory[1500]=='\1','latest camera and flight restored on exit')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
memory[1100],memory[1284],memory[1300]='\4\0','QUEUED_POS','QUEUED_ROT'
c:tick(0.02)
check(c.active and memory[1100]=='\0\0','same ring slot with new actor camera request reacquired')
c:stop('same_slot')
check(memory[1284]=='QUEUED_POS' and memory[1300]=='QUEUED_ROT','new same-slot originals restored not old pose')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
memory[30000],memory[30184],memory[30200]='\4\0','OTHER_POS','OTHER_ROT'
snapshot.camera_row=30000;snapshot.camera_valid=function() return false end
check(not pcall(c.tick,c,0.02),'foreign camera identity refused')
c:stop('foreign_camera')
check(memory[30000]=='\4\0' and memory[30184]=='OTHER_POS','foreign camera never written')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
memory[30000],memory[30184],memory[30200]='\4\0','NEW_POS','NEW_ROT'
snapshot.camera_row=30000;failed=1100
check(not pcall(c.tick,c,0.02),'camera handoff stops on old row restore failure')
check(memory[30000]=='\4\0','new row untouched while old restore pending')
c:stop('handoff_failure');check(c.pending_cleanup,'camera handoff cleanup retained')
failed=nil;c:tick(0.02)
check(not c.pending_cleanup and memory[1100]=='\4\0' and memory[1500]=='\1','failed handoff cleanup retries')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
memory[1500]='\1'
local ok,why=pcall(c.tick,c,0.02)
check(not ok and tostring(why):find('control_motion_resumed'),'foreign motion resume has a distinct refusal')
c:stop('foreign_motion')
check(memory[1500]=='\1','foreign flight flag preserved')
c,pressed,snapshot,engine=fixture();snapshot.motion.enabled='\0'
check(not pcall(enter,c,pressed),'entry refuses inactive autonomous-flight component')
c:stop('motion_not_ready')
check(memory[1000]==B.u32(190) and memory[1100]=='\4\0','invalid motion entry never captures camera or AI')
c,pressed,snapshot,engine=fixture();failed=1500
check(not pcall(enter,c,pressed),'partial autonomous flight pause failure surfaced')
failed=nil;c:stop('motion_capture_failed')
check(memory[1000]==B.u32(190) and memory[1500]=='\1' and memory[1100]=='\4\0' and
    memory[2100]=='MOVE','failed motion pause rolls back AI and player inputs')
c,pressed,snapshot,engine=fixture();enter(c,pressed);failed=1500
c:stop('motion_restore_failed')
check(c.pending_cleanup and memory[1500]=='\0','failed flight restore prevents reentry')
failed=nil;c:tick(0.02)
check(not c.pending_cleanup and memory[1500]=='\1','owned flight restore retries')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
snapshot.motion.invalid=true
check(not pcall(c.tick,c,0.02),'reallocated flight metadata refuses control')
c:stop('reallocated_motion')
check(memory[1500]=='\0' and memory[1000]==B.u32(190),'foreign flight metadata never restored')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
pressed[1]=true;c:tick(0.02)
memory[1000]=B.u32(190);c:tick(0.02)
check(c.active and memory[1000]==B.u32(0),'manual fire behavior reset no longer exits camera')
pressed[1]=false;c:tick(0.02)
memory[1000]=B.u32(190);c:tick(0.02)
check(c.active and memory[1000]==B.u32(0),'brief post-fire reset remains captured')
for _=1,55 do c:tick(0.02) end
memory[1000]=B.u32(190)
check(not pcall(c.tick,c,0.02),'idle autonomous resume outside fire window still refuses')
c:stop('idle_reset')
check(memory[1000]==B.u32(190) and memory[1500]=='\1','cleanup preserves original resumed behavior')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
pressed[1]=true;c:tick(0.02);memory[1000]=B.u32(191)
check(not pcall(c.tick,c,0.02),'unexpected behavior never reclaimed while firing')
c:stop('foreign_behavior');check(memory[1000]==B.u32(191),'foreign behavior preserved on cleanup')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
pressed[1]=true;c:tick(0.02);memory[1000]=B.u32(190);failed=1000
check(not pcall(c.tick,c,0.02),'failed behavior reassert surfaced')
failed=nil;c:stop('renew_failure')
check(memory[1000]==B.u32(190) and memory[1500]=='\1','failed behavior reassert cleans up other leases')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
local start={unpack(snapshot.drone_position)}
for _=1,50 do
    c:tick(0.02)
    local move=command()
    for i=1,3 do snapshot.drone_position[i]=snapshot.drone_position[i]+move[i]*move[4]*0.02 end
end
check(Flight.distance(start,snapshot.drone_position)==0,'native movement stays still after takeover without input')
pressed[87]=true
for _=1,100 do
    c:tick(0.02)
    local move=command()
    for i=1,3 do snapshot.drone_position[i]=snapshot.drone_position[i]+move[i]*move[4]*0.02 end
end
check(Flight.distance(start,snapshot.drone_position)>14 and Flight.distance(start,snapshot.drone_position)<16 and
    math.abs(command()[4]-8)<1e-4,'W gradually reaches eight metres per second')
pressed[87]=false;c:tick(0.02)
check(command()[4]>0 and command()[4]<8,'release brakes instead of stopping abruptly')
local stopped={unpack(snapshot.drone_position)}
for _=1,50 do
    c:tick(0.02)
    local move=command()
    for i=1,3 do snapshot.drone_position[i]=snapshot.drone_position[i]+move[i]*move[4]*0.02 end
end
check(Flight.distance(stopped,snapshot.drone_position)>0 and Flight.distance(stopped,snapshot.drone_position)<2 and
    command()[4]==0,'release glides briefly then stops')
for _,key in ipairs({83,65,68,32,17}) do
    pressed[key]=true;c:tick(0.02)
    check(command()[4]>0 and command()[4]<8,'all mapped directions accelerate the native command')
    pressed[key]=false;c:tick(0.02)
    check(command()[4]>0,'every direction retains brief inertia')
    for _=1,30 do c:tick(0.02) end
    check(command()[4]==0,'every direction eventually brakes to neutral')
end
pressed[87],pressed[83]=true,true;c:tick(0.02)
check(command()[4]==0,'opposite held movement keys cancel')
pressed[87],pressed[83]=false,false
c:stop('movement_test')
check(memory[1600]==snapshot.movement.original,'native command restored after sustained manual movement')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
snapshot.movement.invalid=true
local ok,why=pcall(c.tick,c,0.02)
check(not ok and tostring(why):find('control_movement_changed'),'reallocated Mover input cannot be written')
c:stop('foreign_mover')
check(command()[4]==0,'foreign Mover input never restored')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
local foreign=floats({1,0,0,3});memory[1600]=foreign
check(not pcall(c.tick,c,0.02),'foreign Mover writer causes refusal before overwrite')
c:stop('mover_conflict')
check(memory[1600]==foreign and memory[1500]=='\1','foreign command preserved while owned AI and Boids are restored')
c,pressed,snapshot,engine=fixture();failed=1600
check(not pcall(enter,c,pressed),'partial Mover capture failure is surfaced')
failed=nil;c:stop('mover_capture_failed')
check(memory[1600]==snapshot.movement.original and memory[1500]=='\1' and memory[1000]==B.u32(190),
    'partial Mover capture rolls back both autonomous systems')
c,pressed,snapshot,engine=fixture();enter(c,pressed);failed=1600
c:stop('mover_restore_failed')
check(c.pending_cleanup,'failed owned Mover restore blocks reentry')
failed=nil;c:tick(0.02)
check(not c.pending_cleanup and memory[1600]==snapshot.movement.original,'owned Mover restore retries')
c,pressed,snapshot,engine=fixture()
c:tick(0.02);pressed[18]=true;c:tick(0.02);pressed[84]=true;c:tick(0.02)
check(not c.active and not c.pack_lease and memory[2000]=='KEY','old stratagem combo leaves normal backpack action intact')
pressed[84]=false;pressed[18]=false;pressed[70]=true;c:tick(0.02)
check(c.pack_lease and memory[2000]==B.u32(0),'mapped aim mode arms backpack suppression')
pressed[70]=false;c:tick(0.02)
check(not c.pack_lease and memory[2000]=='KEY','modifier release restores unselected backpack action')
c,pressed,snapshot,engine=fixture();snapshot.deployed=false;snapshot.docked=true
c:tick(0.02);pressed[70]=true;c:tick(0.02);pressed[84]=true;c:tick(0.02)
check(not c.active and c.pending and c.pack_lease,'stowed drone starts staged control without toggling immediately')
pressed[70],pressed[84]=false,false
for _=1,80 do c:tick(0.02);if c.active then break end end
check(c.active and #channel.commands==2,'already docked Rover only deploys once')
c:stop('test_done')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
check(#channel.commands==4 and channel.commands[1].down and not channel.commands[2].down and
    channel.commands[3].down and not channel.commands[4].down,'airborne Rover is recalled then deployed')
c:stop('test_done')
for _, reason in ipairs({'range','heat','connection','focus'}) do
    c,pressed,snapshot,engine,emitted,restored=fixture();enter(c,pressed);pressed[84]=false
    if reason == 'range' then snapshot.drone_position={0,101,0}
    elseif reason == 'heat' then snapshot.overheated=true
    elseif reason == 'connection' then snapshot.token='respawn'
    else function channel:foreground() return false end end
    local ok = pcall(c.tick,c,0.02)
    if not ok then c:stop('refused') end
    check(not c.active and memory[1000] == B.u32(190) and memory[1100] == '\4\0' and
        memory[1500]=='\1','automatic cleanup '..reason)
end
c,pressed,snapshot,engine=fixture()
function engine:capture_input() error('partial focus failure') end
local ok=pcall(enter,c,pressed)
check(not ok,'partial entry failure surfaced')
c:stop('refused')
check(memory[1000] == B.u32(190) and memory[1100] == '\4\0' and memory[2000] == 'KEY','partial entry rolled back')
check(not c.input_lease and memory[2100]=='MOVE' and memory[2200]=='FIRE','failed camera/input capture restores player controls')
c,pressed,snapshot,engine=fixture()
failed=2200
check(not pcall(enter,c,pressed),'partial player binding write failure surfaced')
failed=nil;c:stop('input_capture_failed')
check(not c.input_lease and memory[2100]=='MOVE' and memory[2200]=='FIRE' and
    memory[1000]==B.u32(190) and memory[1100]=='\4\0','partial binding write failure restores without AI/camera takeover')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
failed=2100;c:stop('input_restore_failed')
check(c.pending_cleanup and c.input_lease and c.keys and c.keys.inputs_suppressed,
    'failed player binding restore keeps original keys and blocks reentry')
failed=nil;c:tick(0.02)
check(not c.pending_cleanup and not c.input_lease and memory[2100]=='MOVE','player binding cleanup retries')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
memory[2200]='EDIT'
c:stop('external_binding_change')
check(memory[2200]=='EDIT' and memory[2100]=='MOVE' and memory[2300]=='VIEW',
    'foreign binding edit preserved without stranding other owned bindings')
c,pressed,snapshot,engine=fixture();enter(c,pressed)
failed=1100;c:stop('exit')
check(c.pending_cleanup and not c.active,'failed restore blocks reentry')
failed=nil;c:tick(0.02)
check(not c.pending_cleanup and not c.session and memory[1100] == '\4\0','cleanup retries')
local state, owner, suspended, resumed = {},nil,0,0
local peer = {input_api=1,config={radial=true,enabled=true}}
function peer.suspend_input(token) owner=token;suspended=suspended+1;return true end
function peer.resume_input(token) check(token==owner,'matching owner resumes');resumed=resumed+1;return true end
c,pressed,snapshot,engine=fixture({HD2StratagemHotkeys=peer,HD2HelperAutoReload=peer},state)
function engine:capture_input() check(state.blocking_inputs and suspended>=2,'peers quiet before focus capture') end
enter(c,pressed)
check(c.active and state.blocking_inputs,'compatible enabled peers allow control')
failed=1100;c:stop('exit')
check(c.pending_cleanup and state.blocking_inputs and resumed==0,'restoration failure keeps peers suspended')
failed=nil;c:tick(0.02)
check(not state.blocking_inputs and resumed==1,'successful restoration resumes shared participant once')
check(peer.config.radial and peer.config.enabled,'Arsenal preferences unchanged')
c,pressed,snapshot,engine=fixture({HD2StratagemHotkeys={config={radial=true}}},{})
check(not pcall(enter,c,pressed),'old companion refuses entry')
c:stop('old_companion')
check(memory[1000]==B.u32(190) and memory[1100]=='\4\0','old companion never captures AI or camera')
state={};c,pressed,snapshot,engine=fixture({HD2StratagemHotkeys=peer},state)
function engine:capture_input() error('capture failure') end
check(not pcall(enter,c,pressed),'entry capture failure surfaced')
c:stop('capture_failed')
check(not state.blocking_inputs and not c.pending_cleanup,'failed entry releases companions after rollback')
function engine:capture_input() end
c:tick(0.02)
check(not c.active and not c.pending,'failed entry cannot restart without a fresh press')
pressed[84]=false;c:tick(0.02)
enter(c,pressed)
check(c.active,'fresh backpack press retries after failure')
c:stop('test_done')

for _,reason in ipairs({'timeout','focus','cancel','identity','bindings'}) do
    c,pressed,snapshot,engine=fixture()
    c:tick(0.02);pressed[70]=true;c:tick(0.02);pressed[84]=true;c:tick(0.02)
    pressed[70],pressed[84]=false,false;c:tick(0.02)
    if reason=='timeout' then channel.time=20
    elseif reason=='focus' then function channel:foreground() return false end
    elseif reason=='cancel' then pressed[84]=true
    elseif reason=='bindings' then c.keys.binding_token='changed'
    else snapshot.token='replacement' end
    local ok=pcall(c.tick,c,0.02)
    if not ok then c:stop('refused') end
    check(not c.active and not c.pending and memory[1000]==B.u32(190) and memory[1100]=='\4\0',
        'preparation abort never captures player '..reason)
    check(memory[2000]=='KEY','preparation abort restores backpack '..reason)
end
c,pressed,snapshot,engine=fixture()
c:tick(0.02);pressed[70]=true;c:tick(0.02);pressed[84]=true;c:tick(0.02)
pressed[70],pressed[84]=false,false
for _=1,30 do c:tick(0.02);if c.pulse then break end end
check(c.pulse~=nil,'test reached owned backpack pulse')
local key=channel.key
function channel:key(vk,down) if not down then return false end;return key(self,vk,down) end
c:stop('cancel')
check(c.pending_cleanup and c.pulse,'failed key-up is retained for cleanup')
channel.key=key;c:tick(0.02)
check(not c.pending_cleanup and not c.pulse,'owned backpack release retries before allowing entry')
c,pressed,snapshot,engine=fixture()
local delayed_send=channel.key
local echo_until=0
function channel:key(vk,down)
    local result=delayed_send(self,vk,down)
    if not down then echo_until=self.time+0.06;pressed[vk]=true end
    return result
end
local physical_down=channel.down
function channel:down(vk)
    if vk==84 and echo_until>0 and self.time>=echo_until then
        pressed[vk]=false;echo_until=0
    end
    return physical_down(self,vk)
end
enter(c,pressed)
check(c.active and #channel.commands==4,'delayed synthetic key-up cannot cancel recall or deployment')
c:stop('delayed_input_test')
c,pressed,snapshot,engine=fixture()
local send=channel.key
function channel:key(vk,down)
    local result=send(self,vk,down)
    snapshot.docked,snapshot.deployed=false,true
    snapshot.drone_position={0,5,2}
    return result
end
c:tick(0.02);pressed[70]=true;c:tick(0.02);pressed[84]=true;c:tick(0.02)
pressed[70],pressed[84]=false,false
for _=1,500 do c:tick(0.02);if not c.pending then break end end
check(not c.active and not c.pending and #channel.commands==2,'failed recall times out without repeated toggles')
check(memory[1000]==B.u32(190) and memory[1100]=='\4\0','failed recall never captures AI or camera')
check(not c.input_lease and memory[2100]=='MOVE' and memory[2200]=='FIRE','failed recall leaves player input intact')
local aim=Aim.new(channel,B,Lease)
local options={auto_aim=false}
c,pressed,snapshot,engine,emitted=fixture(nil,nil,aim,options)
snapshot.targeting={flags=2400,position=2500,valid=function()return true end}
snapshot.aim_motor={position=2600,engaged=2700,fire_position=2800,valid=function()return true end}
memory[2400],memory[2500]=B.u32(0),floats({0,0,0})
memory[2600],memory[2700],memory[2800]=floats({0,0,0}),'\0',floats({0,0,0})
local move=engine.move
function engine:move(a,b,q,f,automatic)
    self.automatic=automatic
    check(memory[2400]==B.u32(automatic and 0 or 2),'aim mode captured before rotation and fire')
    if not automatic then
        check(q[1]==0 and q[2]==0,'body yaw does not substitute for lower gun pitch')
        check(memory[2500]==memory[2600] and memory[2500]==memory[2800] and memory[2700]=='\1',
            'model motor and firing share the delayed point before movement or fire')
    end
    return move(self,a,b,q,f,automatic)
end
function engine:hud(a,d,automatic) self.hud_automatic=automatic end
enter(c,pressed);c:tick(0.02)
check(c.active and memory[2400]==B.u32(2) and not engine.automatic,'manual default linked into active controller')
check(not emitted[#emitted] and memory[2500]~=floats({0,0,0}),'camera aim updates without an attack')
channel.mouse_x,channel.mouse_y=300,-200;c:tick(0.02)
channel.mouse_x,channel.mouse_y=0,0
check(c.active and not emitted[#emitted] and math.abs(engine.rotation[3])>0,
    'mouse alone turns body before any attack')
check(engine.rotation[1]==0 and engine.rotation[2]==0,
    'mouse pitch goes to lower model motor without pitching the body')
check(math.abs(2*math.atan2(engine.rotation[3],engine.rotation[4]))<math.abs(c.session.yaw),
    'body follows the faster camera with a rate-limited delay')
options.auto_aim=true;c:tick(0.02)
check(memory[2400]==B.u32(0) and engine.automatic and engine.hud_automatic,'live automatic option reaches engine and HUD')
options.auto_aim=false;c:tick(0.02)
check(memory[2400]==B.u32(2) and not engine.automatic,'live manual option reclaims explicit aim')
pressed[1]=true;c:tick(0.02)
check(emitted[#emitted] and c.active,'manual fire retains aim capture')
failed=2400;c:stop('aim_restore_test')
check(c.pending_cleanup and c.session and aim.lease,'failed aim cleanup blocks reentry')
failed=nil;c:tick(0.02)
check(not c.pending_cleanup and not c.session and not aim.lease,'controller retries aim restoration')
check(memory[2400]==B.u32(0) and memory[2500]==floats({0,0,0}),'controller exit restores targeting')
aim=Aim.new(channel,B,Lease)
c,pressed,snapshot,engine,emitted=fixture(nil,nil,aim,{auto_aim=false})
snapshot.targeting={flags=2400,position=2500,valid=function()return true end}
snapshot.aim_motor_reason='lookat_component_absent'
memory[2400],memory[2500]=B.u32(0),floats({0,0,0})
memory[2600],memory[2700],memory[2800]='UNUSED','UNUSED','UNUSED'
enter(c,pressed);c:tick(0.02)
check(c.active and c.status=='controlling','absent optional LookAt still enters camera/movement control')
check(memory[2400]==B.u32(2),'fallback captures only validated Targeting path')
pressed[87]=true;c:tick(0.02)
check(command()[4]>0,'fallback accepts movement input')
channel.mouse_x=300;c:tick(0.02);channel.mouse_x=0
check(c.active and math.abs(engine.rotation[3])>0,'fallback body follows mouse without shooting')
check(memory[2600]=='UNUSED' and memory[2700]=='UNUSED' and memory[2800]=='UNUSED',
    'absent optional addresses remain untouched')
c:stop('fallback_test')
check(not c.active and memory[2400]==B.u32(0) and memory[1100]=='\4\0',
    'fallback restores camera, targeting and input on exit')

for _, case in ipairs({'copied','foreign','different_owner'}) do
    aim=Aim.new(channel,B,Lease)
    c,pressed,snapshot,engine=fixture(nil,nil,aim,{auto_aim=false})
    local targeting={flags=2400,position=2500}
    function targeting.valid() return not targeting.invalid end
    snapshot.targeting=targeting
    snapshot.aim_motor_reason='lookat_component_absent'
    memory[2400],memory[2500]=B.u32(0),floats({0,0,0})
    enter(c,pressed);pressed[87]=true;c:tick(0.02)
    local original_movement=c.session.movement.original
    local old_brain,old_motion,old_movement=snapshot.brain,snapshot.motion,snapshot.movement
    memory[51000],memory[52000],memory[53000]=memory[1000],memory[1500],memory[1600]
    memory[54000],memory[55000]=memory[2400],memory[2500]
    old_brain.invalid,old_motion.invalid,old_movement.invalid,targeting.invalid=true,true,true,true
    local valid=function() return true end
    snapshot.brain={address=51000,valid=valid}
    snapshot.motion={address=52000,valid=valid,enabled='\0'}
    snapshot.movement={address=53000,valid=valid,original=memory[53000]}
    snapshot.targeting={flags=54000,position=55000,valid=valid}
    if case=='foreign' then
        memory[51000]=B.u32(999);memory[53000]='FOREIGN';memory[55000]='OTHER_POINT'
    elseif case=='different_owner' then snapshot.ownership_key='different' end
    check(not pcall(c.tick,c,0.02),'component relocation fails closed before another control write')
    c:stop('relocation_'..case)
    check(not c.active and not c.pending_cleanup and not c.session,'relocation exit completes '..case)
    check(memory[3000]=='\1' and memory[3001]=='\0','forced exit never changes actor flags '..case)
    check(memory[2100]=='MOVE' and memory[2200]=='FIRE' and memory[2300]=='VIEW' and
        memory[1100]=='\4\0','forced exit restores camera and player input '..case)
    check(memory[1000]==B.u32(0) and memory[1500]=='\0','stale component buffers never restored '..case)
    if case=='copied' then
        check(memory[51000]==B.u32(190) and memory[52000]=='\1' and memory[53000]==original_movement,
            'cleanup restores original AI/motion values at verified refreshed storage')
        check(memory[54000]==B.u32(0) and memory[55000]==floats({0,0,0}),
            'cleanup restores original targeting not paused values from fresh snapshot')
    elseif case=='foreign' then
        check(memory[51000]==B.u32(999) and memory[53000]=='FOREIGN' and memory[55000]=='OTHER_POINT',
            'foreign writes on relocated components preserved')
        check(memory[52000]=='\1' and memory[54000]==B.u32(0),'independent copied flags still restored')
    else
        check(memory[51000]==B.u32(0) and memory[52000]=='\0' and memory[54000]==B.u32(2),
            'different ownership key never receives restore writes')
    end
end
local sensor = {cleared = 0,ready = false}
function sensor:clear() self.cleared=self.cleared+1;self.sample=nil end
function sensor:move(sample,position,wanted,dt,now,previous_velocity)
    check(sample.token=='identity' and dt==0.02 and now==channel.time,
        'clearance uses the current observed owner and frame time')
    check(wanted[2]>0 and previous_velocity[2]==0,'clearance receives desired and previous inertial velocity')
    if not self.ready then return position,{0,0,0,0},{0,0,0} end
    self.sample={}
    return {position[1],position[2]+2*dt,position[3]},{0,1,0,2},{0,2,0}
end
c,pressed,snapshot,engine,emitted=fixture(nil,nil,nil,{auto_aim=false},sensor)
enter(c,pressed)
check(sensor.cleared==1,'entry resets any previous surface cache')
pressed[87],pressed[1]=true,true
c:tick(0.02)
check(c.active and c.status=='controlling' and command()[4]==0 and not engine.surface_ready,
    'surface wait holds movement without exiting camera or blocking cancel/fire')
check(emitted[#emitted]==true and channel:float(memory[1284],4)==2,
    'fire remains available and camera does not drift while surface sensing waits')
sensor.ready=true
c:tick(0.02)
check(command()[4]==2 and c.session.velocity[2]==2 and engine.surface_ready,
    'surface sensing recovery applies the safe inertial command')
check(math.abs(engine.position[2]-5.04)<0.00001 and math.abs(channel:float(memory[1284],4)-2.04)<0.00001,
    'camera follows the corrected position, not the unfiltered proposed position')
c:stop('clearance_test')
check(sensor.cleared==2 and sensor.sample==nil and not c.active and memory[1000]==B.u32(190) and
    memory[1500]=='\1' and memory[1100]=='\4\0' and memory[2100]=='MOVE',
    'exit drops surface state and restores AI, camera and player controls')
for _,kind in ipairs({188,189,190,191}) do
    c,pressed,snapshot,engine,emitted=fixture()
    snapshot.behavior_kind,snapshot.drone_name=kind,'MAGAZINE DRONE'
    snapshot.feed,snapshot.ammo,snapshot.heat='magazine',2,nil
    memory[1000]=B.u32(kind)
    enter(c,pressed)
    check(c.active and memory[1000]==B.u32(0),'each verified drone behavior can be captured')
    pressed[1]=true;c:tick(0.02)
    check(emitted[#emitted]==true,'magazine drones use native weapon fire')
    memory[1000]=B.u32(kind);c:tick(0.02)
    check(memory[1000]==B.u32(0),'native fire reset uses this family original behavior')
    snapshot.ammo,snapshot.exhausted=0,true;c:tick(0.02)
    check(not c.active and c.status=='ammo_empty_return' and emitted[#emitted]==false,
        'empty magazine stops firing and releases remote control')
    check(memory[1000]==B.u32(kind) and memory[1500]=='\1' and memory[2100]=='MOVE' and memory[1100]=='\4\0',
        'empty return restores the actual original AI, camera and input')
end
c,pressed,snapshot,engine,emitted=fixture()
enter(c,pressed)
snapshot.unit_valid=function() return false end
check(not pcall(c.tick,c,0.02),'invalid ownership/solo roster stops before flight or fire')
c:stop('solo_required')
check(not c.active and memory[1000]==B.u32(190) and memory[1500]=='\1' and memory[2100]=='MOVE',
    'party join cleanup restores owned AI and input even when a new snapshot is refused')
local function seeker_fixture()
    local c,pressed,sample,engine,emitted,restored,reader = fixture()
    sample.kind,sample.drone_name,sample.behavior_kind = 'seeker','G-60 SEEKER',4
    sample.deployed,sample.docked = false,false
    sample.heat,sample.feed,sample.targeting = nil,nil,nil
    sample.ticket = {identity='held-original',actor_identity='local-owner',name='G-60 SEEKER'}
    memory[1000]=B.u32(4)
    sample.detonation_valid = function() return sample.deployed and not sample.detonating and sample.unit_valid() end
    local observer = {}
    function observer:capture() return not sample.deployed and sample.ticket or nil end
    function observer:snapshot(ticket)
        check(ticket==sample.ticket,'only the exact held throwable is tracked')
        assert(sample.unit_valid(),'solo_required')
        return sample
    end
    function reader:seeker_snapshot(ticket) return observer:snapshot(ticket) end
    local detonations = 0
    function channel:detonate(context)
        assert(context==sample and context.detonation_valid(),'detonation ownership')
        detonations=detonations+1
    end
    c.seeker=SeekerControl.new(observer,channel,SeekerHotkey,function() end)
    local function launch()
        c:tick(0.02)
        pressed[70]=true;c:tick(0.02)
        pressed[1]=true;c:tick(0.02)
        check(c.seeker_ticket and not c.active and not c.input_lease,'press reserves native throw, never takes over a held bomb')
        check(memory[1000]==B.u32(4) and memory[2100]=='MOVE' and #channel.commands==0,
            'held Q+attack never modifies AI, input or emits synthetic throw')
        pressed[1]=false;c:tick(0.02)
        check(not c.active,'release alone does not fake deployment')
        sample.deployed=true;c:tick(0.02)
        check(c.active and memory[1000]==B.u32(0) and memory[2100]==B.u32(0),'actual native detach starts control')
        check(detonations==0 and #emitted==0,'throw attack release is not detonation or native gun fire')
    end
    return c,pressed,sample,engine,launch,function() return detonations end
end
for _,button in ipairs({1,70}) do
    local c,pressed,sample,engine,launch,count=seeker_fixture()
    launch()
    sample.drone_position={0,1500,0}
    c:tick(0.02)
    check(c.active and engine.moved==1,'seekers have no 100m signal limit')
    pressed[70]=false;c:tick(0.02)
    pressed[button]=true;c:tick(0.02)
    check(not c.active and count()==1,'fresh attack or Q detonates exactly once')
    check(memory[1000]==B.u32(4) and memory[1100]=='\4\0' and memory[2100]=='MOVE',
        'detonation restores native behavior, actor camera and movement')
    check(#channel.commands==0,'detonation never sends backpack or throw input')
    c:tick(0.02)
    check(count()==1,'held detonation button cannot repeat')
end
local c,pressed,sample,engine,launch,count=seeker_fixture()
launch();c:tick(30.01)
check(not c.active and count()==1 and c.status=='seeker_time_expired','lifetime expires through original explosion path')
c,pressed,sample,engine,launch,count=seeker_fixture()
launch();sample.unit_valid=function() return false end
check(not pcall(c.tick,c,0.02),'party join refuses another control frame')
c:stop('party_join')
check(not c.active and count()==0 and memory[2100]=='MOVE' and memory[1100]=='\4\0',
    'party join returns inputs without detonating a now-multiplayer throwable')
c,pressed,sample,engine,launch,count=seeker_fixture()
launch();sample.detonating=true;c:tick(0.02)
check(not c.active and count()==0,'native explosion exits without repeated native invocation')
c,pressed,sample,engine,launch,count=seeker_fixture()
c:tick(0.02);pressed[70],pressed[1]=true,true;c:tick(0.02);c:tick(8.01)
check(not c.active and not c.seeker_ticket and count()==0 and memory[2100]=='MOVE',
    'uncompleted throw times out without stealing focus or exploding a held grenade')
return checks
