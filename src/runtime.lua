-- HD2-Addon: mods/codex/drone_remote_control
if type(jit) == 'table' and type(jit.off) == 'function' then jit.off(true,true) end
local B = (function()
-- @BINARY@
end)()
local Lease = (function()
-- @LEASE@
end)()
local Flight = (function()
-- @FLIGHT@
end)()
local Avoidance = (function()
-- @AVOIDANCE@
end)()
local SurfaceQuery = (function()
-- @SURFACE_QUERY@
end)()
local Hotkey = (function()
-- @CONTROL_HOTKEY@
end)()
local Cooperation = (function()
-- @COOPERATION@
end)()
local Options = (function()
-- @OPTIONS@
end)()
local Aim = (function()
-- @AIM@
end)()
local Pose = (function()
-- @POSE@
end)()
local Platform = (function()
-- @PLATFORM@
end)()
local Reader = (function()
-- @READER@
end)()
local SeekerReader = (function()
-- @SEEKER_READER@
end)()
local SeekerHotkey = (function()
-- @SEEKER_HOTKEY@
end)()
local SeekerControl = (function()
-- @SEEKER_CONTROL@
end)()
local Engine = (function()
-- @ENGINE@
end)()
local Controller = (function()
-- @CONTROLLER@
end)()
local Clock = (function()
-- @CLOCK@
end)()
local loader = rawget(_G,'CowboyBingusModLoader')
if type(loader) ~= 'table' or loader.api ~= 1 or rawget(_G,'DroneRemoteControl') then return end
local state = {version = '0.2.22',status = 'initializing',control_active = false,blocking_inputs = false,stopped = false}
rawset(_G,'DroneRemoteControl',state)
local log
if type(loader.open_log) == 'function' then
    local ok,file = pcall(loader.open_log,'DroneRemoteControl.log'); if ok then log = file end
end
local last_report
local function report(message)
    if message == last_report then return end
    last_report = message
    local line = '[DroneRemoteControl 0.2.22] '..message
    print(line)
    if log then pcall(function() log:write(line..'\n'); log:flush() end) end
end
local controller, cooperation, clock, reader, options, channel
local function initialize()
    local s = assert(rawget(_G,'stingray'),'engine_unavailable')
    assert(s.Unit and s.World and s.Window and s.Mouse and s.Vector3 and s.Quaternion,'engine_api_unavailable')
    channel = Platform.new(require('ffi'),B,s)
    clock = Clock.new(function() return channel:now() end)
    reader = Reader.new(channel,B,Flight)
    local seeker_reader = SeekerReader.new(reader,channel,B)
    function reader:seeker_snapshot(ticket) return seeker_reader:snapshot(ticket) end
    function reader:seeker_camera(ticket) return seeker_reader:camera_snapshot(ticket) end
    cooperation = Cooperation.new(_G,state)
    options = Options.new(_G,channel,B,report)
    controller = Controller.new(channel,reader,Engine.new(s,Flight,report,channel),
        B,Lease,Flight,Hotkey,report,cooperation,Aim.new(channel,B,Lease),options,Pose.new(channel,B,Lease),
        Avoidance.new(SurfaceQuery.new(require('ffi'),channel,B),report))
    controller.seeker = SeekerControl.new(seeker_reader,channel,SeekerHotkey,report)
end
local previous_update, previous_shutdown = rawget(_G,'update'),rawget(_G,'shutdown')
local unpack_values = unpack or table.unpack
local function pack(...) return {n = select('#',...),...} end
local my_update
my_update = function(...)
    local result = previous_update and pack(pcall(previous_update,...)) or {n=1,true}
    if not result[1] then
        if controller then pcall(controller.stop,controller,'foreign_update_error') end
        state.control_active = false
        error(result[2],0)
    end
    if not state.stopped then
        local ok,why = pcall(function()
            if not controller then
                if not rawget(_G,'stingray') then return end
                initialize()
            end
            options:tick(channel:now())
            controller:tick(clock:step())
            state.status,state.control_active = controller.status,controller.active
            state.last_error = nil
        end)
        if not ok then
            local stage = controller and controller.stage or 'initialize'
            local preserve_seeker = stage == 'snapshot' and controller and controller.seeker and
                not controller.active and not controller.session and not controller.pending and
                not controller.pack_lease and not controller.input_lease and not controller.seeker_ticket and
                not controller.pending_cleanup
            if stage == 'snapshot' and reader then stage = 'snapshot/'..tostring(reader.stage) end
            why = 'stage='..tostring(stage)..'; '..tostring(why)
            if controller and (controller.active or controller.session or controller.pack_lease or controller.input_lease or controller.pending or controller.seeker_ticket or
                controller.pending_cleanup or cooperation and cooperation.owner) then
                controller:stop('refused:'..tostring(why))
            end
            if not controller then state.stopped = true end
            -- An absent Guard Dog is normal for a Seeker loadout, not a lost key edge.
            if controller then controller:reset_inputs(preserve_seeker) end
            state.status,state.control_active = 'refused',false
            if state.last_error ~= tostring(why) then
                state.last_error = tostring(why); report('refused: '..tostring(why))
            end
        end
    end
    return unpack_values(result,2,result.n)
end
rawset(_G,'update',my_update)
rawset(_G,'shutdown',function(...)
    state.stopped = true
    if controller then controller:stop('shutdown') end
    state.control_active = false
    if rawget(_G,'update') == my_update then rawset(_G,'update',previous_update) end
    if log then pcall(log.close,log); log = nil end
    if previous_shutdown then return previous_shutdown(...) end
end)
report('Private Guard Dog/solo prototype; five backpack families; aim-mode + backpack: recall, dock, deploy, control; backpack: cancel/exit')
report('Solo G-50/G-60 Seeker: aim-mode + quick throw, or equipped throwable + aim-mode + attack; native throw unchanged; fresh attack or aim-mode detonates')
report('Seeker: 30s lifetime; no range limit; explosion releases native AI and hides exploded meshes; camera alone holds for 0.7s')
report('Nonphysical surface clearance: 1m; private native probes every 50ms; unavailable query holds flight')
report('Seeker surface clearance: 0.5m; no impact-detonation trigger added')
