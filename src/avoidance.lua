local Avoidance = {clearance = 1, interval = 0.05, max_age = 0.1, reach = 4}
local function finite(n)
    return type(n) == 'number' and n == n and math.abs(n) < 100000
end
local function vector(v)
    assert(type(v) == 'table' and finite(v[1]) and finite(v[2]) and finite(v[3]), 'invalid_surface_vector')
end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function length(v) return math.sqrt(dot(v,v)) end
local function minus(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function Avoidance.directions(velocity)
    vector(velocity)
    local result = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
    local speed = length(velocity)
    if speed > 0.01 then
        local direction = {velocity[1]/speed,velocity[2]/speed,velocity[3]/speed}
        local duplicate = false
        for _, axis in ipairs(result) do if dot(axis,direction) > 0.995 then duplicate = true end end
        if not duplicate then result[#result+1] = direction end
    end
    return result
end
function Avoidance.step(position,velocity,contacts,dt,previous_velocity,clearance)
    clearance = clearance or Avoidance.clearance
    assert(finite(clearance) and clearance >= 0.25 and clearance <= 2, 'invalid_surface_clearance')
    vector(position); vector(velocity)
    if previous_velocity then vector(previous_velocity) end
    assert(finite(dt) and dt >= 0 and dt <= 0.1 and type(contacts) == 'table' and #contacts <= 7,
        'invalid_surface_step')
    local v, constraints = {velocity[1],velocity[2],velocity[3]},{}
    for _, hit in ipairs(contacts) do
        vector(hit.position); vector(hit.normal)
        local size = length(hit.normal)
        assert(size >= 0.9 and size <= 1.1, 'invalid_surface_normal')
        local n = {hit.normal[1]/size,hit.normal[2]/size,hit.normal[3]/size}
        local gap = dot(minus(position,hit.position),n)-clearance
        -- Approach speed fades before contact. An already-close surface requests
        -- a small outward velocity, never a teleport or a physical impulse.
        local bound
        if gap >= 0 then
            bound = -math.min(8,3*gap,math.sqrt(32*gap),dt > 0 and gap/dt or 8)
        else
            bound = math.min(2,-4*gap,math.max(0,dot(previous_velocity or velocity,n))+8*dt)
        end
        constraints[#constraints+1] = {normal = n,bound = bound}
    end
    local function project(retreat)
        for _ = 1,12 do
            local changed = false
            for _, limit in ipairs(constraints) do
                local bound = retreat and limit.bound or math.min(0,limit.bound)
                local delta = bound-dot(v,limit.normal)
                if delta > 0.000001 then
                    for axis = 1,3 do v[axis] = v[axis]+delta*limit.normal[axis] end
                    changed = true
                end
            end
            if not changed then return true end
        end
        for _, limit in ipairs(constraints) do
            if dot(v,limit.normal) < (retreat and limit.bound or math.min(0,limit.bound))-0.00001 then
                return false
            end
        end
        return true
    end
    -- Opposing surfaces in a narrow gap cannot both supply one metre of room.
    -- Drop outward pressure in that case, retaining safe tangential movement.
    if not project(true) then
        v = {velocity[1],velocity[2],velocity[3]}
        if not project(false) then v = {0,0,0} end
    end
    local speed = length(v)
    if speed > 8 then for i = 1,3 do v[i] = v[i]*8/speed end; speed = 8 end
    local command = {0,0,0,speed}
    if speed > 0.000001 then for i = 1,3 do command[i] = v[i]/speed end end
    local next_position = {}
    for i = 1,3 do next_position[i] = position[i]+v[i]*dt end
    return next_position,command,v
end
function Avoidance.new(query,report)
    local sensor = {}
    function sensor:clear()
        self.sample,self.token,self.last_reason,self.after,self.last_time = nil,nil,nil,nil,nil
    end
    function sensor:move(snapshot,position,velocity,dt,now,previous_velocity)
        vector(position); vector(velocity)
        assert(finite(now) and now >= 0, 'invalid_surface_time')
        if self.token ~= snapshot.token then self:clear(); self.token = snapshot.token end
        local sample = self.sample
        local speed = length(velocity)
        local direction = speed > 0.01 and {velocity[1]/speed,velocity[2]/speed,velocity[3]/speed} or nil
        local turn = direction and (not sample or not sample.direction or dot(direction,sample.direction) < 0.96)
        local changed = not sample or length(minus(position,sample.position)) > 0.65
        local due = not self.after or now < self.last_time or now >= self.after
        if due or sample and (turn or changed) then
            self.after,self.last_time = now+Avoidance.interval,now
            local ok,contacts,reason = pcall(query.scan,query,snapshot,position,
                Avoidance.directions(velocity),Avoidance.reach)
            if ok and contacts then
                self.sample = {contacts = contacts,time = now,position = {unpack(position)},direction = direction}
                sample = self.sample
                reason = 'ready'
            else
                reason = ok and reason or tostring(contacts)
                -- A failed query must not authorize motion using stale empty space.
                self.sample,sample = nil,nil
            end
            if reason ~= self.last_reason then
                self.last_reason = reason
                report('surface clearance: '..tostring(reason))
            end
        end
        if not sample or now < sample.time or now-sample.time > Avoidance.max_age then
            return {unpack(position)},{0,0,0,0},{0,0,0}
        end
        return Avoidance.step(position,velocity,sample.contacts,dt,previous_velocity,
            snapshot.kind == 'seeker' and 0.5 or Avoidance.clearance)
    end
    return sensor
end
return Avoidance
