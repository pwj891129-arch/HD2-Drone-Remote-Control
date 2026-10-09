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
