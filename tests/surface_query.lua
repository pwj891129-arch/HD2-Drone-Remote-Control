local Query,B = ...
local ffi = require('ffi')
local checks = 0
local function check(value,message) assert(value,message); checks = checks+1 end
local function ptr(n) return ffi.string(ffi.new('uint64_t[1]',n),8) end
local memory = {}
local channel = {base = 0x10000000,exe_base = 0x20000000}
function channel:read(at,size)
    local s = memory[at]
    return s and #s >= size and s:sub(1,size) or nil
end
function channel:executable() return not self.bad_page end
function channel:vector(bytes,at)
    local v = ffi.new('float[3]');ffi.copy(v,bytes:sub(at+1,at+12),12)
    return {tonumber(v[0]),tonumber(v[1]),tonumber(v[2])}
end
function channel:float(bytes,at)
    local v = ffi.new('float[1]');ffi.copy(v,bytes:sub(at+1,at+4),4)
    return tonumber(v[0])
end
function channel:write() error('surface queries must not write game memory') end
for _,pair in ipairs({{Query.game_guards,channel.base},{Query.engine_guards,channel.exe_base}}) do
    for _,guard in ipairs(pair[1]) do memory[pair[2]+guard[1]] = B.unhex(guard[2]) end
end
memory[channel.base+0x3326328] = ptr(channel.exe_base+0x27CDB40)
memory[channel.exe_base+0x27CDB40] = ptr(channel.exe_base+0x79F860)
memory[channel.exe_base+0x27CDB40+0x80] = ptr(channel.exe_base+0x7F9070)
memory[channel.exe_base+0x27C5E48] = ptr(0x35000000)
memory[0x350000F8] = B.u32(2)
memory[0x35000100] = ptr(0x36000000)
memory[0x36000000] = B.u32(Query.filters[1])..B.u32(Query.filters[2])
memory[channel.base+0x37C7678] = ptr(0x37000000)
memory[0x370000F8] = B.u32(Query.filters[2])
memory[channel.base+0x346BFA0] = ptr(0x30000000)
for i = 0,3 do memory[channel.exe_base+0x27BAB30+i*8] = ptr(i == 1 and 0x30000000 or 0) end
memory[channel.exe_base+0x27BA890+0xB0] = ptr(0x31000000)
memory[0x31000000] = string.rep('\0',0x28)
memory[0x31000020] = ptr(0x32000000)
memory[0x32000150] = ptr(0x24000000)
memory[channel.base+0x3326D20] = ptr(0x33000000)
memory[0x33000028] = ptr(0x34000000)
memory[0x34040000] = B.u32(0)
for i = 0,7 do memory[0x3404000C+i*12] = B.u32(1) end
local calls,scenario,changed = 0,nil,false
local function result(point,normal,unit,distance,actor,count)
    local out = ffi.new('uint8_t[44]')
    ffi.copy(out,ffi.new('float[3]',point),12)
    ffi.copy(out+12,ffi.new('float[3]',normal),12)
    ffi.cast('float *',out+24)[0] = distance == nil and 2 or distance
    ffi.cast('uint32_t *',out+28)[0] = unit
    ffi.cast('uint32_t *',out+32)[0] = actor or 123
    return {bytes = ffi.string(out,44),count = count or 1}
end
local function results(...)
    local bytes,hits = {},{...}
    for _,hit in ipairs(hits) do bytes[#bytes+1] = hit.bytes end
    return {bytes = table.concat(bytes),count = #hits}
end
local function invoke(world,shape,mode,types,filter,descriptor,out,capacity)
    calls = calls+1
    check(world == 1 and shape == 2 and mode == 2 and types == 5 and
        (filter == Query.filters[1] or filter == Query.filters[2]) and capacity == 32,
        'verified worker arguments and projectile/geometry filters')
    local d = ffi.cast('uint64_t *',descriptor)
    local origin = ffi.cast('float *',tonumber(d[0]))
    local rotation = ffi.cast('float *',tonumber(d[1]))
    local extent = ffi.cast('float *',tonumber(d[3]))
    local target = ffi.cast('float *',tonumber(d[4]))
    check(d[2] == 0 and d[5] == 0,'no borrowed transform or shared query options')
    check(rotation[0] == 0 and rotation[1] == 0 and rotation[2] == 0 and rotation[3] == 1,
        'private identity query rotation')
    local expected_extent = filter == Query.filters[2] and 0.001 or 0.2
    check(math.abs(extent[0]-expected_extent) < 0.0000001 and extent[0] == extent[1] and extent[1] == extent[2],
        'tiny projectile probe and unchanged terrain probe')
    check(ffi.cast('uint32_t *',descriptor)[12] == 50 and ffi.cast('uint32_t *',descriptor)[13] == 0,
        'generation-tagged owned drone ignored')
    local travel,from,dir = 0,{},{}
    for i = 0,2 do
        travel = travel+(target[i]-origin[i])^2
        from[i+1],dir[i+1] = tonumber(origin[i]),tonumber((target[i]-origin[i])/4)
    end
    check(math.abs(travel-16) < 0.001,'forward/recovery casts remain bounded to four metres')
    if changed then memory[channel.base+0x346BFA0] = ptr(0x30001000) end
    local hit = scenario and scenario(filter,from,dir,calls)
    if hit then ffi.copy(out,hit.bytes,math.min(#hit.bytes,capacity*44)); return hit.count end
    return 0
end
local mock = setmetatable({cast = function(type_name,value)
    if type_name == 'uint32_t (*)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,const void *,void *,uint32_t)' then
        check(value == channel.exe_base+0x7F9070,'only the verified function is called')
        return invoke
    end
    return ffi.cast(type_name,value)
end},{__index = ffi})
local classifications,classify_fail = 0,false
local reader = {}
function reader:character_body(unit)
    classifications = classifications+1
    assert(not classify_fail,'body_identity_changed')
    return unit == 53 or unit == 60 or unit == 62,{unit = unit}
end
function reader:body_part(meta,unit,actor)
    assert(meta.unit == unit,'cross-unit part lookup')
    return actor == 123 or actor == 124
end
local function fixture() return Query.new(mock,channel,B,reader) end
local q,owner = fixture(),true
local snapshot = {drone_unit = 50,gun_unit = 51,pack_unit = 52,actor_unit = 53,
    unit_valid = function() return owner end}
local directions = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local function scan()
    calls = 0
    return q:scan(snapshot,{0,0,2},directions,4)
end
local contacts = scan()
check(#contacts == 0 and calls == 12,'empty scan makes twelve private casts')
scenario = function(_,_,_,call) if call <= 2 then return result({2,0,2},{-1,0,0},61) end end
contacts = scan()
check(#contacts == 1 and contacts[1].normal[1] == -1 and contacts[1].unit == 61,
    'terrain uses geometry, not projectile duplicates')
check(not contacts[1].character_body and classifications == 1,'body identity cached within one scan')
scenario = function(_,_,_,call)
    if call == 1 then return result({0,0,0},{0,0,0},60,0) end
    if call == 2 then return result({2,0,2},{-1,0,0},60) end
end
contacts = scan()
check(#contacts == 1 and contacts[1].character_body and contacts[1].actor == 123,
    'broad overlap discarded before geometry validation; projectile body retained')
scenario = function(_,_,_,call) if call == 1 then return result({0,0,0},{0,0,0},60,0) end end
contacts = scan()
check(#contacts == 0 and calls == 12,'leg gap with no projectile hit stays open')
scenario = function(_,_,_,call)
    if call == 1 then return result({2,0,2},{-1,0,0},61) end
    if call == 2 then return result({2,0,2},{-1,0,0},60) end
end
contacts = scan()
check(#contacts == 2 and not contacts[1].character_body and contacts[2].character_body,
    'coincident wall and body retain distinct margins')
for _,unit in ipairs({50,51,52,53}) do
    scenario = function() return result({0/0,0,0},{0,0,0},unit,0) end
    contacts = scan()
    check(#contacts == 0 and calls == 12,'own equipment/body overlap never freezes flight')
end
scenario = function(filter,_,_,call)
    if filter == Query.filters[2] and call == 2 then return result({0.3,0,2},{-1,0,0},62,0.3) end
end
contacts = scan()
check(#contacts == 1 and contacts[1].character_body,'other players retain projectile body clearance')
local function slab(from,dir,unit,actor)
    if from[1] >= -0.4 and from[1] <= 0.2 then return result({0,0,0},{0,0,0},unit,0,actor) end
    if from[1] > 0.2 and dir[1] < 0 then return result({0.2,0,2},{1,0,0},unit,from[1]-0.2,actor) end
    if from[1] < -0.4 and dir[1] > 0 then return result({-0.4,0,2},{-1,0,0},unit,-0.4-from[1],actor) end
end
for _,body in ipairs({false,true}) do
    scenario = function(filter,from,dir)
        if filter == Query.filters[body and 2 or 1] then return slab(from,dir,body and 60 or 61,123) end
    end
    contacts = scan()
    if body then
        check(#contacts == 0 and calls == 12,'moving body overlap permits escape without terrain bypass')
    else
        check(#contacts == 1 and contacts[1].recovered and math.abs(contacts[1].position[1]-0.2) < 0.00001 and
            contacts[1].normal[1] == 1 and not contacts[1].character_body,
            'solid initial overlap finds nearest exit, not opposing placeholder planes')
        check(calls == 18,'one reverse probe at most per solid initial-overlap hit')
    end
end
scenario = function(filter,_,_,call)
    if filter == Query.filters[2] and call == 2 then
        return results(result({0/0,0,0},{0,0,0},60,0,999),
            result({2,0,2},{-1,0,0},60,2,123))
    end
end
contacts = scan()
check(#contacts == 1 and contacts[1].actor == 123,'discarded broad root does not hide actual body parts')
scenario = function(filter,_,_,call)
    if filter == Query.filters[1] and call == 1 then
        return results(result({0/0,0,0},{0,0,0},60,0,999),result({2,0,2},{-1,0,0},61))
    end
end
contacts = scan()
check(#contacts == 1 and contacts[1].unit == 61,'discarded body hull cannot hide a wall behind it')
scenario = function(filter,from,_,call)
    if filter == Query.filters[2] and call == 2 then
        return results(result({0,0,0},{0,0,0},60,0),result({2,0,2},{-1,0,0},60))
    elseif filter == Query.filters[1] and from[1] == 0 and call == 1 then
        return result({2,0,2},{-1,0,0},61)
    end
end
contacts = scan()
check(#contacts == 1 and contacts[1].unit == 61,'enveloping limb suppresses only its own body contacts')
scenario = function(filter,from)
    if filter == Query.filters[1] and from[1] == 0 then
        return result({0/0,0,0},{1,0,0},61,-0.25)
    end
end
contacts = scan()
check(#contacts == 1 and contacts[1].recovered and contacts[1].gap == -0.25 and
    contacts[1].position[1] == 0.25,'bounded penetration depth yields an outward plane without undefined hit position')
scenario = function(filter,from)
    if filter == Query.filters[1] and from[1] == 0 then
        local hits = {}
        for i = 1,32 do hits[i] = result({0,0,0},{0,0,0},61,0,i) end
        return results(unpack(hits))
    end
end
local busy,reason = scan()
check(busy == nil and reason:find('surface_overlap_unresolved',1,true) and calls <= 28,
    'many overlapping actors cannot exceed the bounded reverse query budget')
scenario = function(filter,from,dir)
    if filter == Query.filters[1] then
        local hit = slab(from,dir,61,123)
        if from[1] ~= 0 and hit then return result({0.2,0,2},{1,0,0},61,3.8,124) end
        return hit
    end
end
local got,why = scan()
check(got == nil and why:find('surface_overlap_unresolved',1,true),'foreign actor cannot supply escape plane')
scenario = function(filter,from)
    if filter == Query.filters[1] and from[1] == 0 then return result({0,0,0},{0,0,0},61,0) end
end
got,why = scan()
check(got == nil and why:find('surface_overlap_unresolved',1,true),'unresolved solid interiors hold flight')
classify_fail = true
scenario = function() return result({2,0,2},{-1,0,0},60) end
check(not pcall(scan),'failed identity classification cannot authorize movement')
classify_fail = false
for _,bad in ipairs({result({20,0,2},{-1,0,0},61),result({2,0,2},{0,0,0},61),
    result({2,0,2},{1,0,0},61),result({-2,0,2},{-1,0,0},61),
    result({2,0,2},{-1,0,0},61,2,123,33),result({0/0,0,2},{-1,0,0},61),
    result({2,0,2},{-1,0,0},61,-5),result({2,0,2},{-1,0,0},61,0/0),
    result({0,0,0},{0,0,0},61,-0.25)}) do
    scenario = function() return bad end
    check(not pcall(scan),'malformed non-overlap result rejected')
end
scenario = nil
collectgarbage('collect')
local pressure = {}
for i = 1,1000 do pressure[i] = ffi.new('float[4]',{i,i,i,i}) end
scan()
check(calls == 12,'query storage survives collection/allocation pressure')
local diagonal = {unpack(directions)}
diagonal[7] = {1/math.sqrt(2),1/math.sqrt(2),0}
calls = 0
q:scan(snapshot,{0,0,2},diagonal,4)
check(calls == 14,'normal flight retains fourteen-cast bound')
local before = calls
memory[0x34040000] = B.u32(1)
got,why = q:scan(snapshot,{0,0,2},directions,4)
check(got == nil and why == 'query_jobs_busy' and calls == before,'active scheduler not borrowed')
memory[0x34040000] = B.u32(0)
memory[0x3404000C] = B.u32(0)
got,why = q:scan(snapshot,{0,0,2},directions,4)
check(got == nil and calls == before,'unfinished jobs prevent native casts')
memory[0x3404000C] = B.u32(1)
owner = false
check(not pcall(q.scan,q,snapshot,{0,0,2},directions,4) and calls == before,'invalid owner prevents casts')
owner = true
check(not pcall(q.scan,q,snapshot,{0,0,2},directions,5),'unbounded sweep rejected')
local function reject(at,new,message)
    local saved = memory[at]
    memory[at] = new
    local other = fixture()
    check(not pcall(other.verify,other),message)
    memory[at] = saved
end
reject(channel.exe_base+0x7F9070,string.rep('\0',#memory[channel.exe_base+0x7F9070]),'changed function bytes refuse binding')
reject(channel.base+0x13AC0CE,string.rep('\0',#memory[channel.base+0x13AC0CE]),'changed projectile accessor refuses binding')
reject(0x370000F8,B.u32(0x032A3283),'old broad damage filter is not a projectile filter')
channel.bad_page = true
local other = fixture()
check(not pcall(other.verify,other),'non-executable function pointer refused')
channel.bad_page = false
reject(channel.exe_base+0x27CDB40+0x80,ptr(channel.exe_base+0x7F9000),'changed API table refuses binding')
reject(0x36000000,B.u32(Query.filters[1])..B.u32(0),'missing projectile filter prevents binding')
reject(0x350000F8,B.u32(513),'unbounded filter list refused')
changed = true
check(not pcall(scan),'world change discards the whole scan')
return checks
