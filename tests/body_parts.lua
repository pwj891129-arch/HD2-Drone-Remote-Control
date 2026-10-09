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
local full_definitions = 0
local raw_read = r.raw
function r:raw(at,size)
    if size == 0x5650 then full_definitions = full_definitions+1 end
    return raw_read(self,at,size)
end
local matched,name = p:matches(meta,unit,actor)
check(not matched and name == 0x2BAD6E19,'unlisted broad root is not a named damage part')
for _,part in ipairs({0x12345678,0x87654321,0x0BADF00D}) do
    memory[address] = patch(actor_bytes,24,B.u32(part))
    check(p:matches(meta,unit,actor),'each authored zone actor is accepted')
end
for _=1,100 do
    local fresh = {identity = meta.identity,authored = meta.authored,valid = meta.valid}
    check(p:matches(fresh,unit,actor),'fresh body identities reuse authored part names')
end
check(full_definitions == 1,'one authored body definition read serves later surface scans')
memory[address] = patch(actor_bytes,24,B.u32(0xABCDEF))
check(not p:matches(meta,unit,actor),'zone name itself is not an actor name')
owner_valid = false
check(not pcall(p.matches,p,meta,unit,actor),'stale body identity refused')
owner_valid = true
memory[address] = patch(actor_bytes,8,B.u32(actor+8192))
check(not p:matches(meta,unit,actor),'recycled actor generation is not a live damage part')
local stable_raw = r.raw
local registry_reads = 0
function r:raw(at,size)
    local value = stable_raw(self,at,size)
    if at == manager then
        registry_reads = registry_reads+1
        if registry_reads > 1 then return patch(value,36,B.u32(4096)) end
    end
    return value
end
check(not pcall(p.matches,p,meta,unit,actor),'recycled handles do not bypass registry instability')
r.raw = stable_raw
memory[address] = patch(actor_bytes,12,B.u32(unit+1))
check(not pcall(p.matches,p,meta,unit,actor),'foreign actor owner refused')
memory[address] = actor_bytes
memory[manager] = patch(header,52,B.u32(8192))
check(not p:matches(meta,unit,actor-8192),'inactive actor is absent without reading its row')
registry_reads = 0
function r:raw(at,size)
    local value = stable_raw(self,at,size)
    if at == manager then
        registry_reads = registry_reads+1
        if registry_reads > 1 then return patch(value,52,B.u32(16384)) end
    end
    return value
end
check(not pcall(p.matches,p,meta,unit,actor-8192),'inactive handles do not bypass registry instability')
r.raw = stable_raw
memory[manager] = patch(header,52,B.u32(0))
check(not pcall(p.matches,p,meta,unit,actor),'missing live mask remains a layout error')
memory[manager] = header
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
local new_table = table_at+0x100000
local new_slot = new_table+index*16
memory[meta.authored+0xF12B78] = ptr(new_table)
memory[new_slot] = memory[slot]
memory[new_table+0x3EA0+7*0x5650] = string.rep('\0',0x5650)
check(not p:matches(meta,unit,actor),'replaced authored tables cannot reuse the old model names')
memory[meta.authored+0xF12B78] = ptr(table_at)
meta.parts = nil
memory[address] = patch(actor_bytes,24,B.u32(0x12345678))
check(p:matches(meta,unit,actor),'returning authored table reloads the correct model names')
local site = Parts.engine_guards[1][1]+channel.exe_base
memory[site] = string.rep('\0',#memory[site])
local other = Parts.new(r,B)
check(not pcall(other.matches,other,meta,unit,actor),'changed Actor accessor refuses part filtering')
return checks
