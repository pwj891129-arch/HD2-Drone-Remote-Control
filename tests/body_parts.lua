local Parts,B = ...
local ffi = require('ffi')
local memory,checks = {},0
local function check(value,message) assert(value,message);checks=checks+1 end
local function ptr(value) return ffi.string(ffi.new('uint64_t[1]',value),8) end
local function patch(bytes,at,new) return bytes:sub(1,at)..new..bytes:sub(at+#new+1) end
local channel = {base = 0x10000000,exe_base = 0x20000000}
local r = {channel = channel}
function r:raw(at,size)
    local raw = assert(memory[at],'missing fixture '..string.format('%x',at))
    assert(#raw >= size,'short fixture');return raw:sub(1,size)
end
function r:ptr(at) return B.ptr(self:raw(at,8)) end
for _,pair in ipairs({{Parts.game_guards,channel.base},{Parts.engine_guards,channel.exe_base}}) do
    for _,guard in ipairs(pair[1]) do memory[pair[2]+guard[1]] = B.unhex(guard[2]) end
end
local owner_valid = true
local resource = B.unhex('ddafccccf2172e9e')
local meta = {identity = resource..string.rep('\0',16),authored = 0x30000000,
    valid = function() return owner_valid end}
local table_at,index = 0x40000000,0
for i = 8,1,-1 do index = (index*256+resource:byte(i))%1002 end
memory[meta.authored+0xF12B78] = ptr(table_at)
local slot = table_at+index*16
memory[slot] = resource..B.u32(7)..B.u32(0)
local definition = table_at+0x3EA0+7*0x5650
local bytes = string.rep('\0',0x5650)
bytes = patch(bytes,0x208+96,B.u32(0xABCDEF))
bytes = patch(bytes,0x208+456,B.u32(0x12345678))
bytes = patch(bytes,0x208+460,B.u32(0x87654321))
bytes = patch(bytes,0x208+0x228+96,B.u32(0xFEDCBA))
bytes = patch(bytes,0x208+0x228+456,B.u32(0x0BADF00D))
memory[definition] = bytes
local actor,unit = 0x900021ED,0x800E64
local manager = channel.exe_base+0x2369B00+(2*10+1)*64
local header = string.rep('\0',64)
header = patch(header,0,ptr(0x50000000))
header = patch(header,28,B.u32(56+8*65536))
header = patch(header,36,B.u32(8192))
header = patch(header,40,B.u32(8191))
header = patch(header,52,B.u32(0xC0000000))
memory[manager] = header
local address = 0x50000000+(actor%8192)*56
local actor_bytes = string.rep('\0',56)
actor_bytes = patch(actor_bytes,8,B.u32(actor))
actor_bytes = patch(actor_bytes,12,B.u32(unit))
actor_bytes = patch(actor_bytes,24,B.u32(0x2BAD6E19))
memory[address] = actor_bytes
local p = Parts.new(r,B)
local matched,name = p:matches(meta,unit,actor)
check(not matched and name == 0x2BAD6E19,'unlisted broad root is not a named damage part')
for _,part in ipairs({0x12345678,0x87654321,0x0BADF00D}) do
    memory[address] = patch(actor_bytes,24,B.u32(part))
    check(p:matches(meta,unit,actor),'each authored zone actor is accepted')
end
memory[address] = patch(actor_bytes,24,B.u32(0xABCDEF))
check(not p:matches(meta,unit,actor),'zone name itself is not an actor name')
owner_valid = false
check(not pcall(p.matches,p,meta,unit,actor),'stale body identity refused')
owner_valid = true
memory[address] = patch(actor_bytes,8,B.u32(actor+8192))
check(not pcall(p.matches,p,meta,unit,actor),'recycled actor generation refused')
memory[address] = patch(actor_bytes,12,B.u32(unit+1))
check(not pcall(p.matches,p,meta,unit,actor),'foreign actor owner refused')
memory[address] = actor_bytes
memory[manager] = patch(header,36,B.u32(131073))
check(not pcall(p.matches,p,meta,unit,actor),'oversized actor registry refused')
memory[manager] = header
memory[slot] = string.rep('\0',16)
meta.parts = nil
check(not p:matches(meta,unit,actor),'missing definition does not restore broad body hulls')
memory[slot] = resource..B.u32(1002)..B.u32(0)
meta.parts = nil
check(not pcall(p.matches,p,meta,unit,actor),'invalid authored dense index refused')
memory[slot] = resource..B.u32(7)..B.u32(0)
local site = Parts.engine_guards[1][1]+channel.exe_base
memory[site] = string.rep('\0',#memory[site])
local other = Parts.new(r,B)
check(not pcall(other.matches,other,meta,unit,actor),'changed Actor accessor refuses part filtering')
return checks
