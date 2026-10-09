local Query,B = ...
local ffi = require('ffi')
local checks = 0
local function check(value,message) assert(value,message); checks = checks+1 end
local function ptr(n)
    return ffi.string(ffi.new('uint64_t[1]',n),8)
end
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
function channel:write() error('surface queries must not write game memory') end
for _,pair in ipairs({{Query.game_guards,channel.base},{Query.engine_guards,channel.exe_base}}) do
    for _,guard in ipairs(pair[1]) do memory[pair[2]+guard[1]] = B.unhex(guard[2]) end
end
memory[channel.base+0x3326328] = ptr(channel.exe_base+0x27CDB40)
memory[channel.exe_base+0x27CDB40] = ptr(channel.exe_base+0x79F860)
memory[channel.exe_base+0x27CDB40+0x80] = ptr(channel.exe_base+0x7F9070)
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
local calls,hit,changed = 0,nil,false
local function invoke(world,shape,mode,types,filter,descriptor,out,capacity)
    calls = calls+1
    check(world == 1 and shape == 2 and mode == 1 and types == 5 and filter == 0x05A5271A and capacity == 1,
        'original worker argument order, box sweep, closest hit and filter')
    local d = ffi.cast('uint64_t *',descriptor)
    local origin = ffi.cast('float *',tonumber(d[0]))
    local rotation = ffi.cast('float *',tonumber(d[1]))
    local extent = ffi.cast('float *',tonumber(d[3]))
    local target = ffi.cast('float *',tonumber(d[4]))
    check(d[2] == 0 and d[5] == 0,'no borrowed transform or shared query options')
    check(rotation[0] == 0 and rotation[1] == 0 and rotation[2] == 0 and rotation[3] == 1,
        'private identity query rotation')
    check(math.abs(extent[0]-0.2) < 0.00001 and extent[0] == extent[1] and extent[1] == extent[2],
        'private small sensing box, not a physical actor')
    check(ffi.cast('uint32_t *',descriptor)[12] == 50 and ffi.cast('uint32_t *',descriptor)[13] == 0,
        'generation-tagged owned drone ignored')
    local travel = 0
    for i = 0,2 do travel = travel+(target[i]-origin[i])^2 end
    check(math.abs(travel-16) < 0.001,'casts remain bounded to four metres')
    if changed then memory[channel.base+0x346BFA0] = ptr(0x30001000) end
    if hit then ffi.copy(out,hit.bytes,44); return hit.count end
    return 0
end
local mock = setmetatable({cast = function(type_name,value)
    if type_name == 'uint32_t (*)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,const void *,void *,uint32_t)' then
        check(value == channel.exe_base+0x7F9070,'only the verified query function can be called')
        return function(...) return invoke(...) end
    end
    return ffi.cast(type_name,value)
end},{__index = ffi})
local function fixture()
    return Query.new(mock,channel,B)
end
local q = fixture()
local owner = true
local snapshot = {drone_unit = 50,gun_unit = 51,pack_unit = 52,actor_unit = 53,
    unit_valid = function() return owner end}
local directions = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local contacts = q:scan(snapshot,{0,0,2},directions,4)
check(#contacts == 0 and calls == 6,'empty scan makes exactly six private casts')
local function result(point,normal,unit,count)
    local out = ffi.new('uint8_t[44]')
    ffi.copy(out,ffi.new('float[3]',point),12)
    ffi.copy(out+12,ffi.new('float[3]',normal),12)
    ffi.cast('uint32_t *',out+28)[0] = unit
    return {bytes = ffi.string(out,44),count = count or 1}
end
-- A hit only on the first cast, as the geometry must face the cast's approach.
local base_invoke = invoke
invoke = function(...)
    if calls % 6 == 0 then hit = result({2,0,2},{-1,0,0},60) else hit = nil end
    return base_invoke(...)
end
contacts = q:scan(snapshot,{0,0,2},directions,4)
check(#contacts == 1 and contacts[1].position[1] == 2 and contacts[1].normal[1] == -1,
    'surface point and normal decode the native 44-byte result')
invoke = base_invoke
for _,unit in ipairs({50,51,52,53}) do
    hit = result({0,0,2},{-1,0,0},unit)
    local got,why = q:scan(snapshot,{0,0,2},directions,4)
    check(got == nil and why == 'surface_owner_occlusion','own attachments never become obstacle planes')
end
for _,bad in ipairs({result({20,0,2},{-1,0,0},60),result({2,0,2},{0,0,0},60),
    result({2,0,2},{1,0,0},60),result({-2,0,2},{-1,0,0},60),result({2,0,2},{-1,0,0},60,2),
    result({0/0,0,2},{-1,0,0},60)}) do
    hit = bad
    check(not pcall(q.scan,q,snapshot,{0,0,2},directions,4),'malformed or foreign result rejected')
end
hit = nil
local before = calls
collectgarbage('collect')
local pressure = {}
for i = 1,1000 do pressure[i] = ffi.new('float[4]',{i,i,i,i}) end
q:scan(snapshot,{0,0,2},directions,4)
check(calls == before+6,'private shape storage survives garbage collection and allocation pressure')
before = calls
memory[0x34040000] = B.u32(1)
local got,why = q:scan(snapshot,{0,0,2},directions,4)
check(got == nil and why == 'query_jobs_busy' and calls == before,'active query scheduler is never borrowed')
memory[0x34040000] = B.u32(0)
memory[0x3404000C] = B.u32(0)
got,why = q:scan(snapshot,{0,0,2},directions,4)
check(got == nil and calls == before,'unfinished jobs prevent native casts')
memory[0x3404000C] = B.u32(1)
owner = false
check(not pcall(q.scan,q,snapshot,{0,0,2},directions,4) and calls == before,'invalid owner prevents casts')
owner = true
check(not pcall(q.scan,q,snapshot,{0,0,2},directions,5),'unbounded sweep rejected')
local saved = memory[channel.exe_base+0x7F9070]
memory[channel.exe_base+0x7F9070] = string.rep('\0',#saved)
check(not pcall(fixture().verify,fixture()),'changed function bytes refuse binding')
memory[channel.exe_base+0x7F9070] = saved
channel.bad_page = true
local foreign = fixture()
check(not pcall(foreign.verify,foreign),'non-executable function pointer refused')
channel.bad_page = false
local saved_api = memory[channel.exe_base+0x27CDB40+0x80]
memory[channel.exe_base+0x27CDB40+0x80] = ptr(channel.exe_base+0x7F9000)
foreign = fixture()
check(not pcall(foreign.verify,foreign),'changed API table refuses binding')
memory[channel.exe_base+0x27CDB40+0x80] = saved_api
changed = true
check(not pcall(q.scan,q,snapshot,{0,0,2},directions,4),'world change discards the whole scan')
return checks
