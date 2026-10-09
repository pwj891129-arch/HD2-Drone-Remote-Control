-- HD2-Addon: mods/codex/drone_remote_control_probe
local Probe = (function()
-- @PROBE@
end)()

local loader = rawget(_G, 'CowboyBingusModLoader')
if type(loader) ~= 'table' or loader.api ~= 1 then
    print('[DroneRemoteControlProbe] Bingus Shared Loader API 1 required')
    return
end
if rawget(_G, 'DroneRemoteControlProbe') then return end
local state = {version = '0.1.0', read_only = true, remote_control_enabled = false,
               status = 'waiting_for_update', frames = 0, stopped = false}
rawset(_G, 'DroneRemoteControlProbe', state)
local log
if type(loader.open_log) == 'function' then
    local ok, file = pcall(loader.open_log, 'DroneRemoteControlProbe.log')
    if ok then log = file end
end
local function report(message)
    local text = '[DroneRemoteControlProbe 0.1.0] ' .. message
    print(text)
    if log then pcall(function() log:write(text .. '\n'); log:flush() end) end
end
local previous_update, previous_shutdown = rawget(_G, 'update'), rawget(_G, 'shutdown')
local unpack_values = unpack or table.unpack
local function pack(...) return {n = select('#', ...), ...} end
local signature
local function tick()
    state.frames = state.frames + 1
    if state.frames > 36000 then state.status = 'complete'; return end
    if state.frames ~= 1 and state.frames % 120 ~= 0 then return end
    local lines = Probe.inventory(_G)
    local current = table.concat(lines, '\n')
    if current == signature then return end
    signature = current
    state.status = lines[1] == 'stingray=unavailable' and 'waiting_for_engine' or 'captured'
    for _, line in ipairs(lines) do report(line) end
end
local my_update
my_update = function(...)
    local result = previous_update and pack(previous_update(...)) or {n = 0}
    if not state.stopped then
        local ok, why = pcall(tick)
        if not ok then
            state.status, state.stopped = 'refused', true
            report('inspection stopped: ' .. tostring(why))
        end
    end
    return unpack_values(result, 1, result.n)
end
rawset(_G, 'update', my_update)
rawset(_G, 'shutdown', function(...)
    state.stopped = true
    if rawget(_G, 'update') == my_update then rawset(_G, 'update', previous_update) end
    if log then pcall(log.close, log); log = nil end
    if previous_shutdown then return previous_shutdown(...) end
end)
report('API inventory only; no memory writes, input, AI changes or camera changes')
