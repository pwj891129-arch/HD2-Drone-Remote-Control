local Query = {}
Query.filters = {0x05A5271A,0x393D9518} -- Geometry and the game's projectile collision filter.
Query.capacity = 32
Query.overflow_capacity = 128
Query.max_reverse = 14
-- Narrow, private box sweeps, verified against the game's original overlap worker.
-- No scheduler records, actors, collision shapes or player movement are modified.
Query.game_guards = {
    {0x175B8AC,'8b436c8b4b7085c9'},
    {0x175B8D3,'488b054eaabc014c8b9080000000'},
    {0x175B8F1,'488d44244048894424288b43688944242041ffd2'},
    {0x13ABCCC,'4c8bbcc170767c03'},
    {0x13AC0CE,'668584733c2000007507418b8ff8000000'},
}
Query.engine_guards = {
    {0x7F44FF,'488b058a16fd014c8b0d3b19fd01'},
    {0x7F9070,'488bc44889580848897018488978205541564157488d68c1'},
    {0x7F9291,'488b43204885c07426'},
    {0x7F92CA,'8b43308945cf8b43348945d3'},
    {0x7F934A,'8b457f448bce89442440458bc6488b4577'},
    {0x7F937E,'e84ddfffff'},
    {0x7F7100,'4c894424184889542410554154415541574883ec38'},
    {0x7F758C,'83ff010f8532090000'},
    {0x7F76A4,'448bcb4c8bc0498bcf498bd4e84bfaffff'},
    {0x79F860,'33c04c8d05c7b20102'},
}
function Query.new(ffi,channel,B,reader)
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
    local output_size = Query.overflow_capacity*44
    local output_owner,output = aligned(output_size)
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
        local settings = pointer(channel.exe_base+0x27C5E48)
        local count = word(settings+0xF8)
        assert(count > 0 and count <= 512,'surface_filter_bounds')
        local rows = pointer(settings+0x100)
        local hashes = assert(channel:read(rows,count*4),'surface_filters_unavailable')
        for _,filter in ipairs(Query.filters) do
            local found = false
            for i = 0,count-1 do if B.word(hashes,i*4) == filter then found = true; break end end
            assert(found,'surface_body_filter_unavailable')
        end
        local projectile = pointer(channel.base+0x37C7678)
        assert(word(projectile+0xF8) == Query.filters[2], 'surface_projectile_filter_changed')
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
        local contacts,body_cache,live_cache,overlaps,recovered,body_overlaps = {},{},{},{},{},{}
        local reverse_count = 0
        local ignored = snapshot.drone_unit
        assert(type(ignored) == 'number' and ignored > 0 and ignored % 1 == 0 and ignored < 4294967295,
            'surface_ignore_unit_invalid')
        ffi.cast('uint32_t *',descriptor)[12] = ignored
        local function cast(from,direction,filter,narrow)
            for axis = 1,3 do
                origin[axis-1],target[axis-1] = from[axis],from[axis]+direction[axis]*reach
                extent[axis-1] = filter == Query.filters[2] and 0.001 or narrow and 0.02 or 0.2
            end
            ffi.fill(output,Query.capacity*44)
            local count = tonumber(invoke(world.index,2,2,5,filter,descriptor,output,Query.capacity))
            local capacity = Query.capacity
            if count > capacity and count%1 == 0 and count <= Query.overflow_capacity then
                -- The all-hit worker reports total hits even when output is full.
                -- Retry before reading any truncated rows; never keep a partial scan.
                capacity = Query.overflow_capacity
                ffi.fill(output,output_size)
                count = tonumber(invoke(world.index,2,2,5,filter,descriptor,output,capacity))
            end
            assert(count >= 0 and count <= capacity and count%1 == 0,
                'surface_count_invalid_'..tostring(count))
            local hits,initial_overlap = {},false
            for i = 0,count-1 do
                local bytes = ffi.string(output+i*44,44)
                local unit,actor = B.word(bytes,28),B.word(bytes,32)
                -- Inspect identity before undefined initial-overlap geometry. All-hit
                -- sweeps prevent a discarded broad hull from hiding a limb or wall.
                if unit ~= ignored and unit ~= snapshot.gun_unit and unit ~= snapshot.pack_unit and
                    unit ~= snapshot.actor_unit then
                    if live_cache[unit] == nil then
                        live_cache[unit] = not reader or not reader.collision_unit_live or
                            reader:collision_unit_live(unit) ~= false
                    end
                    if live_cache[unit] then
                        if not body_cache[unit] then
                            local body,meta = false,nil
                            if reader then body,meta = reader:character_body(unit,snapshot) end
                            body_cache[unit] = {body = body == true,meta = meta,parts = {}}
                        end
                        local cached = body_cache[unit]
                        local accepted = filter == Query.filters[1] and not cached.body
                        if filter == Query.filters[2] and cached.body then
                            if cached.parts[actor] == nil then
                                cached.parts[actor] = reader:body_part(cached.meta,unit,actor) == true
                            end
                            accepted = cached.parts[actor]
                        end
                        if accepted then
                            local distance = channel:float(bytes,24)
                            initial_overlap = initial_overlap or distance <= 0.00001
                            hits[#hits+1] = {position = channel:vector(bytes,0),normal = channel:vector(bytes,12),
                                distance = distance,unit = unit,actor = actor,character_body = cached.body}
                        end
                    end
                end
            end
            -- A broad box can overlap a wall while its centre is outside. Recheck
            -- that direction with a small probe before treating it as an interior.
            -- Ordinary clear scans and body probes retain their original cost.
            if initial_overlap and filter == Query.filters[1] and not narrow and from == position then
                return cast(from,direction,filter,true)
            end
            return hits
        end
        local function geometry(hit,from,direction)
            local squared_normal,along,squared_distance,facing = 0,0,0,0
            for axis = 1,3 do
                local p,n = hit.position[axis],hit.normal[axis]
                if type(p) ~= 'number' or p ~= p or math.abs(p) >= 100000 or
                    type(n) ~= 'number' or n ~= n or math.abs(n) > 1.1 then return false end
                local delta = p-from[axis]
                squared_normal = squared_normal+n*n
                squared_distance = squared_distance+delta*delta
                along = along+delta*direction[axis]
                facing = facing+n*direction[axis]
            end
            return squared_normal >= 0.81 and squared_normal <= 1.21 and
                squared_distance <= (reach+0.4)^2 and along >= -0.4 and along <= reach+0.4 and facing <= 0.01
        end
        local function add(hit)
            for _,old in ipairs(contacts) do
                local error = 0
                for axis = 1,3 do
                    error = error+math.abs(old.position[axis]-hit.position[axis])+math.abs(old.normal[axis]-hit.normal[axis])
                end
                if old.unit == hit.unit and old.character_body == hit.character_body and error < 0.001 then return end
            end
            contacts[#contacts+1] = hit
        end
        for _, direction in ipairs(directions) do
            local squared = 0
            for axis = 1,3 do
                local p,d = position[axis],direction[axis]
                assert(type(p) == 'number' and p == p and math.abs(p) < 100000 and
                    type(d) == 'number' and d == d and math.abs(d) <= 1.001,'invalid_surface_geometry')
                squared = squared+d*d
            end
            assert(math.abs(squared-1) < 0.001,'invalid_surface_direction')
            for _,filter in ipairs(Query.filters) do
                local nearest
                for _,hit in ipairs(cast(position,direction,filter)) do
                    assert(type(hit.distance) == 'number' and hit.distance == hit.distance and
                        hit.distance >= -reach and hit.distance <= reach+0.4,
                        'surface_distance_invalid_'..tostring(hit.distance)..'_'..tostring(hit.unit)..'_'..tostring(hit.actor))
                    if hit.distance <= 0.00001 then
                        if hit.character_body then
                            -- A moving limb can envelop the drone between samples.
                            -- Permit escape for that body only; terrain remains active.
                            body_overlaps[hit.unit] = true
                        else
                            local key = tostring(hit.unit)..':'..tostring(hit.actor)..':'..tostring(filter)
                            overlaps[key] = true
                            local from,back = {},{}
                            for axis = 1,3 do from[axis],back[axis] = position[axis]+direction[axis]*reach,-direction[axis] end
                            local exits = {}
                            if reverse_count < Query.max_reverse then
                                reverse_count = reverse_count+1
                                exits = cast(from,back,filter)
                            end
                            for _,exit in ipairs(exits) do
                                if exit.unit == hit.unit and exit.actor == hit.actor and
                                    exit.distance > 0.00001 and exit.distance <= reach+0.4 and geometry(exit,from,back) then
                                    local gap = 0
                                    for axis = 1,3 do gap = gap+(position[axis]-exit.position[axis])*exit.normal[axis] end
                                    if gap <= 0.21 and (not recovered[key] or gap > recovered[key].gap) then
                                        exit.gap,exit.recovered = gap,true
                                        recovered[key] = exit
                                    end
                                end
                            end
                            -- Signed sweep distances are penetration depth, not corrupt
                            -- travel. A valid outward normal supplies an MTD escape plane.
                            if hit.distance < -0.00001 then
                                local norm = 0
                                for axis = 1,3 do
                                    local n = hit.normal[axis]
                                    assert(type(n) == 'number' and n == n and math.abs(n) <= 1.1,
                                        'surface_penetration_normal_invalid')
                                    norm = norm+n*n
                                end
                                assert(norm >= 0.81 and norm <= 1.21,'surface_penetration_normal_invalid')
                                if not recovered[key] or hit.distance > recovered[key].gap then
                                    for axis = 1,3 do hit.position[axis] = position[axis]-hit.normal[axis]*hit.distance end
                                    hit.gap,hit.recovered = hit.distance,true
                                    recovered[key] = hit
                                end
                            end
                        end
                    else
                        assert(geometry(hit,position,direction), 'surface_hit_geometry_invalid_'..
                            tostring(hit.unit)..'_'..string.format('%x',filter))
                        if not nearest or hit.distance < nearest.distance then nearest = hit end
                    end
                end
                if nearest then add(nearest) end
            end
        end
        for key in pairs(overlaps) do
            if not recovered[key] then return nil,'surface_overlap_unresolved_'..key end
            -- Choosing one nearest exit avoids opposing initial-overlap normals
            -- pinning a drone in place. Ordinary nearby obstacles remain active.
            add(recovered[key])
        end
        for i = #contacts,1,-1 do
            if contacts[i].character_body and body_overlaps[contacts[i].unit] then table.remove(contacts,i) end
        end
        assert(#contacts <= 128,'surface_contact_bounds')
        assert(snapshot.unit_valid() and pointer(channel.base+0x346BFA0) == world.address and
            pointer(channel.exe_base+0x27BA890+world.index*0xB0) == world.physics, 'surface_world_changed')
        assert(#storage == 6 and output_owner ~= nil, 'surface_storage_lifetime')
        return contacts
    end
    return q
end
return Query
