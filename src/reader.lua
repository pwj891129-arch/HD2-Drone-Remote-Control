local Reader = {arc_display_interval = 0.1}
Reader.body_guards = {
    {0x4BE6E0,'488b05b1d8fa028bd5448b80e8aef200'},
    {0x4BE704,'4c8b90e0aef200448b98ecaef200'},
    {0x4BE73A,'8b5004'},
}
Reader.arc_guards = {
    {0x80C0CB,'4c8b153eabb102'},
    {0x80C126,'498b5a708bc8498b4278488d3c89'},
    {0x80C155,'f30f5e4004f30f1144fb0c'},
    {0x80C521,'f30f1044c10cf30f5844c108f30f1144c108'},
    {0x80E0C8,'f3410f1044ee080f57f60f2fc6764cf30f5cc7'},
    {0x80E126,'f3410f1144ee08'},
    {0x80E14E,'410f2f74ee08720f'},
}
-- Authored backpack -> deployed body -> mounted weapon, pinned to the retained build.
Reader.families = {
    ['af9b683ccb6ddc02'] = {name = 'ROVER', body = '5beec97f4c7f4ae9',
        weapon = '2c66c201b2543d2c', feed = 'heat', behavior = 190},
    ['255ebc5767d7ceec'] = {name = 'GUARD DOG', body = 'a0ff2f9a0ca6992a',
        weapon = 'a32621e3bde13379', feed = 'magazine', behavior = 191},
    ['3015626aa69f8d4d'] = {name = 'HOT DOG', body = '979e9bc6d48d1fc6',
        weapon = '65cd4325ba23f3c6', feed = 'magazine', behavior = 188},
    ['c28da712b12e3dfa'] = {name = 'K-9', body = '4b071633584e4594',
        weapon = 'a0532c3616528cbf', feed = 'magazine', behavior = 190},
    ['bffcb4cd971a8eda'] = {name = 'DOG BREATH', body = 'b9baf571fc8f9959',
        weapon = 'b729a2ba153bcaed', feed = 'magazine', behavior = 189},
}
function Reader.new(channel, B, Flight, options, body_resources, BodyParts)
    local r = {channel = channel, options = options or {},unit_cache = {},unit_cache_order = {}}
    local part_reader = BodyParts and BodyParts.new(r,B)
    function r:raw(at, size) return assert(channel:read(at,size), 'unreadable') end
    function r:ptr(at) return B.ptr(self:raw(at,8)) end
    function r:word(at) return B.word(self:raw(at,4),0) end
    function r:root(rva) return self:ptr(channel.base+rva) end
    function r:party_allowed(players)
        local counts = self:raw(players+132,8)
        local total,local_count = B.word(counts,0),B.word(counts,4)
        -- The first local peer (+936) must remain unique even with remote peers.
        return local_count == 1 and total >= 1 and total <= 4 and
            (total == 1 or self.options.allow_multiplayer == true)
    end
    function r:map_header(h, entity)
        local rows, count, empty, multiplier = B.ptr(h), B.word(h,8), B.word(h,12), B.word(h,16)
        if not (count >= 1 and count <= 1048576 and entity ~= empty) then
            error(string.format('map_invalid: capacity=%d key=%d empty=%d',count,entity,empty),0)
        end
        local power = count
        while power > 1 and power % 2 == 0 do power = power/2 end
        assert(power == 1, 'map_invalid')
        local seed = B.mul(entity, multiplier)
        for i = 0, math.min(count,128)-1 do
            local raw = self:raw(rows + ((seed+i)%count)*8,8)
            if B.word(raw,0) == entity then return B.word(raw,4) end
            if B.word(raw,0) == empty then break end
        end
        error('component_absent',0)
    end
    function r:map(at, entity) return self:map_header(self:raw(at,20),entity) end
    function r:component(rva, map, back, count_at, entity, rows_at, stride, limit)
        local root = self:root(rva)
        -- These fields belong to one small manager header; re-read it on every
        -- validation rather than crossing the native reader for each field.
        local first = math.min(map,back,count_at,rows_at)
        local size = math.max(map+20,back+8,count_at+4,rows_at+8)-first
        assert(size <= 128,'component_header_bounds')
        local function header() return self:raw(root+first,size) end
        local function pointer(h,at) return B.ptr(h:sub(at-first+1,at-first+8)) end
        local function index(h) return r:map_header(h:sub(map-first+1,map-first+20),entity) end
        local h = header()
        local count, dense = B.word(h,count_at-first),index(h)
        assert(dense < count and count <= limit, 'component_bounds')
        local owners, rows = pointer(h,back),pointer(h,rows_at)
        local descriptor_at = self:ptr(owners+dense*8)
        local descriptor = self:raw(descriptor_at,24)
        assert(B.word(descriptor,8) == entity and B.word(descriptor,16) > 0 and
            B.word(descriptor,16) < 32767, 'component_identity')
        local result = {root = root, dense = dense, descriptor = descriptor,
            descriptor_at = descriptor_at, address = rows+dense*stride,
            unit = B.word(descriptor,12), entity = entity, goid = B.word(descriptor,16)}
        function result.valid()
            local ok, valid = pcall(function()
                if r:root(rva) ~= root then return false end
                local current = header()
                local count = B.word(current,count_at-first)
                return count > dense and count <= limit and index(current) == dense and
                    pointer(current,back) == owners and pointer(current,rows_at) == rows and
                    r:ptr(owners+dense*8) == descriptor_at and
                    r:raw(descriptor_at,24) == descriptor
            end)
            return ok and valid
        end
        return result
    end
    function r:arc_readiness(gun)
        if not self.arc_verified then
            for _,guard in ipairs(Reader.arc_guards) do
                local bytes = B.unhex(guard[2])
                assert(self:raw(channel.base+guard[1],#bytes) == bytes,'arc_code_changed')
            end
            self.arc_verified = true
        end
        local arc = self:component(0x3326C10,0x48,0x60,0x38,gun.entity,0x70,40,512)
        assert(arc.descriptor == gun.descriptor and arc.unit == gun.unit,'arc_owner_changed')
        local raw = self:raw(arc.address,16)
        -- Arc update subtracts frame delta from +8; a shot adds the instance
        -- fire interval at +12. These are remaining seconds, not game timestamps.
        local remaining,interval = channel:float(raw,8),channel:float(raw,12)
        assert(interval == interval and interval >= 0.01 and interval <= 120 and
            remaining == remaining and remaining >= -0.5 and remaining <= interval+0.5,
            'arc_timer_invalid')
        assert(arc.valid() and gun.valid(),'arc_owner_changed')
        remaining = math.max(0,remaining)
        return {percent = math.max(0,math.min(100,(1-remaining/interval)*100)),
            remaining = remaining,interval = interval,ready = remaining <= 0}
    end
    function r:arc_display(gun)
        local now = channel.now and channel:now()
        if type(now) ~= 'number' or now ~= now or now < 0 or now == math.huge then now = nil end
        local cached = self.arc_display_cache
        if now and cached and now >= cached.at and now-cached.at < Reader.arc_display_interval and
            cached.descriptor == gun.descriptor and cached.unit == gun.unit and cached.entity == gun.entity then
            return cached.value,cached.reason
        end
        local available,value = pcall(self.arc_readiness,self,gun)
        local result,reason
        if available then result = value else reason = tostring(value) end
        -- Display-only sample. Ammo, ownership, firing and movement stay live.
        self.arc_display_cache = now and {at = now,descriptor = gun.descriptor,unit = gun.unit,
            entity = gun.entity,value = result,reason = reason} or nil
        return result,reason
    end
    function r:unit_object(unit)
        local cached = self.unit_cache[unit]
        -- Only addresses/validators are reused. The current registry, generation,
        -- object identity and accessor are checked again before every use.
        if cached and cached.valid() then return cached.object,cached.valid end
        local registry = self:ptr(channel.exe_base+0x1A100F0)
        local h = self:raw(registry+0x88,32)
        local rows, count, gens = B.ptr(h), B.word(h,16), B.ptr(h:sub(25,32))
        local index, generation = unit%0x400000, math.floor(unit/0x400000)
        assert(index < count and count <= 0x400000 and generation <= 255 and
            self:raw(gens+index,1) == string.char(generation), 'unit_generation')
        local object = self:ptr(rows+index*8)
        assert(self:word(object+8) == unit, 'unit_reference_mismatch')
        local vtable = self:ptr(object)
        local method = self:ptr(vtable+0xE8)
        assert(method == channel.exe_base+0x2BD870 or method == channel.exe_base+0x2BD880, 'unit_accessor')
        local function valid()
            local ok, same = pcall(function()
                if self:ptr(channel.exe_base+0x1A100F0) ~= registry then return false end
                local current = self:raw(registry+0x88,32)
                local current_rows, capacity, current_gens = B.ptr(current),B.word(current,16),B.ptr(current:sub(25,32))
                -- Unrelated units may grow the registry; only this slot's identity is leased.
                return index < capacity and capacity <= 0x400000 and
                    self:raw(current_gens+index,1) == string.char(generation) and
                    self:ptr(current_rows+index*8) == object and self:word(object+8) == unit and
                    self:ptr(object) == vtable and self:ptr(vtable+0xE8) == method and
                    self:raw(registry+0x88,32) == current
            end)
            return ok and same
        end
        assert(valid(), 'unit_changed')
        if not cached then
            if #self.unit_cache_order >= 64 then
                self.unit_cache[table.remove(self.unit_cache_order,1)] = nil
            end
            self.unit_cache_order[#self.unit_cache_order+1] = unit
        end
        self.unit_cache[unit] = {object = object,valid = valid}
        return object, valid
    end
    function r:collision_unit_live(unit)
        -- Static/world hits may not carry a UnitRef. Only proven retired generations
        -- are discarded; unreadable registries remain a query failure.
        if unit <= 0 or unit >= 1073741824 or unit % 1 ~= 0 then return nil end
        local registry = self:ptr(channel.exe_base+0x1A100F0)
        local header = self:raw(registry+0x88,32)
        local rows,count,gens = B.ptr(header),B.word(header,16),B.ptr(header:sub(25,32))
        assert(count <= 0x400000,'collision_registry_bounds')
        local index,generation = unit%0x400000,math.floor(unit/0x400000)
        local live,gen,slot = false,nil,nil
        if index < count then
            gen = self:raw(gens+index,1)
            if gen == string.char(generation) then
                slot = self:raw(rows+index*8,8)
                if slot ~= string.rep('\0',8) then live = self:word(B.ptr(slot)+8) == unit end
            end
        end
        assert(self:ptr(channel.exe_base+0x1A100F0) == registry and
            self:raw(registry+0x88,32) == header and
            (not gen or self:raw(gens+index,1) == gen) and
            (not slot or self:raw(rows+index*8,8) == slot),'collision_registry_changed')
        return live
    end
    function r:character_body(unit,snapshot)
        if type(unit) ~= 'number' or unit <= 0 or unit >= 1073741824 or unit % 1 ~= 0 then return false end
        if unit == snapshot.actor_unit then return true end
        -- Original UnitRef -> entity map. Its value is an entity, not a dense index.
        for _,guard in ipairs(Reader.body_guards) do
            assert(self:raw(channel.base+guard[1],#guard[2]/2) == B.unhex(guard[2]), 'body_lookup_code_changed')
        end
        local authored = self:root(0x346BF98)
        local ok,entity = pcall(self.map,self,authored+0xF2AEE0,unit)
        if not ok then assert(entity == 'component_absent',entity); return false end
        local index = self:map(authored+0xF1AEB0,entity)
        assert(index < 100000,'body_descriptor_bounds')
        local at = authored+0xF32F18+index*24
        local identity = self:raw(at,24)
        assert(B.word(identity,8) == entity and B.word(identity,12) == unit, 'body_descriptor_changed')
        local resource = B.hex(identity:sub(1,8):reverse())
        local body = body_resources and body_resources[resource] == true
        if not body then
            local avatars = self:root(0x3326D20)
            local present,dense = pcall(self.map,self,avatars+248,entity)
            if present then
                local count = self:word(avatars+108)
                assert(dense < count and count <= 32 and
                    self:word(avatars+0x53D8B0+dense*0x1238+0xBD4) == entity, 'body_avatar_changed')
                body = true
            else assert(dense == 'component_absent',dense) end
        end
        local function body_valid()
            -- Collision classification needs identity, not the drone transform
            -- accessor. Props and body sub-units may have another accessor.
            return r:collision_unit_live(unit) == true and r:root(0x346BF98) == authored and
                r:raw(at,24) == identity and
                r:map(authored+0xF2AEE0,unit) == entity and r:map(authored+0xF1AEB0,entity) == index
        end
        assert(body_valid(),'body_identity_changed')
        return body == true,{identity = identity,authored = authored,valid = body_valid}
    end
    function r:body_part(meta,unit,actor)
        assert(part_reader,'body_part_reader_unavailable')
        return part_reader:matches(meta,unit,actor)
    end
    function r:position(unit)
        local object, valid = self:unit_object(unit)
        local matrices = self:ptr(object+0x88)
        local xyz = channel:vector(self:raw(matrices+48,12),0)
        assert(valid() and self:ptr(object+0x88) == matrices, 'unit_changed')
        return xyz
    end
    function r:forward(unit)
        local object, valid = self:unit_object(unit)
        local matrices = self:ptr(object+0x88)
        local xyz = channel:vector(self:raw(matrices+16,12),0)
        local length = math.sqrt(xyz[1]^2+xyz[2]^2+xyz[3]^2)
        assert(length > 0.00001 and length < 100 and valid() and
            self:ptr(object+0x88) == matrices, 'unit_orientation_changed')
        for i=1,3 do xyz[i] = xyz[i]/length end
        return xyz
    end
    function r:engine_resource(unit)
        -- Unit.resource_name reads the native resource, not the authored component descriptor.
        assert(self:raw(channel.exe_base+0x40BD85,7) == B.unhex('488b5830488b1b'),
            'unit_resource_code_changed')
        local object, unit_valid = self:unit_object(unit)
        local at = self:ptr(object+0x30)
        local raw = self:raw(at,8)
        assert(raw ~= string.rep('\0',8), 'unit_resource_unavailable')
        local function valid()
            return unit_valid() and self:ptr(object+0x30) == at and self:raw(at,8) == raw
        end
        assert(valid(), 'unit_resource_changed')
        return B.hex(raw:reverse()), valid
    end
    function r:parent_unit(unit)
        assert(self:raw(channel.exe_base+0x2BD9E0,8) == B.unhex('488b81d0010000c3'),
            'unit_parent_code_changed')
        local object, unit_valid = self:unit_object(unit)
        local vtable = self:ptr(object)
        assert(self:ptr(vtable+0x1E0) == channel.exe_base+0x2BD9E0, 'unit_parent_accessor')
        local raw = self:raw(object+0x1D0,8)
        local reference, parent_valid
        if raw ~= string.rep('\0',8) then
            local parent = B.ptr(raw)
            reference = self:word(parent+8)
            local registered
            registered, parent_valid = self:unit_object(reference)
            assert(registered == parent, 'unit_parent_reference_mismatch')
        end
        local function valid()
            return unit_valid() and self:ptr(vtable+0x1E0) == channel.exe_base+0x2BD9E0 and
                self:raw(object+0x1D0,8) == raw and (not parent_valid or parent_valid())
        end
        assert(valid(), 'unit_parent_changed')
        return reference, valid
    end
    function r:node_index()
        -- Unit.world_position subtracts the runtime Lua index offset from its node argument.
        assert(self:raw(channel.exe_base+0x407851,6) == B.unhex('2b1d450a5001'), 'node_index_code_changed')
        local index = self:word(channel.exe_base+0x190829C)
        assert(index == 0 or index == 1, 'node_index_invalid')
        return index
    end
    function r:rotation_controls(snapshot)
        local guards = {
            {0x620C20,'498b4568f6041001740e498b4d600fb64410044288440108'},
            {0x620C7C,'4d8b65604869f198020000'},
            {0x620CE4,'43807cb408000f10b2d00200008b9ae8020000f2440f1092e00200000f11b530030000'},
            {0x5A29E2,'488b46684c69c208030000f3450f109400dc020000'},
        }
        for _, guard in ipairs(guards) do
            local bytes = B.unhex(guard[2])
            assert(self:raw(channel.base+guard[1],#bytes) == bytes, 'rotation_code_changed')
        end
        assert(snapshot.unit_valid(), 'rotation_owner_changed')
        local body_object, body_unit_valid = self:unit_object(snapshot.drone_unit)
        local resource, resource_valid = self:engine_resource(snapshot.drone_unit)
        local function rotator(entity, unit, identity, unit_valid, optional)
            local found, component = pcall(r.component,r,0x33264A0,0x38,0x50,0x2C,
                entity,0x58,0x298,4096)
            if not found then
                assert(optional and component == 'component_absent', component)
                return nil
            end
            assert(component.unit == unit and component.descriptor == identity, 'rotator_owner_changed')
            local replicas, overrides = r:ptr(component.root+0x60),r:ptr(component.root+0x68)
            local result = {enabled = replicas+component.dense*12+8,
                override = overrides+component.dense*8+4}
            -- The update copies override+4 into replica+8 before testing rotation enable.
            for _, address in ipairs({result.enabled,result.override}) do
                local flag = r:raw(address,1)
                assert(flag == '\0' or flag == '\1', 'rotator_flag_invalid')
            end
            function result.valid()
                local ok, valid = pcall(function()
                    return component.valid() and r:ptr(component.root+0x60) == replicas and
                        r:ptr(component.root+0x68) == overrides and unit_valid()
                end)
                return ok and valid
            end
            assert(result.valid(), 'rotator_changed')
            return result
        end
        local identity = snapshot.brain.descriptor
        local key = identity..resource..tostring(body_object)
        local function resolve()
            assert(body_unit_valid() and resource_valid(), 'rotation_owner_changed')
            local spatial = r:component(0x3326508,0x40,0x58,0x2C,
                snapshot.drone_entity,0x68,0x308,100000)
            assert(spatial.unit == snapshot.drone_unit and spatial.descriptor == identity,
                'body_pose_owner_changed')
            local rotation = spatial.address+0x2D0
            local raw, norm = r:raw(rotation,16),0
            for i=0,3 do norm = norm+channel:float(raw,i*4)^2 end
            assert(math.abs(norm-1) < 0.001, 'body_pose_rotation_invalid')
            local controls = {key = key,resolve = resolve,
                body = rotator(snapshot.drone_entity,snapshot.drone_unit,identity,body_unit_valid,true),
                rotation = rotation, valid = function()
                    return spatial.valid() and body_unit_valid() and resource_valid()
                end}
            assert(controls.valid(), 'rotation_owner_changed')
            return controls
        end
        return resolve()
    end
    function r:bindings()
        local now = channel.now and channel:now()
        if now and self.binding_cache and now >= self.binding_time and
            now-self.binding_time < 0.25 and self.binding_cache.valid() then
            return self.binding_cache
        end
        local owner = self:root(0x347CF18)
        local buckets = self:ptr(owner+686800)
        assert(self:word(owner+686808) == 256, 'binding_layout')
        local raw = self:raw(buckets,256*328)
        local wanted = {[0x2001A]='aim_mode', [0x20025]='backpack', [0x20011]='up',
            [0x2000C]='down', [0x20009]='fire', [0x20000]='left', [0x20001]='right',
            [0x20002]='forward', [0x20003]='back', [0x20015]='quick_throw'}
        local keys, token, pack_entries, input_entries, records = {}, {tostring(owner),tostring(buckets)}, {}, {}, {}
        local function owner_valid()
            return r:root(0x347CF18) == owner and r:ptr(owner+686800) == buckets and
                r:word(owner+686808) == 256
        end
        for i = 0,255 do
            local at = i*328; local code = B.word(raw,at); local name = wanted[code]
            local player_action = code >= 0x20000 and code <= 0x20028 or code >= 0x50000 and code <= 0x50004
            if name or player_action then
                if name then assert(not keys[name], 'binding_duplicate') end
                local count = B.word(raw,at+4)
                assert(count <= 16 and (not name or name == 'quick_throw' or count > 0), 'binding_count')
                local record = {at = buckets+at, raw = raw:sub(at+1,at+8+count*20), pack = name == 'backpack'}
                records[#records+1] = record
                if not record.pack and count > 0 then
                    local function valid_count()
                        local current = r:raw(record.at,#record.raw)
                        return owner_valid() and current:sub(1,4) == record.raw:sub(1,4) and
                            (current:sub(5,8) == record.raw:sub(5,8) or current:sub(5,8) == B.u32(0)) and
                            current:sub(9) == record.raw:sub(9)
                    end
                    -- A zero flags word is still a device binding. Zero count means unbound.
                    input_entries[#input_entries+1] = {record.at+4,B.u32(count),valid_count}
                end
                local selected
                for j = 0,count-1 do
                    local start = at+8+j*20; local flags = B.word(raw,start)
                    local address, payload = buckets+start,raw:sub(start+5,start+20)
                    local function valid()
                        -- Validate this entry's identity independently so another changed binding cannot strand it.
                        return owner_valid() and r:raw(record.at,8) == record.raw:sub(1,8) and
                            r:raw(address+4,16) == payload
                    end
                    if record.pack then pack_entries[#pack_entries+1] = {address,raw:sub(start+1,start+4),valid} end
                    if name and math.floor(flags/16)%16 == 4 and math.floor(flags/256)%256 == 255 then
                        local kind, index, vk = flags%16, math.floor(flags/1048576)
                        if kind == 3 and index > 6 and index <= 254 then vk = index end
                        if kind == 4 and B.word(raw,start+4) == 32+index then vk = channel.mouse_keys[index] end
                        if vk and not selected then selected = vk end
                    end
                end
                if name then
                    assert(selected or name == 'quick_throw', 'binding_unsupported_'..name)
                    keys[name] = selected
                end
                token[#token+1] = tostring(code)..':'..record.raw
            end
        end
        for _, name in pairs(wanted) do
            if name ~= 'quick_throw' then assert(keys[name], 'binding_missing_'..name) end
        end
        function keys.valid()
            local ok, result = pcall(function()
                if not owner_valid() then return false end
                for _, record in ipairs(records) do
                    local current = r:raw(record.at,#record.raw)
                    if not record.pack then
                        if keys.inputs_suppressed then
                            if current:sub(1,4) ~= record.raw:sub(1,4) or
                                (current:sub(5,8) ~= record.raw:sub(5,8) and current:sub(5,8) ~= B.u32(0)) or
                                current:sub(9) ~= record.raw:sub(9) then return false end
                        elseif current ~= record.raw then return false end
                    else
                        if current:sub(1,8) ~= record.raw:sub(1,8) then return false end
                        for j = 8,#record.raw-1,20 do
                            local flags = current:sub(j+1,j+4)
                            if flags ~= B.u32(0) and flags ~= record.raw:sub(j+1,j+4) then return false end
                            if current:sub(j+5,j+20) ~= record.raw:sub(j+5,j+20) then return false end
                        end
                    end
                end
                return true
            end)
            return ok and result
        end
        keys.binding_token, keys.pack_entries, keys.input_entries = table.concat(token,':'), pack_entries,input_entries
        self.binding_cache,self.binding_time = keys,now
        return keys
    end
    function r:snapshot()
        self.stage = 'local_actor'
        local players, authored, avatars = self:root(0x3326468), self:root(0x346BF98), self:root(0x3326D20)
        assert(self:party_allowed(players), 'solo_required')
        local actor_goid = self:word(players+936)
        local index = self:map(authored+15871688, actor_goid)
        assert(index < 100000, 'actor_bounds')
        local actor_at = authored+15937304+index*24
        local identity = self:raw(actor_at,24); local entity, unit = B.word(identity,8), B.word(identity,12)
        assert(entity > 0 and entity < 0xFFFFFF00 and B.word(identity,16) == actor_goid and
            B.word(identity,16) > 0 and B.word(identity,16) < 32767, 'actor_unavailable')
        self.stage = 'avatar'
        local dense, count = self:map(avatars+248,entity), self:word(avatars+108)
        assert(dense < count and count <= 32 and self:word(avatars+0x53D8B0+dense*0x1238+0xBD4) == entity,
            'avatar_identity')
        local menu_flags = self:word(avatars+0x53E888+dense*0x1238)
        self.stage = 'inventory'
        local inventory = self:component(0x3326738,40,64,20,entity,80,48,512)
        local pack_entity = self:word(inventory.address+12)
        self.stage = 'backpack'
        local pack = self:component(0x33265E8,32,56,12,pack_entity,80,8,512)
        local family = assert(Reader.families[B.hex(pack.descriptor:sub(1,8):reverse())],
            'guard_dog_required')
        self.stage = 'backpack_attachment'
        local attachment = self:component(0x3326DC0,32,56,12,pack_entity,64,48,512)
        assert(self:word(attachment.address+4) == entity, 'pack_not_worn')
        local drone_goid = self:word(pack.address+4)
        local mounts = self:root(0x3326438)
        local mount_count = self:word(mounts+16); assert(mount_count <= 128, 'mount_bounds')
        local backrefs = self:ptr(mounts+56); local drone_entity
        for i = 0,mount_count-1 do
            local descriptor = self:raw(self:ptr(backrefs+i*8),24)
            if B.word(descriptor,16) == drone_goid then
                assert(not drone_entity, 'drone_ambiguous'); drone_entity = B.word(descriptor,8)
            end
        end
        assert(drone_entity, 'drone_absent')
        self.stage = 'drone'
        local drone = self:component(0x3326438,32,56,16,drone_entity,72,24,128)
        assert(B.hex(drone.descriptor:sub(1,8):reverse()) == family.body, 'drone_resource')
        local gun_entity = self:word(drone.address)
        self.stage = 'weapon_feed/'..family.feed
        local feed
        if family.feed == 'heat' then
            feed = self:component(0x3326D48,40,64,20,gun_entity,88,12,512)
        else
            feed = self:component(0x3326648,32,56,12,gun_entity,80,12,512)
        end
        assert(B.hex(feed.descriptor:sub(1,8):reverse()) == family.weapon, 'drone_weapon_resource')
        local feed_raw = self:raw(feed.address,12)
        local reserve, heat_value, overheated, ammo = B.word(feed_raw,0),nil,false,nil
        local magazine_ammo,chamber_ammo
        local chambers
        if family.feed == 'heat' then
            heat_value = channel:float(feed_raw,4)
            assert(heat_value >= 0 and (feed_raw:byte(9) == 0 or feed_raw:byte(9) == 1), 'heat_state_invalid')
            overheated = feed_raw:byte(9) == 1
        else
            ammo = B.word(feed_raw,4)
            assert(ammo <= 100000, 'ammo_bounds')
            chambers = self:ptr(feed.root+72)
            local chamber = self:word(chambers+feed.dense*16+8)
            assert(chamber <= 100000, 'chamber_bounds')
            magazine_ammo,chamber_ammo = ammo,chamber
            -- Keep the final chambered round usable when the magazine reads zero.
            if ammo == 0 and chamber > 0 then ammo = 1 end
        end
        assert(reserve <= 100000, 'reserve_bounds')
        local function feed_valid()
            return feed.valid() and (not chambers or r:ptr(feed.root+72) == chambers)
        end
        self.stage = 'drone_ai'
        local brain = self:component(0x3326740,64,88,44,drone_entity,96,0x1F8,4096)
        self.stage = 'drone_owner'
        local boids = self:component(0x3326460,48,72,24,drone_entity,80,0x534,256)
        assert(boids.dense < self:word(boids.root+32), 'drone_not_owned')
        local metadata = self:ptr(boids.root+0x60)
        local motion = {address = metadata+boids.dense*0x38+0x20}
        motion.enabled = self:raw(motion.address,1)
        assert(motion.enabled == '\0' or motion.enabled == '\1', 'drone_motion_flag_invalid')
        function motion.valid()
            local ok, valid = pcall(function()
                return boids.valid() and boids.dense < r:word(boids.root+32) and
                    r:ptr(boids.root+0x60) == metadata
            end)
            return ok and valid
        end
        self.stage = 'drone_mover'
        local mover = self:component(0x3326558,0x48A0,0x48B8,0x4888,
            drone_entity,0x48C0,0x1C,4096)
        assert(mover.unit == drone.unit and mover.descriptor == drone.descriptor and
            mover.dense < self:word(mover.root+0x4890), 'drone_mover_not_owned')
        local movement = {address = mover.address, original = self:raw(mover.address,16)}
        function movement.valid()
            local ok, valid = pcall(function()
                return mover.valid() and mover.dense < r:word(mover.root+0x4890)
            end)
            return ok and valid
        end
        self.stage = 'targeting'
        local aim = self:component(0x3326D30,0x150,0x168,0x13C,
            drone_entity,0x170,0x50,4096)
        assert(aim.descriptor == drone.descriptor and aim.unit == drone.unit and
            aim.dense < self:word(aim.root+0x144), 'targeting_not_owned')
        local simulations, replicas = self:ptr(aim.root+0x178),self:ptr(aim.root+0x180)
        local targeting = {flags = replicas+aim.dense*24+16,
            position = simulations+aim.dense*0xD0+8}
        function targeting.valid()
            local ok, valid = pcall(function()
                return aim.valid() and aim.dense < r:word(aim.root+0x144) and
                    r:ptr(aim.root+0x178) == simulations and r:ptr(aim.root+0x180) == replicas
            end)
            return ok and valid
        end
        self.stage = 'firing'
        local fire = self:component(0x3326420,48,72,24,drone_entity,96,0x1D0,512)
        self.stage = 'aim_motor'
        local found, look = pcall(self.component,self,0x33266B8,0x30,0x48,0x1C,
            drone_entity,0x50,0x1C,4096)
        -- Some drone bodies have no LookAt component. Absence disables only the
        -- optional model-output path; malformed maps and foreign owners still refuse.
        assert(found or look == 'component_absent', look)
        local aim_motor
        if found then
            assert(look.descriptor == drone.descriptor and look.unit == drone.unit and
                look.dense < self:word(look.root+0x20) and
                fire.dense < self:word(fire.root+0x20), 'aim_motor_not_owned')
            local firing_inputs = self:ptr(fire.root+0x50)
            aim_motor = {position = look.address,engaged = look.address+0x18,
                fire_position = firing_inputs+fire.dense*0x3C}
            function aim_motor.valid()
                local ok, valid = pcall(function()
                    return look.valid() and fire.valid() and look.dense < r:word(look.root+0x20) and
                        fire.dense < r:word(fire.root+0x20) and r:ptr(fire.root+0x50) == firing_inputs
                end)
                return ok and valid
            end
        end
        self.stage = 'weapon'
        local gun = self:component(0x3326CE0,48,72,24,gun_entity,88,0x3F0,4096)
        local arc,arc_reason
        if family.name == 'K-9' then
            arc,arc_reason = self:arc_display(gun)
        end
        local invalid = self:word(channel.base+0x3483C20)
        assert(self:word(fire.address) == gun_entity and
            (self:word(fire.address+4) == invalid or self:word(fire.address+4) == gun_entity), 'fire_slot_alias')
        self.stage = 'camera'
        local camera = self:root(0x346D560)
        local first, next_index = self:word(camera+0x1F8), self:word(camera+0x1FC)
        assert(first < 32 and next_index < 32 and first ~= next_index, 'camera_queue')
        local row = camera+0x200+((next_index+31)%32)*0xE8
        local camera_identity = self:raw(row+4,12)
        assert(B.word(camera_identity,0) == entity and B.word(camera_identity,4) == unit, 'camera_not_player')
        self.stage = 'unit_graph'
        local drone_resource, drone_resource_valid = self:engine_resource(drone.unit)
        assert(gun.descriptor == feed.descriptor, 'weapon_feed_identity')
        local gun_resource, gun_resource_valid = self:engine_resource(feed.unit)
        local drone_parent, drone_parent_valid = self:parent_unit(drone.unit)
        local pack_parent, pack_parent_valid = self:parent_unit(pack.unit)
        local gun_parent, gun_parent_valid = self:parent_unit(feed.unit)
        self.stage = 'position'
        local result = {actor_position = self:position(unit), drone_position = self:position(drone.unit),
            weapon_position = self:position(feed.unit), weapon_forward = self:forward(feed.unit),
            node_index = self:node_index(),
            drone_unit = drone.unit, drone_entity = drone_entity, gun_unit = feed.unit,
            actor_unit = unit, pack_unit = pack.unit,
            drone_parent_unit = drone_parent, pack_parent_unit = pack_parent, gun_parent_unit = gun_parent,
            drone_engine_resource = drone_resource, gun_engine_resource = gun_resource,
            drone_goid = drone.goid, gun_goid = feed.goid,
            brain = brain, motion = motion, movement = movement, targeting = targeting, aim_motor = aim_motor,
            aim_motor_reason = not found and 'lookat_component_absent' or nil,
            camera = camera, camera_row = row, fire_manager = fire.root,
            drone_name = family.name, behavior_kind = family.behavior,
            arc_readiness = arc,arc_reason = arc_reason,
            feed = family.feed, heat = heat_value, ammo = ammo, reserve = reserve,
            magazine_ammo = magazine_ammo, chamber_ammo = chamber_ammo,
            exhausted = ammo ~= nil and ammo == 0, overheated = overheated,
            menu_active = math.floor(menu_flags/512)%2 == 1}
        result.ownership_key = identity..pack.descriptor..drone.descriptor..feed.descriptor..
            brain.descriptor..boids.descriptor..mover.descriptor..aim.descriptor..fire.descriptor..gun.descriptor..
            drone_resource..gun_resource
        result.token = result.ownership_key..tostring(brain.address)
        function result.unit_valid()
            local ok, valid = pcall(function()
                if not (inventory.valid() and pack.valid() and attachment.valid() and drone.valid() and
                    feed_valid() and motion.valid() and movement.valid() and targeting.valid() and
                    (not aim_motor or aim_motor.valid()) and brain.valid() and
                    drone_resource_valid() and gun_resource_valid()) then return false end
                r:position(drone.unit); r:position(feed.unit)
                return r:root(0x3326468) == players and r:root(0x346BF98) == authored and
                    r:raw(actor_at,24) == identity and r:word(players+936) == actor_goid and
                    r:party_allowed(players) and
                    r:word(inventory.address+12) == pack_entity and r:word(attachment.address+4) == entity and
                    r:word(pack.address+4) == drone_goid and r:word(drone.address) == gun_entity and
                    boids.dense < r:word(boids.root+32)
            end)
            return ok and valid
        end
        function result.camera_valid()
            local ok, valid = pcall(function()
                return r:root(0x346D560) == camera and r:raw(row+4,12) == camera_identity
            end)
            return ok and valid
        end
        function result.graph_valid()
            local ok, valid = pcall(function()
                return drone_parent_valid() and pack_parent_valid() and gun_parent_valid()
            end)
            return ok and valid
        end
        function result.fire_valid()
            local ok, valid = pcall(function()
                if not (fire.valid() and gun.valid() and feed_valid() and boids.valid()) then return false end
                r:position(drone.unit); r:position(feed.unit)
                return boids.dense < r:word(boids.root+32) and r:word(fire.address) == gun_entity and
                    (r:word(fire.address+4) == invalid or r:word(fire.address+4) == gun_entity)
            end)
            return ok and valid
        end
        self.stage = 'revalidate'
        -- These aggregate checks already revalidate every component and owner.
        assert(result.unit_valid() and result.fire_valid() and result.camera_valid() and result.graph_valid() and
            self:node_index() == result.node_index, 'snapshot_changed')
        result.deployed = Flight.distance(result.actor_position,result.drone_position) > 1.5
        return result
    end
    return r
end
return Reader
