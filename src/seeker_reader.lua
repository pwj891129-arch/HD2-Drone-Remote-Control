local SeekerReader = {}
SeekerReader.resources = {
    ['2d398d1ec35e0838'] = 'G-50 SEEKER',
    ['8e325c933e55bf62'] = 'G-60 ANTI-TANK SEEKER',
}
function SeekerReader.new(r, channel, B)
    local self = {}
    local function actor()
        local players, authored = r:root(0x3326468),r:root(0x346BF98)
        assert(r:word(players+132) == 1 and r:word(players+136) == 1, 'solo_required')
        local goid = r:word(players+936)
        local dense = r:map(authored+15871688,goid)
        assert(dense < 100000 and goid > 0 and goid < 32767, 'actor_bounds')
        local at = authored+15937304+dense*24
        local identity = r:raw(at,24)
        local entity,unit = B.word(identity,8),B.word(identity,12)
        assert(entity > 0 and entity < 0xFFFFFF00 and B.word(identity,16) == goid, 'actor_identity')
        local _,unit_valid = r:unit_object(unit)
        local function valid()
            return unit_valid() and r:root(0x3326468) == players and r:root(0x346BF98) == authored and
                r:word(players+132) == 1 and r:word(players+136) == 1 and
                r:word(players+936) == goid and r:raw(at,24) == identity
        end
        assert(valid(), 'actor_changed')
        return {entity = entity,unit = unit,identity = identity,valid = valid}
    end
    function self:capture()
        local a = actor()
        local inventory = r:component(0x3326738,40,64,20,a.entity,80,48,512)
        if r:word(inventory.address+28) ~= 4 then return nil end
        local wield = r:component(0x3326420,48,72,24,a.entity,96,0x1D0,512)
        assert(wield.unit == a.unit and wield.descriptor == a.identity, 'held_owner_changed')
        local entity = r:word(wield.address)
        if entity == 0 or entity >= 0xFFFFFF00 then return nil end
        local ok,brain = pcall(r.component,r,0x3326740,64,88,44,entity,96,0x1F8,4096)
        if not ok then assert(brain == 'component_absent',brain); return nil end
        local resource = B.hex(brain.descriptor:sub(1,8):reverse())
        if not SeekerReader.resources[resource] then return nil end
        local parent,parent_valid = r:parent_unit(brain.unit)
        assert(parent == a.unit and parent_valid() and r:word(brain.address) == 4 and
            inventory.valid() and wield.valid() and brain.valid() and a.valid() and
            r:word(inventory.address+28) == 4 and r:word(wield.address) == entity, 'held_seeker_changed')
        return {entity = entity,unit = brain.unit,identity = brain.descriptor,
            actor_identity = a.identity,resource = resource,name = SeekerReader.resources[resource]}
    end
    function self:snapshot(ticket)
        assert(type(ticket) == 'table' and SeekerReader.resources[ticket.resource], 'seeker_ticket_required')
        local a = actor()
        assert(a.identity == ticket.actor_identity, 'seeker_actor_changed')
        local brain = r:component(0x3326740,64,88,44,ticket.entity,96,0x1F8,4096)
        assert(brain.descriptor == ticket.identity and brain.unit == ticket.unit, 'seeker_identity_changed')
        local boids = r:component(0x3326460,48,72,24,ticket.entity,80,0x534,256)
        local mover = r:component(0x3326558,0x48A0,0x48B8,0x4888,ticket.entity,0x48C0,0x1C,4096)
        local explosive = r:component(0x3326728,56,80,44,ticket.entity,96,64,4096)
        for _,component in ipairs({boids,mover,explosive}) do
            assert(component.descriptor == ticket.identity and component.unit == ticket.unit,
                'seeker_component_identity')
        end
        assert(boids.dense < r:word(boids.root+32) and mover.dense < r:word(mover.root+0x4890) and
            explosive.dense < r:word(explosive.root+40), 'seeker_not_local')
        local metadata = r:ptr(boids.root+96)
        local motion = {address = metadata+boids.dense*56+32}
        motion.enabled = r:raw(motion.address,1)
        assert(motion.enabled == '\0' or motion.enabled == '\1', 'seeker_motion_invalid')
        function motion.valid()
            return boids.valid() and boids.dense < r:word(boids.root+32) and r:ptr(boids.root+96) == metadata
        end
        local movement = {address = mover.address,original = r:raw(mover.address,16)}
        function movement.valid() return mover.valid() and mover.dense < r:word(mover.root+0x4890) end
        local resource,resource_valid = r:engine_resource(ticket.unit)
        local parent,parent_valid = r:parent_unit(ticket.unit)
        assert(parent == nil or parent == a.unit, 'seeker_foreign_parent')
        local camera = r:root(0x346D560)
        local first,next_row = r:word(camera+0x1F8),r:word(camera+0x1FC)
        assert(first < 32 and next_row < 32 and first ~= next_row, 'camera_queue')
        local row = camera+0x200+((next_row+31)%32)*0xE8
        local camera_identity = r:raw(row+4,12)
        assert(B.word(camera_identity,0) == a.entity and B.word(camera_identity,4) == a.unit, 'camera_not_player')
        local result = {kind = 'seeker',ticket = ticket,actor_unit = a.unit,actor_position = r:position(a.unit),
            drone_unit = ticket.unit,drone_entity = ticket.entity,drone_goid = brain.goid,
            drone_position = r:position(ticket.unit),drone_parent_unit = parent,drone_engine_resource = resource,
            gun_unit = ticket.unit,gun_goid = brain.goid,gun_engine_resource = resource,
            node_index = r:node_index(),brain = brain,motion = motion,movement = movement,
            camera = camera,camera_row = row,drone_name = ticket.name,behavior_kind = 4,
            explosive = explosive,detonation_manager = explosive.root,
            ownership_key = ticket.actor_identity..ticket.identity..resource,
            deployed = parent == nil and r:word(brain.address+8) == 3,
            detonating = r:raw(explosive.address+36,1) ~= '\0'}
        result.token = result.ownership_key..tostring(brain.address)
        function result.unit_valid()
            local ok,valid = pcall(function()
                return a.valid() and brain.valid() and motion.valid() and movement.valid() and
                    explosive.valid() and explosive.dense < r:word(explosive.root+40) and resource_valid()
            end)
            return ok and valid
        end
        function result.graph_valid() return parent_valid() end
        function result.camera_valid()
            return r:root(0x346D560) == camera and r:raw(row+4,12) == camera_identity
        end
        function result.detonation_valid()
            return result.unit_valid() and result.graph_valid() and parent == nil and
                r:raw(explosive.address+36,1) == '\0'
        end
        result.fire_valid = result.unit_valid
        assert(result.unit_valid() and result.graph_valid() and result.camera_valid(), 'seeker_snapshot_changed')
        return result
    end
    return self
end
return SeekerReader
