local Reader,B = ...
local ffi = require('ffi')
local checks,memory = 0,{}
local function check(value,message) assert(value,message);checks=checks+1 end
local channel = {base = 0x10000000}
function channel:read(at,size)
    local value = memory[at]
    return value and #value >= size and value:sub(1,size)
end
function channel:float(bytes,at)
    local value = ffi.new('float[1]');ffi.copy(value,bytes:sub(at+1,at+4),4)
    return tonumber(value[0])
end
function channel:write() error('arc display must never write game values') end
for _,guard in ipairs(Reader.arc_guards) do memory[channel.base+guard[1]] = B.unhex(guard[2]) end
local r = Reader.new(channel,B)
local valid = true
local gun = {entity = 728,unit = 17014,descriptor = 'K-9 identity',valid = function() return valid end}
local arc = {address = 0x20000000,unit = gun.unit,descriptor = gun.descriptor,valid = gun.valid}
function r:component(root,map,back,count,entity,rows,stride,limit)
    check(root == 0x3326C10 and map == 0x48 and back == 0x60 and count == 0x38 and
        entity == 728 and rows == 0x70 and stride == 40 and limit == 512,'verified Arc component layout')
    return arc
end
local function timer(remaining,interval)
    memory[arc.address] = ffi.string(ffi.new('float[4]',{0,0,remaining,interval}),16)
    return r:arc_readiness(gun)
end
local value = timer(0,5)
check(value.ready and value.percent == 100 and value.remaining == 0,'idle Arc is ready, not zero charge')
value = timer(5,5)
check(not value.ready and value.percent == 0,'shot starts a fresh readiness interval')
value = timer(2.5,5)
check(not value.ready and value.percent == 50 and value.remaining == 2.5,'actual countdown yields half readiness')
value = timer(1,2)
check(value.percent == 50 and value.interval == 2,'instance fire interval is not hardcoded to five seconds')
value = timer(-0.05,5)
check(value.ready and value.percent == 100 and value.remaining == 0,'native delta undershoot clamps to ready')
value = timer(5.1,5)
check(value.percent == 0,'small timer rounding overshoot cannot create a negative HUD percentage')
for _,pair in ipairs({{0,0},{0,121},{6,5},{-1,5},{0/0,5},{0,0/0},{math.huge,5}}) do
    check(not pcall(timer,pair[1],pair[2]),'invalid Arc timer is not a fabricated readiness value')
end
valid = false
check(not pcall(timer,0,5),'stale owner refuses only optional Arc reading')
valid = true
arc.unit = gun.unit+1
check(not pcall(timer,0,5),'foreign Arc component refused')
arc.unit = gun.unit;arc.descriptor = 'foreign weapon'
check(not pcall(timer,0,5),'resource descriptor mismatch refused')
arc.descriptor = gun.descriptor
local site = Reader.arc_guards[1][1]+channel.base
memory[site] = string.rep('\0',7)
local other = Reader.new(channel,B);other.component = r.component
check(not pcall(other.arc_readiness,other,gun),'changed native build refuses before timer lookup')
return checks
