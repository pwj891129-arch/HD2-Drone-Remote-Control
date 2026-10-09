local Avoidance,Flight = ...
local checks = 0
local function check(value,message) assert(value,message); checks = checks+1 end
local function near(a,b) return math.abs(a-b) < 0.00001 end
local wall = {{position = {5,0,0},normal = {-1,0,0}}}
local p,command,v = Avoidance.step({0,0,0},{8,0,0},wall,0.05)
check(near(p[1],0.4) and near(command[4],8),'far from walls, speed is unchanged')
p,command,v = Avoidance.step({3.5,0,0},{8,3,0},wall,0.05)
check(near(v[1],1.5) and near(v[2],3),'approach fades while tangential velocity remains')
p,command,v = Avoidance.step({4,0,0},{8,3,0},wall,0.05)
check(near(v[1],0) and near(v[2],3) and near(p[1],4),'one metre clearance is held')
p,command,v = Avoidance.step({4.6,0,0},{8,0,0},wall,0.05)
check(near(v[1],-0.4) and near(p[1],4.58),'too-close position retreats gently without teleporting')
p,command,v = Avoidance.step({4.6,0,0},{-2,0,0},wall,0.05)
check(near(v[1],-2),'existing outward motion is not stopped')
p,command,v = Avoidance.step({4.6,0,0},{0.8,0,0},wall,0.05,{-0.4,0,0})
check(near(v[1],-0.8),'outward acceleration accumulates even while pressing toward a wall')
local ground = {{position = {0,0,0},normal = {0,0,1}}}
p,command,v = Avoidance.step({0,0,1},{2,3,-8},ground,0.05)
check(near(v[3],0) and near(v[1],2) and near(v[2],3),'ground blocks descent only')
local ceiling = {{position = {0,0,5},normal = {0,0,-1}}}
p,command,v = Avoidance.step({0,0,4},{2,3,8},ceiling,0.05)
check(near(v[3],0) and near(v[1],2),'ceiling blocks ascent only')
local corner = {wall[1],{position = {0,5,0},normal = {0,-1,0}},ground[1]}
p,command,v = Avoidance.step({4,4,1},{4,4,-4},corner,0.1)
check(near(command[4],0),'a three-surface corner cannot be crossed')
local small = {{position = {-0.5,0,0},normal = {1,0,0}},
    {position = {0.5,0,0},normal = {-1,0,0}}}
p,command,v = Avoidance.step({0,0,0},{3,2,0},small,0.05)
check(near(v[1],0) and near(v[2],2),'narrow spaces do not alternate outward pushes')
local n = math.sqrt(0.5)
local slope = {{position = {0,0,0},normal = {-n,0,n}}}
p,command,v = Avoidance.step({0,0,math.sqrt(2)},{4,2,-4},slope,0.05)
check(near(-n*v[1]+n*v[3],0) and near(v[2],2),'sloped surfaces preserve tangent motion')
p,command,v = Avoidance.step({0,0,0},{1,2,3},{},0)
check(near(p[1],0) and near(p[2],0) and near(p[3],0),'zero frame time never translates')
for _,dt in ipairs({1/30,1/60,1/144,0.1}) do
    local position,velocity = {0,0,0},{0,0,0}
    for _ = 1,math.ceil(4/dt) do
        local _,_,_,_,_,_,_,wanted = Flight.step(position,0,0,
            {right = 1,left = 0,forward = 0,back = 0,up = 0,down = 0},dt,velocity)
        position,command,velocity = Avoidance.step(position,wanted,wall,dt)
        check(position[1] <= 4.000001,'held movement never crosses clearance at different frame rates')
    end
    check(position[1] > 3.99,'smooth deceleration converges to one metre clearance')
end
for _,value in ipairs({{0,0,0},{2,0,0},{0/0,0,1}}) do
    check(not pcall(Avoidance.step,{0,0,0},{0,0,0},{{position={0,0,0},normal=value}},0.05),
        'unusable surface normals are rejected')
end
check(not pcall(Avoidance.step,{0/0,0,0},{0,0,0},{},0.05),'nonfinite position rejected')
check(not pcall(Avoidance.step,{0,0,0},{math.huge,0,0},{},0.05),'nonfinite velocity rejected')
check(not pcall(Avoidance.step,{0,0,0},{0,0,0},{},0.2),'long frame gap rejected')
check(#Avoidance.directions({0,0,0}) == 6,'six directions cover walls, floor and ceiling')
check(#Avoidance.directions({8,0,0}) == 6,'cardinal movement casts are not duplicated')
check(#Avoidance.directions({4,4,0}) == 7,'diagonal movement adds a forward probe')
local calls,fail,contacts,events = 0,false,{},{}
local query = {}
function query:scan(_,_,directions,reach)
    calls = calls+1
    check(#directions <= 7 and reach == 4,'bounded sensing budget')
    if fail then return nil,'query_jobs_busy' end
    return contacts
end
local sensor = Avoidance.new(query,function(s) events[#events+1] = s end)
local snapshot = {token = 'owned-rover'}
p,command,v = sensor:move(snapshot,{0,0,0},{1,0,0},0.02,1)
check(calls == 1 and near(v[1],1),'first scan authorizes free movement')
p,command,v = sensor:move(snapshot,{0.02,0,0},{1,0,0},0.02,1.01)
check(calls == 1,'same-direction samples are reused for fifty milliseconds')
sensor:move(snapshot,{0,0,0},{0,1,0},0.02,1.02)
check(calls == 2,'sharp movement direction changes refresh sensing immediately')
sensor:move(snapshot,{1,0,0},{0,1,0},0.02,1.03)
check(calls == 3,'external movement invalidates distant surface samples')
fail = true
p,command,v = sensor:move(snapshot,{1,0,0},{0,1,0},0.02,1.1)
check(command[4] == 0 and near(p[1],1),'busy query pauses flight, not the control session')
sensor:move(snapshot,{1,0,0},{0,1,0},0.02,1.11)
check(calls == 4,'failed queries are rate-limited too')
fail = false
sensor:move(snapshot,{1,0,0},{0,1,0},0.02,1.2)
check(calls == 5 and #events == 3,'query recovery resumes movement and reports once')
contacts = wall
sensor:move({token = 'new-rover'},{4,0,0},{1,0,0},0.02,1.21)
check(calls == 6,'owner changes discard cached empty space')
p,command,v = sensor:move({token = 'new-rover'},{4,0,0},{1,0,0},0.02,0.5)
check(calls == 7 and command[4] == 0,'clock reset requires a fresh query')
sensor:clear()
check(sensor.sample == nil and sensor.token == nil and sensor.after == nil,'cleanup drops all query state')
query.scan = function() error('world disappeared') end
p,command,v = sensor:move(snapshot,{1,2,3},{8,0,0},0.05,2)
check(command[4] == 0 and near(p[2],2),'query exceptions never authorize movement')
local _,_,seeker_velocity=Avoidance.step({0,0,0.6},{0,0,-1},
    {{position={0,0,0},normal={0,0,1}}},0.05,{0,0,-1},0.5)
check(seeker_velocity[3]<0 and seeker_velocity[3]>=-0.31,'Seeker fades approach at its own half-metre clearance')
local _,_,normal_velocity=Avoidance.step({0,0,0.6},{0,0,-1},
    {{position={0,0,0},normal={0,0,1}}},0.05,{0,0,-1})
check(normal_velocity[3]>0,'Seeker clearance does not mutate the backpack clearance')
check(not pcall(Avoidance.step,{0,0,1},{0,0,0},{},0.05,nil,0),'invalid clearance is refused')
check(Avoidance.body_clearance == 0.01,'one centimetre body clearance is independent of probe size')
local body = {{position={0,0,0},normal={0,0,1},character_body=true}}
for _,terrain_margin in ipairs({0.5,1}) do
    p,command,v = Avoidance.step({0,0,0.01},{1,2,-4},body,0.05,nil,terrain_margin)
    check(near(v[3],0) and near(v[1],1) and near(v[2],2),'body holds one centimetre for either drone type')
    p,command,v = Avoidance.step({0,0,0.02},{0,0,-1},body,0.05,nil,terrain_margin)
    check(v[3] < 0,'body permits approach well inside the terrain margin')
    p,command,v = Avoidance.step({0,0,0.005},{0,0,-1},body,0.05,nil,terrain_margin)
    check(v[3] > 0 and v[3] < 0.03,'gentle outward correction starts only inside one centimetre')
    local leg_gap = {{position={-0.1,0,0},normal={1,0,0},character_body=true},
        {position={0.1,0,0},normal={-1,0,0},character_body=true}}
    p,command,v = Avoidance.step({0,0,0},{0,4,0},leg_gap,0.05,nil,terrain_margin)
    check(near(v[1],0) and near(v[2],4),'leg gaps preserve forward flight with no lateral shove')
    for _,dt in ipairs({1/30,1/60,1/144,0.1}) do
        local position,velocity={0,0,1},{0,0,0}
        for _=1,math.ceil(4/dt) do
            local _,_,_,_,_,_,_,wanted=Flight.step(position,0,0,
                {right=0,left=0,forward=0,back=0,up=0,down=1},dt,velocity)
            position,command,velocity=Avoidance.step(position,wanted,body,dt,velocity,terrain_margin)
            check(position[3] >= 0.009999,'held descent never crosses the body margin')
        end
        check(position[3] < 0.01002,'approach converges to the one-centimetre body margin')
    end
end
local mixed={body[1],{position={0,0,0},normal={0,0,1},character_body=false}}
p,command,v=Avoidance.step({0,0,0.5},{0,0,-1},mixed,0.05,nil,0.5)
check(near(v[3],0),'a coincident wall still retains its half-metre margin')
p,command,v=Avoidance.step({0,0,1},{0,0,-1},mixed,0.05)
check(near(v[3],0),'backpack terrain clearance remains one metre')
for _,body_hit in ipairs({false,true}) do
    local exit={{position={0.2,0,0},normal={1,0,0},character_body=body_hit,recovered=true}}
    local position,velocity={0,0,0},{0,0,0}
    for _=1,300 do
        position,command,velocity=Avoidance.step(position,{0,1,0},exit,0.02,velocity,0.5)
        check(velocity[1]>=0 and near(velocity[2],1),'initial escape is smooth and retains tangential input')
    end
    check(position[1]>0.2+(body_hit and 0.009 or 0.49),'initial terrain/body penetration reaches exit margin')
end
return checks
