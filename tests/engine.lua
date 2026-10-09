local Engine, Flight = ...
local checks = 0
local function check(value,message) assert(value,message);checks=checks+1 end
local V = setmetatable({x=function(v)return v.x end,y=function(v)return v.y end,z=function(v)return v.z end},
    {__call=function(_,x,y,z)return{x=x,y=y,z=z or 0}end})
local drone = {ref=0x400002,resource='cb8d6dbe2ad74be4',position=V(0,5,2),local_position=V(0,5,2),alive=true}
local gun = {ref=0x400003,resource='5beec97f4c7f4ae9',position=V(0,5,2),local_position=V(0,0,0),alive=true}
local world, ui = {},{}
local texts,destroyed,updates = {},0,0
local mouse,cursor,root_node = true,true,0
local rotations,transform_writes,position_writes = 0,0,0
local Q = setmetatable({from_elements=function(...)
    assert(select('#',...)==4,'Quaternion.from_elements takes four scalars')
    local q = {kind='quaternion',...}
    for i=1,4 do assert(type(q[i])=='number' and q[i]==q[i],'invalid quaternion scalar') end
    rotations=rotations+1
    return q
end}, {__call=function(_,axis,angle)
    assert(type(axis)=='table' and axis.x and type(angle)=='number',
        'Quaternion(...) takes Vector3 axis and numeric angle, not four scalars')
    error('component rotation must not use the axis-angle constructor')
end})
local s = {Vector3=V,Vector2=V,Quaternion=Q,Color=function(...)return{...}end}
s.Application={main_world=function()return world end,worlds=function()return{world,ui}end,
    can_get=function()return true end}
s.World={update_unit=function(target,u)
        assert(target==world and (u==drone or u==gun),'world update requires the owned unit')
        updates=updates+1
    end,
    create_screen_gui=function(target)assert(target==ui);return 7 end,
    destroy_gui=function(target,gui)assert(target==ui and gui==7);destroyed=destroyed+1 end}
s.IdString64={from_hex=function(hex)return{hex=hex}end}
local units_for_resource = function(target,id)
    assert(target==world and type(id)=='table','typed resource query')
    if id.hex==drone.resource then return {[0]=drone} end
    if id.hex==gun.resource then return {[9]=gun} end
    return {}
end
s.World.units_by_resource=units_for_resource
s.Unit={alive=function(u)return u.alive end,world=function()return world end,
    resource_name=function()error('opaque resource names must not be string compared')end,
    world_position=function(u,node)assert(node==root_node,'wrong root node');return u.position end,
    local_position=function(u,node)assert(node==root_node,'wrong root node');return u.local_position end,
    set_local_position=function(u,node,p)
        position_writes=position_writes+1
        error('movement must use owned Mover input, not scene-root translation')
    end,
    set_local_rotation=function()error('use the immediate rotation notification path')end,
    teleport_local_rotation=function(u,node,q)
        assert(node==root_node and q.kind=='quaternion','rotation requires a typed quaternion')
        transform_writes=transform_writes+1;u.rotation=q
    end}
-- HD2 exposes the mouse focus/cursor APIs, not the required keyboard-focus pair.
s.Window={mouse_focus=function()return mouse end,set_mouse_focus=function(v)mouse=v end,
    show_cursor=function()return cursor end,set_show_cursor=function(v)cursor=v end}
s.Gui={resolution=function()return 2560,1440 end,
    text_extents=function(_,str,font,size)return V(0,0),V(#str*size/2,24)end,
    text=function(_,str,font,size,material,pos,color)
        assert(pos.z==12 or pos.z==13,'HUD text requires a layered Vector3')
        texts[#texts+1]={str=str,pos=pos,color=color};return #texts
    end,destroy_text=function()end}
local foreground=true
local channel={unit_ref=function(_,unit)return unit.ref end,foreground=function()return foreground end}
local reports={}
local function make()return Engine.new(s,Flight,function(message)reports[#reports+1]=message end,channel)end
local sample = {drone_position={0,5,2},weapon_position={0,5,2},actor_position={0,0,0},drone_goid=525,gun_goid=524,
    drone_unit=drone.ref,gun_unit=gun.ref,token='owned',node_index=0,heat=0.25,reserve=3,
    drone_engine_resource=drone.resource,gun_engine_resource=gun.resource,
    actor_unit=0x400001,pack_unit=0x400004,pack_parent_unit=0x400001,gun_parent_unit=drone.ref,
    graph_valid=function()return true end,unit_valid=function()return true end,
    movement={valid=function()return true end}}
local engine=make()
engine:prepare(sample)
check(updates==0 and cursor and mouse,'preflight never changes input or transforms')
check(s.Window.keyboard_focus==nil and s.Window.set_keyboard_focus==nil,
    'realistic missing keyboard focus API does not refuse entry')
check(engine.drone==drone and engine.gun==gun,'exact UnitRefs resolve sparse resource lists')
check(not pcall(Q,0,0,0,1),'native axis-angle signature reproduces the rejected old call')
local from_elements=Q.from_elements
Q.from_elements=nil
check(not pcall(engine.prepare,make(),sample),'missing from_elements refuses entry before input takeover')
check(updates==0 and transform_writes==0 and mouse and cursor,'API failure has no transform or input side effects')
Q.from_elements=from_elements
local immediate_rotation=s.Unit.teleport_local_rotation
s.Unit.teleport_local_rotation=nil
check(not pcall(engine.prepare,make(),sample),'missing immediate rotation API refuses before capture')
check(updates==0 and transform_writes==0 and mouse and cursor,'rotation API failure has no side effects')
s.Unit.teleport_local_rotation=immediate_rotation
sample.drone_engine_resource=nil
check(not pcall(engine.prepare,make(),sample),'missing native resource is never replaced by authored resource')
sample.drone_engine_resource=gun.resource
check(not pcall(engine.prepare,make(),sample),'authored drone resource returns gun and cannot select it as drone')
sample.drone_engine_resource=drone.resource
engine:capture_input();check(not cursor and not mouse,'mouse capture hides cursor; keyboard uses binding lease')
engine:move(sample,{0,5.4,2},{0,0,0,1},{0,1,0})
check(drone.position.y==5 and position_writes==0 and updates==2,
    'orientation updates body and gun without fighting the native movement position')
check(rotations==1 and drone.rotation.kind=='quaternion' and drone.rotation[4]==1,
    'identity rotation uses typed from_elements rather than Quaternion(...)')
local before_reports=#reports
local next_position,_,_,_,rotation,forward=Flight.step({0,5.4,2},0.7,-0.3,
    {left=0,right=1,forward=1,back=0,up=0,down=0,dx=8,dy=-5},0.05)
engine:move(sample,next_position,rotation,forward)
for i=1,4 do check(drone.rotation[i]==rotation[i],'nontrivial flight rotation preserves component order') end
check(#reports==before_reports,'first-move stage logs do not repeat every frame')
local manual_writes=transform_writes
engine:move(sample,next_position,rotation,forward,true)
check(transform_writes==manual_writes,'automatic mode does not fight native target orientation')
engine:move(sample,next_position,rotation,forward,false)
check(transform_writes==manual_writes+1,'manual mode updates body orientation without firing')
local before_rotations,before_writes,before_updates=rotations,transform_writes,updates
for _,invalid in ipairs({{0,0,0},{0/0,0,0,1},{math.huge,0,0,1},{0,0,0,0},{0,0,0,0.5},{'0',0,0,1}}) do
    check(not pcall(engine.move,engine,sample,{0,6,2},invalid,{}),'invalid quaternion refused before native calls')
end
for _,invalid in ipairs({{0,6},{0/0,6,2},{0,math.huge,2},{'0',6,2}}) do
    check(not pcall(engine.move,engine,sample,invalid,{0,0,0,1},{}),'invalid position refused before native calls')
end
check(rotations==before_rotations and transform_writes==before_writes and updates==before_updates,
    'invalid flight data cannot partially mutate transforms')
Q.from_elements=function()error('mock native constructor failure')end
check(not pcall(engine.move,engine,sample,{0,6,2},{0,0,0,1},{}),'constructor failure is propagated')
check(transform_writes==before_writes and updates==before_updates,'construct rotation before any transform write')
Q.from_elements=from_elements
engine:hud(sample,81)
check(#texts==2 and math.abs(texts[2].pos.y-1008)<1e-8 and texts[2].pos.x>0,'HUD at seventy percent of screen height')
check(math.abs(texts[1].pos.y-1007)<1e-8,'shadow follows lowered HUD')
check(texts[2].color[3]==165,'orange distance warning')
check(texts[2].str:find('81.0m') and texts[2].str:find('HEAT 0.25') and texts[2].str:find('HEATSINKS 3'),
    'actual heat and reserve labels')
check(texts[2].str:find('AIM MANUAL'),'manual mode visible in HUD')
before_reports=#reports
engine:hud(sample,81,true)
check(#reports==before_reports,'first-HUD stage logs do not repeat every frame')
check(texts[#texts].str:find('AIM AUTO'),'automatic mode visible in HUD')
sample.feed,sample.drone_name,sample.ammo,sample.heat='magazine','GUARD DOG',17,nil
engine:hud(sample,10,false)
check(texts[#texts].str:find('GUARD DOG') and texts[#texts].str:find('AMMO 17') and
    texts[#texts].str:find('MAGAZINES 3') and not texts[#texts].str:find('HEAT'),
    'magazine drone HUD uses actual rounds/reserve without laser assumptions')
engine:clear();check(cursor and mouse and destroyed==1,'input and GUI restored')
engine:clear();check(destroyed==1,'cleanup idempotent')

-- Position drift does not change identity; a co-located other Rover is never selected.
drone.position=V(0.224,5,2);drone.local_position=drone.position
local other={ref=0x400020,position=V(0,5,2),local_position=V(0,5,2),alive=true}
s.World.units_by_resource=function(target,id)
    if id.hex==drone.resource then return {[1]=other,[8]=drone,[9]=drone} end
    return units_for_resource(target,id)
end
engine=make();engine:prepare(sample)
check(engine.drone==drone,'22cm stale snapshot drift cannot select a co-located foreign drone')
local matched_report=false
for i=math.max(1,#reports-4),#reports do
    if reports[i]:find('matched=true',1,true) then matched_report=true end
end
check(matched_report,'exact reference match is diagnosed')
sample.drone_unit=0x800002
check(not pcall(engine.prepare,engine,sample),'same registry index with another generation is refused')
check(not pcall(engine.move,engine,sample,{0,6,2},{0,0,0,1},{}),'changed identity cannot move cached handles')
sample.drone_unit=drone.ref
engine:clear()
s.World.units_by_resource=function(target,id)
    if id.hex==drone.resource then return {other} end
    return units_for_resource(target,id)
end
engine=make()
check(not pcall(engine.prepare,engine,sample),'nearby foreign Rover is not a fallback')
s.World.units_by_resource=units_for_resource
engine=make();sample.unit_valid=function()return false end
check(not pcall(engine.prepare,engine,sample),'invalid ownership prevents engine queries')
sample.unit_valid=function()return true end

drone.position=V(0,0,0.8);drone.local_position=V(0,0,0)
sample.drone_parent_unit=sample.pack_unit
local observed=engine:observe(sample)
check(observed.docked and not observed.airborne and not observed.free,'docked root and owner proximity agree')
check(not pcall(engine.prepare,engine,sample),'docked root is never controlled')
check(not pcall(engine.move,engine,sample,{0,6,2},{0,0,0,1},{}),'docked root cannot be teleported')
drone.position=V(0,0,0.8);drone.local_position=drone.position
sample.drone_parent_unit=nil
observed=engine:observe(sample)
check(not observed.docked and not observed.airborne and observed.free,'nearby free drone is not mistaken for docked')
drone.position=V(0,5,2);drone.local_position=V(0,0,0)
sample.drone_parent_unit=other.ref
observed=engine:observe(sample)
check(not observed.docked and not observed.airborne and not observed.free,'foreign parent is not an owned dock')
drone.position=V(0,0,1.548)
sample.drone_parent_unit=sample.pack_unit
observed=engine:observe(sample)
check(observed.docked and not observed.airborne,'actual 1.548m stowed distance does not block native pack parent')
sample.graph_valid=function()return false end
check(not pcall(engine.observe,engine,sample),'changed graph cannot authorize control')
sample.graph_valid=function()return true end
sample.pack_parent_unit=other.ref
check(not pcall(engine.observe,engine,sample),'pack attached to another owner cannot authorize docking')
sample.pack_parent_unit=sample.actor_unit
sample.gun_parent_unit=other.ref
check(not pcall(engine.observe,engine,sample),'laser parent must be owned Rover')
sample.gun_parent_unit=sample.drone_unit
sample.drone_parent_unit=nil
drone.position=V(0,5,2)
drone.local_position=drone.position
engine:prepare(sample)
drone.alive=false
check(not pcall(engine.move,engine,sample,{0,6,2},{0,0,0,1},{}),'dead handle not moved')
drone.alive=true
local old_world=world;world={}
check(not pcall(engine.move,engine,sample,{0,6,2},{0,0,0,1},{}),'another world cannot use cached handles')
world=old_world;engine:clear()

local session,sync={},{}
s.Network={game_session=function()return session end}
s.GameSession={unit_synchronizer=function(value)assert(value==session);return sync end}
s.UnitSynchronizer={game_object_id_to_unit=function(value,id)
    assert(value==sync);return id==525 and drone or id==524 and gun or nil end,
    unit_to_game_object_id=function(value,unit)assert(value==sync);return unit==drone and 525 or 524 end}
s.World.units_by_resource=function()error('exact GOID resolution must not scan')end
engine=make();engine:prepare(sample)
check(engine.drone==drone and engine.gun==gun,'network IDs are cross-checked against exact UnitRefs')
local original_id=s.UnitSynchronizer.unit_to_game_object_id
s.UnitSynchronizer.unit_to_game_object_id=function()return 999 end
check(not pcall(engine.prepare,make(),sample),'reverse GOID mismatch refused')
s.UnitSynchronizer.unit_to_game_object_id=original_id
local original_sync=s.UnitSynchronizer.game_object_id_to_unit
s.UnitSynchronizer.game_object_id_to_unit=function()return other end
check(not pcall(engine.prepare,make(),sample),'wrong GOID UnitRef refused without coordinate fallback')
s.UnitSynchronizer.game_object_id_to_unit=original_sync
drone.position=V(0/0,5,2)
check(not pcall(engine.prepare,make(),sample),'invalid owned GOID position refused')
drone.position=V(0,5,2);drone.local_position=drone.position
s.GameSession.unit_synchronizer=function()return nil end
s.World.units_by_resource=units_for_resource
sample.node_index,root_node=1,1
engine=make();engine:prepare(sample)
check(engine.node==1,'one-based engine root index used')
before_reports=#reports
engine:move(sample,{0,6,2},{0,0,0,1},{})
check(drone.position.y==5 and position_writes==0,'one-based root index used for orientation without teleporting')
check(#reports>before_reports and reports[#reports]=='engine: first move: complete',
    'new control entry logs its first move again')
local normal_resolution=s.Gui.resolution
for _,size in ipairs({{1920,1080},{1280,720},{3840,2160}}) do
    s.Gui.resolution=function()return size[1],size[2] end
    engine:hud(sample,80)
    check(math.abs(texts[#texts].pos.y-size[2]*0.7)<1e-8,'HUD relative height survives resolution changes')
    check(texts[#texts].pos.y>size[2]*0.5 and texts[#texts].pos.y<size[2],
        'HUD remains between crosshair and top')
end
s.Gui.resolution=normal_resolution
sample.node_index=0
local old_updates=updates
check(not pcall(engine.move,engine,sample,{0,7,2},{0,0,0,1},{}),'changed root index blocks movement')
check(updates==old_updates,'changed root index never writes transforms')
sample.node_index=nil
check(not pcall(engine.prepare,make(),sample),'missing root index is never guessed')
sample.node_index,root_node=0,0

local ffi=require('ffi')
drone.position={x=ffi.new('float',0),y=ffi.new('float',5),z=ffi.new('float',2)}
drone.local_position=drone.position
V.to_elements=function(value)return value.x,value.y,value.z end
V.x=function()error('prefer single engine vector unpack')end
V.y,V.z=V.x,V.x
engine=make();engine:prepare(sample)
check(engine.drone==drone,'native numeric scalars and Vector3.to_elements normalize')
drone.position=V(0,5,2);drone.local_position=drone.position
local ids=s.IdString64;s.IdString64=nil
check(not pcall(engine.prepare,make(),sample),'missing resource API never constructs a Unit handle')
s.IdString64=ids
engine:clear();check(engine.node==nil and engine.token==nil,'cleanup forgets node and identity cache')
local old_mouse_focus=s.Window.set_mouse_focus
s.Window.set_mouse_focus=nil
check(not pcall(engine.prepare,make(),sample),'missing mouse focus API still refuses input takeover')
s.Window.set_mouse_focus=old_mouse_focus
engine=make();engine:capture_input()
cursor=true
engine:clear()
check(mouse and cursor,'external cursor change is preserved while owned focus is restored')
local original_set=s.Window.set_show_cursor
s.Window.set_show_cursor=function()error('cursor capture failed')end
engine=make()
check(not pcall(engine.capture_input,engine) and not mouse,'partial mouse capture records restoration state')
s.Window.set_show_cursor=original_set
engine:clear()
check(mouse and cursor,'partial mouse capture is rolled back')
engine=make();engine:capture_input();foreground=false
check(not pcall(engine.clear,engine) and engine.focus and not mouse and not cursor,
    'alt-tab cannot recapture mouse in another application')
foreground=true;engine:clear()
check(not engine.focus and mouse and cursor,'pending mouse restoration retries on foreground return')
sample.kind,sample.drone_name,sample.remaining='seeker','G-60 SEEKER',21.5
sample.gun_unit,sample.gun_goid,sample.gun_engine_resource=sample.drone_unit,sample.drone_goid,sample.drone_engine_resource
sample.pack_unit,sample.pack_parent_unit,sample.gun_parent_unit=nil,nil,nil
sample.drone_parent_unit=nil
local hidden,exploded=0,false
sample.explosion_valid=function()return exploded and sample.unit_valid()end
s.Unit.set_unit_visibility=function(unit,visible)
    check(unit==drone and visible==false and exploded,'hide only the exact exploded Seeker meshes')
    hidden=hidden+1
end
engine=make();engine:prepare(sample)
check(engine.drone==engine.gun,'Seeker camera resolves the bomb itself, never a fabricated weapon')
local previous_updates=updates
engine:move(sample,{0,5,2},{0,0,0,1},{0,1,0},false)
check(updates==previous_updates+1,'single-unit Seeker pose is published only once')
engine:hud(sample,1500,false,true)
check(texts[#texts].str:find('TIME 21.5s') and texts[#texts].str:find('1500.0m') and
    not texts[#texts].str:find('/ 100m') and not texts[#texts].str:find('HEAT'),
    'Seeker HUD shows lifetime and distance without a signal-range or heat fiction')
check(not engine:seeker_explosion(sample) and hidden==0,'live Seeker is never hidden before detonation')
exploded=true
check(engine:seeker_explosion(sample) and hidden==1,'exploded mesh is hidden without deleting the native unit')
local saved_ref=drone.ref
drone.ref=0x400020
check(not pcall(engine.seeker_explosion,engine,sample) and hidden==1,'reused/foreign engine handle is never hidden')
drone.ref=saved_ref
sample.unit_valid=function()return false end
check(not engine:seeker_explosion(sample) and hidden==1,'destroyed generation needs no visibility call')
sample.unit_valid=function()return true end
s.Unit.set_unit_visibility=nil
check(not pcall(engine.prepare,make(),sample),'missing visibility API refuses before Seeker input takeover')
engine:clear()
return checks
