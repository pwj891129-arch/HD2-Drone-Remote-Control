local Platform, B = ...
local checks = 0
local function check(value,message)assert(value,message);checks=checks+1 end
local sent={}
local input={[0]={value={key={},mouse={}}}}
local user={DRC_MapVirtualKeyW=function(vk,mode)assert(mode==4);return vk==37 and 0x14B or vk==84 and 0x14 or 0 end}
function user.DRC_SendInput(count,value,size)
    assert(count==1 and value==input and size==40)
    sent[#sent+1]=value[0].type
    return 1
end
check(Platform.send_key(user,input,84,true),'configured T down')
check(input[0].type==1 and input[0].value.key.vk==0 and input[0].value.key.scan==0x14 and
    input[0].value.key.flags==8,'keyboard uses scan codes')
check(Platform.send_key(user,input,84,false) and input[0].value.key.flags==10,'keyboard release')
check(Platform.send_key(user,input,37,true) and input[0].value.key.flags==9,'extended keyboard down')
check(Platform.send_key(user,input,37,false) and input[0].value.key.flags==11,'extended keyboard release')
for _,pair in ipairs({{1,2,4,0},{2,8,16,0},{4,32,64,0},{5,128,256,1},{6,128,256,2}}) do
    check(Platform.send_key(user,input,pair[1],true),'mapped mouse down')
    check(input[0].type==0 and input[0].value.mouse.flags==pair[2] and input[0].value.mouse.data==pair[4],
        'mapped mouse button data')
    check(Platform.send_key(user,input,pair[1],false) and input[0].value.mouse.flags==pair[3],'mapped mouse release')
end
local before=#sent
for _,key in ipairs({0,3,255,1.5,'T',85}) do check(not Platform.send_key(user,input,key,true),'unsupported key') end
check(#sent==before,'unsupported inputs never sent')
user.DRC_SendInput=function()return 0 end
check(not Platform.send_key(user,input,84,false),'failed key-up is observable')
local ffi=require('ffi')
local allocations,copies,short_read,failed_read = 0,0,false,false
local observed_buffers = {}
local allocating_ffi = {new = function(...)
    allocations = allocations+1; return ffi.new(...)
end,string = ffi.string,copy = ffi.copy}
local bytes = string.rep('X',100000)
local mem = Platform.memory(allocating_ffi,function(at,buffer,size,count)
    copies = copies+1
    observed_buffers[#observed_buffers+1] = buffer
    ffi.copy(buffer,bytes,size)
    count[0] = short_read and size-1 or size
    return not failed_read
end)
local initial_allocations = allocations
local first_read = mem:read(65536,24)
for _=1,100 do check(mem:read(65536,8) == string.rep('X',8),'fresh bytes returned from reusable buffer') end
check(allocations == initial_allocations and observed_buffers[1] == observed_buffers[#observed_buffers],
    'small native reads allocate no per-call FFI arrays')
check(mem:read(65536,83968) == bytes:sub(1,83968),'large binding table grows the buffer once')
local grown_allocations = allocations
check(mem:read(65536,83968) == bytes:sub(1,83968) and allocations == grown_allocations,
    'large buffer is reused on later binding scans')
check(first_read == string.rep('X',24),'returned strings do not alias reused native buffers')
short_read = true;check(mem:read(65536,8) == nil,'partial reads never return old buffer bytes')
short_read,failed_read = false,true
check(mem:read(65536,8) == nil,'failed reads never return stale buffer bytes')
failed_read = false
local before_copies = copies
for _,size in ipairs({0,-1,1.5,262145}) do check(mem:read(65536,size) == nil,'invalid read length refused') end
check(copies == before_copies,'invalid reads never invoke native copying')
local raw = mem:floats({1.25,-2.5,3.75,1})
check(mem:float(raw,4) == -2.5,'reused float decoder keeps offsets')
local xyz = mem:vector(raw,0)
check(xyz[1] == 1.25 and xyz[2] == -2.5 and xyz[3] == 3.75,'vector decodes in one FFI copy')
for _=1,100 do mem:float(raw,0);mem:vector(raw,0);mem:floats({1,2,3}) end
check(allocations == grown_allocations,'numeric conversions allocate no per-call FFI arrays')
check(raw == mem:floats({1.25,-2.5,3.75,1}),'encoded strings survive scratch buffer reuse')
for _,n in ipairs({0/0,math.huge,-math.huge,1000000}) do
    check(not pcall(mem.floats,mem,{n}),'nonfinite or out-of-range values refused')
end
check(not pcall(mem.floats,mem,{1,2,3,4,5}),'oversized float input refused before buffer overflow')
check(not pcall(mem.float,mem,'X',0),'short scalar input refused before native copying')
check(not pcall(mem.vector,mem,raw,8),'short vector input refused before native copying')
check(not pcall(mem.float,mem,raw,-1),'negative byte offset refused')
check(not pcall(mem.floats,mem,{'1'}),'numeric strings cannot enter the native float buffer')
check(not pcall(mem.floats,mem,{[1]=1,[3]=3,[4]=4}),'sparse numeric inputs cannot expose old buffer values')
check(Platform.unit_ref(ffi,nil)==nil and Platform.unit_ref(ffi,{})==nil and
    Platform.unit_ref(ffi,ffi.cast('void*',0x2000009))==nil,'never accept a manufactured cdata Unit handle')
local native_calls,valid = 0,true
local code = {}
for _,guard in ipairs(Platform.detonation_guards) do code[0x100000+guard[1]]=B.unhex(guard[2]) end
local channel = {base=0x100000}
function channel:read(at,size) return code[at] end
function channel:executable() return not self.not_executable end
local context={kind='seeker',drone_entity=573,detonation_manager=0x900000,
    detonation_valid=function() return valid end}
local function invoke(manager,entity,delay)
    check(manager==0x900000 and entity==573 and delay==0,'native explosion arguments preserve original owned Seeker')
    native_calls=native_calls+1
end
Platform.detonate(channel,B,invoke,context)
check(native_calls==1,'verified explosion path invoked once')
valid=false
check(not pcall(Platform.detonate,channel,B,invoke,context),'identity changes prevent detonation')
valid=true
context.kind='backpack'
check(not pcall(Platform.detonate,channel,B,invoke,context),'backpack drones cannot use explosion path')
context.kind='seeker'
channel.not_executable=true
check(not pcall(Platform.detonate,channel,B,invoke,context),'nonexecutable code refused')
channel.not_executable=false
for _,guard in ipairs(Platform.detonation_guards) do
    local at=channel.base+guard[1];local original=code[at];code[at]='FOREIGN'
    check(not pcall(Platform.detonate,channel,B,invoke,context),'modified native code refused')
    code[at]=original
end
check(native_calls==1,'failed checks never invoke native explosion')
local read=channel.read
function channel:read(at,size) local raw=read(self,at,size);valid=false;return raw end
check(not pcall(Platform.detonate,channel,B,invoke,context) and native_calls==1,
    'ownership rechecked immediately before native invocation')
return checks
