local Platform = {}
function Platform.memory(ffi, copy)
    local capacity,buffer,transferred = 256,ffi.new('unsigned char[?]',256),ffi.new('size_t[1]')
    local values = ffi.new('float[4]')
    local memory = {}
    local function finite(n)
        assert(type(n) == 'number' and n == n and math.abs(n) < 1000000, 'invalid_float')
        return n
    end
    function memory:read(at,size)
        if type(size) ~= 'number' or size < 1 or size > 262144 or size%1 ~= 0 then return nil end
        if size > capacity then
            while capacity < size do capacity = capacity*2 end
            buffer = ffi.new('unsigned char[?]',capacity)
        end
        transferred[0] = 0
        if not copy(at,buffer,size,transferred) or tonumber(transferred[0]) ~= size then return nil end
        return ffi.string(buffer,size)
    end
    function memory:float(raw,offset)
        assert(type(raw) == 'string' and type(offset) == 'number' and offset >= 0 and offset%1 == 0 and
            #raw >= offset+4,'invalid_float_bytes')
        ffi.copy(values,raw:sub(offset+1,offset+4),4)
        return finite(tonumber(values[0]))
    end
    function memory:vector(raw,offset)
        assert(type(raw) == 'string' and type(offset) == 'number' and offset >= 0 and offset%1 == 0 and
            #raw >= offset+12,'invalid_float_bytes')
        ffi.copy(values,raw:sub(offset+1,offset+12),12)
        return {finite(tonumber(values[0])),finite(tonumber(values[1])),finite(tonumber(values[2]))}
    end
    function memory:floats(numbers)
        assert(#numbers >= 1 and #numbers <= 4,'invalid_float_count')
        for i=1,#numbers do values[i-1] = finite(numbers[i]) end
        return ffi.string(values,#numbers*4)
    end
    return memory
end
Platform.detonation_guards = {
    {0x8CE2E0,'4053554883ec583b153359bb028bda0f29742440488be90f28f2'},
    {0x8CE368,'48897424708bf048c1e606480375604c89742450448bf0807e24000f85fe000000488b45504a8b0cf0f64114010f84d800'},
    {0x8CE473,'f30f117608c6460101c6462401c7463800000000'},
}
function Platform.detonate(channel, B, invoke, context)
    assert(context.kind == 'seeker' and context.detonation_valid(), 'detonation_identity_changed')
    for _,guard in ipairs(Platform.detonation_guards) do
        local bytes = B.unhex(guard[2])
        assert(channel:read(channel.base+guard[1],#bytes) == bytes and
            channel:executable(channel.base+guard[1]), 'detonation_code_changed')
    end
    assert(context.detonation_valid(), 'detonation_identity_changed')
    invoke(context.detonation_manager,context.drone_entity,0)
end
function Platform.unit_ref(ffi, unit)
    if type(unit) ~= 'userdata' then return nil end
    local ok, encoded = pcall(function() return tonumber(ffi.cast('uintptr_t',unit)) end)
    -- Engine-returned light userdata encodes a generation-tagged UnitRef, not an object pointer.
    if not ok or encoded < 5 or encoded >= 4294967296 or encoded % 4 ~= 1 then return nil end
    return math.floor(encoded/4)
end
function Platform.send_key(user, input, vk, pressed)
    if type(vk) ~= 'number' or vk % 1 ~= 0 or vk < 1 or vk > 254 then return false end
    if vk <= 6 then
        local flags = {[1]={2,4},[2]={8,16},[4]={32,64},[5]={128,256},[6]={128,256}}
        if not flags[vk] then return false end
        input[0].type = 0
        local mouse = input[0].value.mouse
        mouse.x,mouse.y,mouse.time,mouse.extra = 0,0,0,0
        mouse.flags = flags[vk][pressed and 1 or 2]
        mouse.data = vk == 5 and 1 or vk == 6 and 2 or 0
    else
        local scan = user.DRC_MapVirtualKeyW(vk,4)
        if scan == 0 then return false end
        input[0].type = 1
        local key = input[0].value.key
        key.vk,key.scan,key.time,key.extra = 0,scan % 256,0,0
        key.flags = 8+(scan >= 256 and 1 or 0)+(pressed and 0 or 2)
    end
    return user.DRC_SendInput(1,input,40) == 1
end
function Platform.new(ffi, B, engine)
    assert(ffi.abi('64bit'), 'x64_required')
    ffi.cdef([[
typedef struct { void *base, *allocation; unsigned int allocation_protect; unsigned short partition;
    size_t size; unsigned int state, protect, type; } DRC_REGION;
typedef struct { int x,y; } DRC_POINT;
typedef struct { int left,top,right,bottom; } DRC_RECT;
typedef struct { unsigned short vk,scan; unsigned int flags,time; uintptr_t extra; } DRC_KEY;
typedef struct { int x,y; unsigned int data,flags,time; uintptr_t extra; } DRC_MOUSE;
typedef union { DRC_KEY key; DRC_MOUSE mouse; } DRC_INPUT_VALUE;
typedef struct { unsigned int type; DRC_INPUT_VALUE value; } DRC_INPUT;
void* DRC_GetModuleHandleA(const char*) __asm__("GetModuleHandleA");
void* DRC_GetCurrentProcess(void) __asm__("GetCurrentProcess");
unsigned int DRC_GetCurrentProcessId(void) __asm__("GetCurrentProcessId");
unsigned long long DRC_GetTickCount64(void) __asm__("GetTickCount64");
int DRC_ReadProcessMemory(void*,const void*,void*,size_t,size_t*) __asm__("ReadProcessMemory");
int DRC_WriteProcessMemory(void*,void*,const void*,size_t,size_t*) __asm__("WriteProcessMemory");
size_t DRC_VirtualQuery(const void*,DRC_REGION*,size_t) __asm__("VirtualQuery");
void* DRC_GetForegroundWindow(void) __asm__("GetForegroundWindow");
unsigned int DRC_GetWindowThreadProcessId(void*,unsigned int*) __asm__("GetWindowThreadProcessId");
short DRC_GetAsyncKeyState(int) __asm__("GetAsyncKeyState");
int DRC_GetCursorPos(DRC_POINT*) __asm__("GetCursorPos");
int DRC_ClientToScreen(void*,DRC_POINT*) __asm__("ClientToScreen");
int DRC_GetClientRect(void*,DRC_RECT*) __asm__("GetClientRect");
int DRC_SetCursorPos(int,int) __asm__("SetCursorPos");
unsigned int DRC_SendInput(unsigned int,const DRC_INPUT*,int) __asm__("SendInput");
unsigned int DRC_MapVirtualKeyW(unsigned int,unsigned int) __asm__("MapVirtualKeyW");
]])
    assert(ffi.sizeof('DRC_REGION') == 48 and ffi.sizeof('DRC_INPUT') == 40, 'region_layout')
    local kernel, user = ffi.load('kernel32'), ffi.load('user32')
    local process, transferred = kernel.DRC_GetCurrentProcess(), ffi.new('size_t[1]')
    local pid, region = ffi.new('unsigned int[1]'), ffi.new('DRC_REGION[1]')
    local cursor, center, rect = ffi.new('DRC_POINT[1]'), ffi.new('DRC_POINT[1]'), ffi.new('DRC_RECT[1]')
    local input = ffi.new('DRC_INPUT[1]')
    local own_pid = kernel.DRC_GetCurrentProcessId()
    local memory = Platform.memory(ffi,function(at,buffer,size,bytes)
        return kernel.DRC_ReadProcessMemory(process,ffi.cast('void*',at),buffer,size,bytes) ~= 0
    end)
    local channel = {}
    channel.base = tonumber(ffi.cast('uintptr_t', kernel.DRC_GetModuleHandleA('game.dll')))
    channel.exe_base = tonumber(ffi.cast('uintptr_t', kernel.DRC_GetModuleHandleA(nil)))
    local function address(at, size)
        return type(at) == 'number' and at % 1 == 0 and at >= 65536 and
            type(size) == 'number' and size >= 1 and size <= 262144 and
            at + size < 140737488355328
    end
    function channel:read(at, size)
        if not address(at, size) then return nil end
        return memory:read(at,size)
    end
    function channel:write(at, value)
        if not address(at, #value) or #value > 64 then return false end
        if kernel.DRC_VirtualQuery(ffi.cast('void*', at), region, 48) ~= 48 then return false end
        local page, p = region[0], tonumber(region[0].protect)
        if page.state ~= 0x1000 or page.type ~= 0x20000 or p ~= 4 or
            at + #value > tonumber(ffi.cast('uintptr_t', page.base)) + tonumber(page.size) then return false end
        return kernel.DRC_WriteProcessMemory(process, ffi.cast('void*', at), value, #value, transferred) ~= 0 and
            tonumber(transferred[0]) == #value
    end
    function channel:float(raw, offset)
        return memory:float(raw,offset)
    end
    function channel:floats(values)
        return memory:floats(values)
    end
    function channel:vector(raw, offset)
        return memory:vector(raw,offset)
    end
    local function foreground()
        local window = user.DRC_GetForegroundWindow()
        user.DRC_GetWindowThreadProcessId(window, pid)
        if pid[0] == own_pid then return window end
    end
    function channel:foreground() return foreground() ~= nil end
    function channel:executable(at)
        if not address(at,1) or kernel.DRC_VirtualQuery(ffi.cast('void*',at),region,48) ~= 48 then return false end
        return region[0].state == 0x1000 and region[0].type == 0x1000000 and
            (region[0].protect == 0x20 or region[0].protect == 0x40)
    end
    function channel:now()
        local app = engine.Application
        if app and type(app.time_since_launch) == 'function' then
            local ok, value = pcall(app.time_since_launch)
            if ok and type(value) == 'number' and value == value and value >= 0 and value < math.huge then
                return value
            end
        end
        return tonumber(kernel.DRC_GetTickCount64()) / 1000
    end
    function channel:down(vk) return user.DRC_GetAsyncKeyState(vk) < 0 end
    function channel:unit_ref(unit) return Platform.unit_ref(ffi,unit) end
    function channel:key(vk, pressed)
        if pressed and not self:foreground() then return false end
        ffi.fill(input,40)
        return Platform.send_key(user,input,vk,pressed)
    end
    function channel:mouse_delta()
        local window = foreground()
        assert(window and user.DRC_GetClientRect(window, rect) ~= 0 and
            user.DRC_GetCursorPos(cursor) ~= 0, 'cursor_unavailable')
        center[0].x, center[0].y = math.floor(rect[0].right/2), math.floor(rect[0].bottom/2)
        assert(user.DRC_ClientToScreen(window, center) ~= 0, 'cursor_unavailable')
        local dx, dy = cursor[0].x - center[0].x, cursor[0].y - center[0].y
        assert(user.DRC_SetCursorPos(center[0].x, center[0].y) ~= 0, 'cursor_unavailable')
        return dx, dy
    end
    channel.mouse_keys = {}
    for _, pair in ipairs({{'left',1}, {'right',2}, {'middle',4}, {'extra_1',5}, {'extra_2',6}}) do
        local ok, id = pcall(engine.Mouse.button_id, pair[1])
        if ok and type(id) == 'number' and engine.Mouse.button_name(id) == pair[1] then
            channel.mouse_keys[id] = pair[2]
        end
    end
    function channel:fire(context, pressed)
        assert(context.fire_valid(), 'fire_identity_changed')
        local rva = pressed and 0x786BE0 or 0x786DF0
        local signature = B.unhex(pressed and '48894c24085355565741544883ec30' or '405357415441574883ec28')
        assert(self:read(self.base+rva,#signature) == signature, 'fire_code_changed')
        assert(kernel.DRC_VirtualQuery(ffi.cast('void*',self.base+rva),region,48) == 48 and
            region[0].state == 0x1000 and region[0].type == 0x1000000 and
            (region[0].protect == 0x20 or region[0].protect == 0x40), 'fire_code_not_executable')
        local fn = ffi.cast('void(*)(void*,unsigned int,unsigned int)',
            self.base + rva)
        fn(ffi.cast('void*', context.fire_manager), context.drone_entity, 0)
    end
    function channel:detonate(context)
        Platform.detonate(self,B,function(manager,entity,delay)
            local fn = ffi.cast('void(*)(void*,unsigned int,float)',self.base+0x8CE2E0)
            fn(ffi.cast('void*',manager),entity,delay)
        end,context)
    end
    function channel:verify()
        local header = assert(self:read(self.base, 4096), 'module_absent')
        local pe = B.word(header, 60)
        assert(pe >= 64 and pe < 2048 and header:sub(1,2) == 'MZ' and
            header:sub(pe+1,pe+4) == 'PE\0\0' and B.word(header, pe+8) == 0x6AB3B43F and
            (B.word(header, pe+80) == 0x4744000 or B.word(header, pe+80) == 0x4747000), 'unsupported_game_build')
        local guards = {
            {0x472F84,'ffca488bf981fab40200000f8715660000'},
            {0x48EE63,'ffca418bf8488bd981fab40200000f8786420000'},
            {0x786BE0,'48894c24085355565741544883ec30'},
            {0x786DF0,'405357415441574883ec28'},
            {0x849A32,'498b45604c6be13841807c0420000f84eb150000'},
            {0x84B1A2,'498b4560486bca3848894df0807c0820000f84b2360000'},
            {0x84EE8B,'498b4160486bd1384438740220742b4488740220'},
            {0x84E75F,'488b86c0480000486bd11c0f110402'},
            {0x59FF6B,'498b8424c0480000'},
            {0x59FFC5,'0f100406440f29b424100100000f114580'},
            {0x5505DE,'8bb788480000'},
            {0x1279453,'410fb706ffc883f80b0f875a030000'},
            {0xAED057,'41c786880400000200000041c7868c04000025000000'},
            {0xAEC80C,'41c786300400000200000041c786340400001a000000'},
            {0x12F95E6,'448b5604468b1c8a8bd74585d27436'},
            {0x6BBE8E,'837cf81000488945a00f8576040000'},
            {0x6BC95B,'438b44fc10f2440f114de8'},
            {0x6BE4F4,'a8020f858a000000'},
            {0x6BE586,'f30f10642450f30f1074244cf30f105c2448'},
            {0x6BEC21,'488b4750486bd13cf20f110c024489640208'},
            {0x6B9D9B,'498b4a50f20f104500486bd01c8b4508f20f11040a89440a08'},
            {0x6B7747,'4c8b3d6aefc602'},
            {0x6B7CBC,'488b40504c8965b8f2410f100404418b440408'},
            {0x6B7FC9,'41807c041800740d'},
            {0x6BE6BB,'488b4650486bd11c4488740218'},
        }
        for _, guard in ipairs(guards) do
            local expected = B.unhex(guard[2])
            assert(self:read(self.base+guard[1], #expected) == expected, 'native_guard_'..string.format('%x',guard[1]))
        end
        local e = assert(self:read(self.exe_base, 4096)); local ep = B.word(e,60)
        assert(ep >= 64 and ep < 2048 and B.word(e, ep+80) == 0x39E8000, 'unsupported_engine_build')
        assert(self:read(self.exe_base+0x40784E,3) == B.unhex('c1ef02') and
            self:read(self.exe_base+0x9DA48,4) == B.unhex('24033c01') and
            self:read(self.exe_base+0x3EB4D9,7) == B.unhex('8d148d01000000'), 'unit_handle_encoding_changed')
    end
    channel:verify()
    return channel
end
return Platform
