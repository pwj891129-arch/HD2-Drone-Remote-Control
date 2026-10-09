local Query = {}
-- Narrow, private box sweeps, verified against the game's original overlap worker.
-- No scheduler records, actors, collision shapes or player movement are modified.
Query.game_guards = {
    {0x175B8AC,'8b436c8b4b7085c9'},
    {0x175B8D3,'488b054eaabc014c8b9080000000'},
    {0x175B8F1,'488d44244048894424288b43688944242041ffd2'},
}
Query.engine_guards = {
    {0x7F9070,'488bc44889580848897018488978205541564157488d68c1'},
    {0x7F9291,'488b43204885c07426'},
    {0x7F92CA,'8b43308945cf8b43348945d3'},
    {0x7F934A,'8b457f448bce89442440458bc6488b4577'},
    {0x7F937E,'e84ddfffff'},
    {0x7F7100,'4c894424184889542410554154415541574883ec38'},
    {0x79F860,'33c04c8d05c7b20102'},
}
function Query.new(ffi,channel,B)
    local q = {}
    local function pointer(at)
        return B.ptr(assert(channel:read(at,8),'surface_pointer_unavailable'))
    end
    local function word(at) return B.word(assert(channel:read(at,4),'surface_word_unavailable'),0) end
    local function aligned(size)
        local owner = ffi.new('uint8_t[?]',size+15)
        local at = tonumber(ffi.cast('uintptr_t',owner))
        return owner,owner+(16-at%16)%16
    end
    local output_owner,output = aligned(48)
    local origin,rotation = ffi.new('float[3]'),ffi.new('float[4]',{0,0,0,1})
    local extent,target = ffi.new('float[3]',{0.2,0.2,0.2}),ffi.new('float[3]')
    local descriptor = ffi.new('uint64_t[7]')
    -- Integer pointers in the descriptor do not keep their FFI allocations alive.
    local storage = {origin,rotation,extent,target,descriptor,output_owner}
    descriptor[0],descriptor[1] = ffi.cast('uintptr_t',origin),ffi.cast('uintptr_t',rotation)
    descriptor[3],descriptor[4] = ffi.cast('uintptr_t',extent),ffi.cast('uintptr_t',target)
    local invoke
    function q:verify()
        for _, pair in ipairs({{Query.game_guards,channel.base},{Query.engine_guards,channel.exe_base}}) do
            for _, guard in ipairs(pair[1]) do
                local expected = B.unhex(guard[2])
                assert(channel:read(pair[2]+guard[1],#expected) == expected,
                    'surface_code_changed_'..string.format('%x',guard[1]))
            end
        end
        local table_address = pointer(channel.base+0x3326328)
        assert(table_address == channel.exe_base+0x27CDB40 and
            pointer(table_address) == channel.exe_base+0x79F860 and
            pointer(table_address+0x80) == channel.exe_base+0x7F9070, 'surface_api_changed')
        assert(channel:executable(channel.exe_base+0x7F9070), 'surface_code_not_executable')
        invoke = ffi.cast('uint32_t (*)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,const void *,void *,uint32_t)',
            channel.exe_base+0x7F9070)
    end
    function q:world()
        local world = pointer(channel.base+0x346BFA0)
        local index
        for i = 0,3 do
            local bytes = assert(channel:read(channel.exe_base+0x27BAB30+i*8,8),'surface_world_unavailable')
            if B.hex(bytes) ~= '0000000000000000' and B.ptr(bytes) == world then index = i end
        end
        assert(index ~= nil,'surface_world_unregistered')
        local physics = pointer(channel.exe_base+0x27BA890+index*0xB0)
        local vtable = pointer(physics+0x20)
        assert(channel:read(physics,0x28) and channel:executable(pointer(vtable+0x150)),
            'surface_physics_unavailable')
        local manager = pointer(channel.base+0x3326D20)
        local scheduler = pointer(manager+0x28)
        if word(scheduler+0x40000) ~= 0 then return nil,'query_jobs_busy' end
        for i = 0,7 do
            if word(scheduler+0x4000C+i*12) ~= 1 then return nil,'query_jobs_busy' end
        end
        return {address = world,index = index,physics = physics}
    end
    function q:scan(snapshot,position,directions,reach)
        assert(type(reach) == 'number' and reach > 0 and reach <= 4 and
            type(directions) == 'table' and #directions >= 6 and #directions <= 7, 'invalid_surface_scan')
        assert(snapshot.unit_valid(),'surface_owner_changed')
        if not invoke then self:verify() end
        local world,reason = self:world()
        if not world then return nil,reason end
        local contacts = {}
        local ignored = snapshot.drone_unit
        assert(type(ignored) == 'number' and ignored > 0 and ignored % 1 == 0 and ignored < 4294967295,
            'surface_ignore_unit_invalid')
        ffi.cast('uint32_t *',descriptor)[12] = ignored
        for _, direction in ipairs(directions) do
            local squared = 0
            for axis = 1,3 do
                local p,d = position[axis],direction[axis]
                assert(type(p) == 'number' and p == p and math.abs(p) < 100000 and
                    type(d) == 'number' and d == d and math.abs(d) <= 1.001,'invalid_surface_geometry')
                squared = squared+d*d
                origin[axis-1],target[axis-1] = p,p+d*reach
            end
            assert(math.abs(squared-1) < 0.001,'invalid_surface_direction')
            ffi.fill(output,48)
            local count = tonumber(invoke(world.index,2,1,5,0x05A5271A,descriptor,output,1))
            assert(count == 0 or count == 1,'surface_count_invalid')
            if count == 1 then
                local bytes = ffi.string(output,44)
                local unit = B.word(bytes,28)
                if unit == ignored or unit == snapshot.gun_unit or unit == snapshot.pack_unit or
                    unit == snapshot.actor_unit then return nil,'surface_owner_occlusion' end
                local point,normal = channel:vector(bytes,0),channel:vector(bytes,12)
                local squared_normal,along,squared_distance,facing = 0,0,0,0
                for axis = 1,3 do
                    assert(math.abs(point[axis]) < 100000 and math.abs(normal[axis]) <= 1.1,'surface_hit_invalid')
                    local delta = point[axis]-position[axis]
                    squared_normal = squared_normal+normal[axis]^2
                    squared_distance = squared_distance+delta^2
                    along = along+delta*direction[axis]
                    facing = facing+normal[axis]*direction[axis]
                end
                assert(squared_normal >= 0.81 and squared_normal <= 1.21 and
                    squared_distance <= (reach+0.4)^2 and along >= -0.4 and along <= reach+0.4 and
                    facing <= 0.01,'surface_hit_geometry_invalid')
                contacts[#contacts+1] = {position = point,normal = normal}
            end
        end
        assert(snapshot.unit_valid() and pointer(channel.base+0x346BFA0) == world.address and
            pointer(channel.exe_base+0x27BA890+world.index*0xB0) == world.physics, 'surface_world_changed')
        assert(#storage == 6 and output_owner ~= nil, 'surface_storage_lifetime')
        return contacts
    end
    return q
end
return Query
