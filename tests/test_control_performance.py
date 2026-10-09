"""Steady K-9 control workload; mock engine only, not an FPS benchmark."""
import struct
import unittest
import test_runtime_reader as runtime_fixtures
from test_snapshot import ROOT


def k9_control_workload(frames=120):
    fixture = runtime_fixtures.RuntimeReaderTests()
    fixture.setUp()
    fixture.select_family('c28da712b12e3dfa')
    lua, memory, reader = fixture.lua, fixture.memory, fixture.native
    load = lambda name: lua.execute((ROOT / 'src' / (name + '.lua')).read_bytes())
    for guard in load('reader')[b'arc_guards'].values():
        memory.put(memory.game+guard[1], bytes.fromhex(guard[2].decode()))
    pointer = lambda at: struct.unpack('<Q', memory.read(at, 8))[0]
    gun = pointer(memory.game+0x3326CE0)
    owner = memory.read(pointer(pointer(gun+72)), 24)
    memory.component(0x3326C10, 0x48, 0x60, 0x70, 0x38, owner,
                     struct.pack('<4f', 0, 0, 2.5, 5)+bytes(24))
    lua.globals().write_fixture = lambda at, data: (memory.put(at, data), True)[1]
    lua.globals().test_reader = reader
    lua.execute(b'''
local ffi=require('ffi')
function channel:write(at,bytes) return write_fixture(at,bytes) end
function channel:floats(values)
    local raw=ffi.new('float[?]',#values)
    for i=1,#values do raw[i-1]=values[i] end
    return ffi.string(raw,#values*4)
end
channel.time=0
function channel:now() return self.time end
function channel:foreground() return true end
function channel:down() return false end
function channel:mouse_delta() return 0,0 end
function channel:fire(snapshot) assert(snapshot.fire_valid()) end
function channel:unit_ref(unit) return unit end
local sample=test_reader:snapshot()
local positions={[sample.drone_unit]=sample.drone_position,[sample.gun_unit]=sample.weapon_position}
local world={}
local V=setmetatable({to_elements=function(v) return v[1],v[2],v[3] end},
    {__call=function(_,...)return{...}end})
test_engine_api={Vector3=V,Quaternion={from_elements=function(...)return{...}end},
    Application={main_world=function()return world end},
    World={update_unit=function()end},
    Unit={alive=function()return true end,world=function()return world end,
        world_position=function(unit)return positions[unit]end,
        local_position=function(unit)return positions[unit]end,
        teleport_local_rotation=function()end},
    Window={mouse_focus=function()return true end,set_mouse_focus=function()end,
        show_cursor=function()return true end,set_show_cursor=function()end},
    UnitSynchronizer={game_object_id_to_unit=function(_,goid)
        if goid==sample.drone_goid then return sample.drone_unit end
        if goid==sample.gun_goid then return sample.gun_unit end
    end},GameSession={unit_synchronizer=function()return 1 end},
    Network={game_session=function()return 1 end}}
''')
    channel = lua.globals().channel
    binary, lease, flight = load('binary'), load('lease'), load('flight')
    report = lambda message: None
    engine = load('engine').new(lua.globals().test_engine_api, flight, report, channel)
    engine[b'hud'] = lambda *args: None  # GUI cadence is covered separately in tests/engine.lua.
    aim = load('aim').new(channel, binary, lease)
    pose = load('pose').new(channel, binary, lease)
    controller = load('controller').new(channel, reader, engine, binary, lease, flight,
                                        load('control_hotkey'), report, None, aim,
                                        fixture.options, pose)
    controller[b'keys'] = reader.bindings(reader)
    controller.enter(controller, reader.snapshot(reader))
    controller.tick(controller, 1/120)  # Warm entry-time leases and code guards.
    counts = {'reads': 0, 'bytes': 0, 'writes': 0, 'stages': {}}

    def counted_read(at, size):
        counts['reads'] += 1
        counts['bytes'] += size
        stage = controller[b'stage'].decode()
        counts['stages'][stage] = counts['stages'].get(stage, 0)+1
        return memory.read(at, size)

    def counted_write(at, data):
        counts['writes'] += 1
        memory.put(at, data)
        return True

    lua.globals().read_fixture = counted_read
    lua.globals().write_fixture = counted_write
    for frame in range(frames):
        channel[b'time'] = (frame+1)/120
        controller.tick(controller, 1/120)
    assert controller[b'active'] and not controller[b'session'][b'firing']
    counts['frames'] = frames
    return counts


class ControlPerformanceTests(unittest.TestCase):
    def test_stationary_nonfiring_k9_control(self):
        counts = k9_control_workload(12)
        self.assertEqual(counts['frames'], 12)
        self.assertGreater(counts['reads'], 0)
        self.assertIn('control/aim', counts['stages'])

    def test_k9_steady_control_native_reader_budget(self):
        counts = k9_control_workload()
        # Recovery adds live aim-reset checks; the steady read budget grows <0.2%.
        self.assertLessEqual(counts['reads'], 186_000)
        self.assertLessEqual(counts['bytes'], 2_800_000)
        self.assertEqual(counts['writes'], 240)  # Unchanged motor activation is no longer rewritten every frame.


if __name__ == '__main__':
    unittest.main()
