local Aim = {}
local function unit(v)
    local length = 0
    for i=1,3 do
        local n = v[i]
        assert(type(n) == 'number' and n == n and math.abs(n) < 1000000, 'aim_vector_invalid')
        length = length+n*n
    end
    length = math.sqrt(length)
    assert(length > 0.00001, 'aim_direction_invalid')
    return {v[1]/length,v[2]/length,v[3]/length},length
end
function Aim.follow(current, desired, dt)
    assert(type(dt) == 'number' and dt == dt and dt >= 0 and dt <= 0.1, 'aim_frame_gap')
    current,desired = unit(current),unit(desired)
    local dot = math.max(-1,math.min(1,current[1]*desired[1]+current[2]*desired[2]+current[3]*desired[3]))
    local angle = math.acos(dot)
    local step = math.min(angle,math.pi*dt)
    if angle < 0.00001 or step == angle then return desired end
    if step == 0 then return current end
    local tangent
    if dot < -0.99999 then
        local axis = math.abs(current[3]) < 0.9 and {current[2],-current[1],0} or {1,0,0}
        local projection = current[1]*axis[1]+current[2]*axis[2]+current[3]*axis[3]
        tangent = unit({axis[1]-projection*current[1],axis[2]-projection*current[2],axis[3]-projection*current[3]})
    else
        tangent = unit({desired[1]-dot*current[1],desired[2]-dot*current[2],desired[3]-dot*current[3]})
    end
    local c,s = math.cos(step),math.sin(step)
    return unit({c*current[1]+s*tangent[1],c*current[2]+s*tangent[2],c*current[3]+s*tangent[3]})
end
function Aim.turn(current, desired, dt)
    local delta = (desired-current+math.pi)%(2*math.pi)-math.pi
    local limit = math.pi*dt
    return current+math.max(-limit,math.min(limit,delta))
end
function Aim.new(channel, B, Lease)
    local self = {}
    function self:rebind(snapshot)
        if not self.lease then return end
        assert(self.ownership_key and snapshot.ownership_key == self.ownership_key, 'aim_owner_changed')
        local targeting = assert(snapshot.targeting, 'targeting_unavailable')
        assert(targeting.valid(), 'targeting_changed')
        for _, pair in ipairs({{self.mode,targeting.flags},{self.point,targeting.position}}) do
            if pair[1] then pcall(self.lease.rebind,self.lease,pair[1],pair[2],targeting.valid) end
        end
    end
    function self:clear()
        if self.lease then
            assert(self.lease:release(), 'aim_restore_pending')
            self.lease,self.context,self.point,self.mode,self.ownership_key = nil,nil,nil,nil,nil
        end
        self.direction,self.yaw = nil,nil
    end
    function self:tick(snapshot, camera, forward, automatic, dt)
        assert(type(automatic) == 'boolean', 'aim_option_invalid')
        local targeting = assert(snapshot.targeting, 'targeting_unavailable')
        assert(targeting.valid(), 'targeting_changed')
        if automatic then self:clear(); return end
        local point, norm = {},0
        for i=1,3 do
            local p,d = camera[i],forward[i]
            assert(type(p) == 'number' and p == p and math.abs(p) < 1000000 and
                type(d) == 'number' and d == d and math.abs(d) <= 1.001, 'aim_vector_invalid')
            point[i] = p+d*100
            norm = norm+d*d
        end
        assert(math.abs(norm-1) < 0.001, 'aim_direction_not_unit')
        local motor = snapshot.aim_motor
        assert(motor or snapshot.aim_motor_reason == 'lookat_component_absent', 'aim_motor_unavailable')
        assert(not motor or motor.valid(), 'aim_motor_changed')
        local origin = assert(snapshot.weapon_position, 'aim_origin_unavailable')
        local desired,range = unit({point[1]-origin[1],point[2]-origin[2],point[3]-origin[3]})
        local direction = Aim.follow(self.direction or assert(snapshot.weapon_forward, 'aim_orientation_unavailable'),
            desired,dt)
        for i=1,3 do point[i] = origin[i]+direction[i]*range end
        local raw = channel:floats(point)
        if not self.lease then
            assert(channel:read(targeting.flags,4) == B.u32(0), 'targeting_mode_not_ready')
            self.lease,self.context = Lease.new(channel),targeting
            self.ownership_key = snapshot.ownership_key
            -- Nonzero flags skip target acquisition; bit 2 uses the explicit world point.
            self.mode = self.lease:claim(targeting.flags,B.u32(0),B.u32(2),targeting.valid)
            self.point = self.lease:claim(targeting.position,assert(channel:read(targeting.position,12)),
                raw,targeting.valid)
        else
            assert(self.context.flags == targeting.flags and self.context.position == targeting.position and
                self.context.valid() and channel:read(targeting.flags,4) == B.u32(2), 'aim_capture_changed')
            self.lease:set(self.point,raw)
        end
        assert(self.context.valid() and channel:read(targeting.flags,4) == B.u32(2) and
            (not motor or motor.valid()),
            'aim_capture_changed')
        -- These are native producer outputs, not configuration leases. Refresh all
        -- consumers even without fire; native targeting owns them again on release.
        if motor then
            for _, output in ipairs({{motor.position,raw},{motor.engaged,'\1'},{motor.fire_position,raw}}) do
                assert(motor.valid() and channel:write(output[1],output[2]) and
                    channel:read(output[1],#output[2]) == output[2], 'aim_motor_write_failed')
            end
        end
        assert((not motor or motor.valid()) and targeting.valid(), 'aim_motor_changed')
        self.direction = direction
        if not self.yaw then
            self.yaw = math.atan2(-snapshot.weapon_forward[1],snapshot.weapon_forward[2])
        end
        if direction[1]^2+direction[2]^2 > 0.000001 then
            self.yaw = Aim.turn(self.yaw,math.atan2(-direction[1],direction[2]),dt)
        end
        local yaw = (self.yaw or 0)/2
        return {point = point,direction = direction,body_rotation = {0,0,math.sin(yaw),math.cos(yaw)}}
    end
    return self
end
return Aim
