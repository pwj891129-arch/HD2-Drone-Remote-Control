"""Offline checks only; never opens the game or invokes game functions."""
from pathlib import Path
import importlib.util
import json
import sys
import unittest

ROOT = Path(__file__).resolve().parent


def assembled_source():
    return (ROOT / 'src/addon.lua').read_text(encoding='ascii').replace(
        '-- @PROBE@', (ROOT / 'src/api_probe.lua').read_text(encoding='ascii'))


def runtime_source():
    source = (ROOT / 'src/runtime.lua').read_text(encoding='ascii')
    for name in ('binary', 'lease', 'flight', 'avoidance', 'surface_query', 'control_hotkey', 'cooperation', 'options', 'aim', 'pose', 'platform', 'reader', 'body_resources', 'body_parts', 'seeker_reader', 'seeker_hotkey', 'seeker_control', 'seeker_guidance', 'engine', 'controller', 'clock'):
        source = source.replace('-- @' + name.upper() + '@',
                                (ROOT / 'src' / (name + '.lua')).read_text(encoding='ascii'))
    assert '-- @' not in source
    return source


def run():
    dependencies = ROOT.parent / 'VehicleDualControl/.test-deps'
    if str(dependencies) not in sys.path:
        sys.path.insert(0, str(dependencies))
    from lupa.luajit21 import LuaRuntime
    checks = 0

    def check(condition):
        nonlocal checks
        assert condition
        checks += 1

    lua = LuaRuntime(unpack_returned_tuples=True)
    probe = lua.execute((ROOT / 'src/api_probe.lua').read_text(encoding='ascii'))
    check(probe.inventory(lua.table())[1] == 'stingray=unavailable')
    lua.execute('calls=0; hostile={__index=function() calls=calls+1;error("called") end}; '
                'engine={Unit=setmetatable({set_local_position=function() calls=calls+1 end},hostile), '
                'Camera={set_local_pose=function() calls=calls+1 end}}; '
                'globals=setmetatable({stingray=engine},hostile)')
    lines = list(probe.inventory(lua.globals().globals).values())
    check('Unit=set_local_position:function' in lines)
    check('Camera=set_local_pose:function' in lines)
    check(lua.globals().calls == 0)
    large = lua.table_from({str(i): lua.eval('function() error("must not call") end') for i in range(600)})
    lines = list(probe.inventory(lua.table_from({'stingray': lua.table_from({'Unit': large})})).values())
    check('Unit=truncated' in lines)
    check(len(next(line for line in lines if line.startswith('Unit=') and line != 'Unit=truncated')) < 20000)

    hotkeys = lua.execute((ROOT / 'src/control_hotkey.lua').read_text(encoding='ascii'))
    hotkey = hotkeys.new()
    inputs = {'binding_token': 'mapped-actions-v1', 'backpack_down': False,
              'aim_mode_down': False, 'control_active': False,
              'drone_deployed': True, 'entry_allowed': True}

    def press(**changes):
        inputs.update(changes)
        return hotkey.step(hotkey, lua.table_from(inputs))

    check(press(backpack_down=True, aim_mode_down=True) is None)
    check(press(backpack_down=False) is None)
    check(press(backpack_down=True) == 'enter')
    check(press(control_active=True) is None)
    check(press(backpack_down=False, aim_mode_down=False) is None)
    check(press(backpack_down=True) == 'exit')
    check(press() is None)
    check(press(backpack_down=False, control_active=False) is None)
    check(press(backpack_down=True) is None)
    check(press(aim_mode_down=True) is None)
    check(press(backpack_down=False, drone_deployed=False) is None)
    check(press(backpack_down=True) == 'enter')  # A docked drone can start preparation too.
    check(press(backpack_down=False, drone_deployed=True, entry_allowed=False) is None)
    check(press(backpack_down=True) is None)
    check(press(backpack_down=False, entry_allowed=True) is None)
    check(press(backpack_down=True) == 'enter')
    check(press(binding_token='mapped-actions-v2', control_active=True) is None)
    check(press(backpack_down=False) is None)
    check(press(backpack_down=True, aim_mode_down=False, drone_deployed=False,
                entry_allowed=False) == 'exit')
    check(hotkey.step(hotkey, lua.table()) is None)
    check(press() is None)
    check(hotkey.step(hotkey, lua.table_from({'binding_token': '', 'backpack_down': False})) is None)
    check(hotkey.step(hotkey, lua.table_from({'binding_token': 'valid', 'backpack_down': 1})) is None)
    check(hotkey.step(hotkey, None) is None)
    check(press(backpack_down=False, control_active=False, drone_deployed=True,
                entry_allowed=True, aim_mode_down=False, stratagem_down=True) is None)
    check(press(backpack_down=True) is None)  # The old combo never enters.
    check(press(backpack_down=False, aim_mode_down=True) is None)
    check(press(backpack_down=True) == 'enter')

    modules = [lua.execute((ROOT / 'src' / (name + '.lua')).read_text(encoding='ascii'))
               for name in ('binary', 'lease', 'flight', 'controller', 'control_hotkey', 'cooperation', 'aim', 'pose', 'seeker_control', 'seeker_hotkey', 'seeker_guidance')]
    control_checks = lua.execute((ROOT / 'tests/control.lua').read_text(encoding='ascii'), *modules)
    check(control_checks >= 25)
    cooperation_checks = lua.execute((ROOT / 'tests/cooperation.lua').read_text(encoding='ascii'), modules[5])
    check(cooperation_checks >= 15)
    aim = lua.execute((ROOT / 'src/aim.lua').read_text(encoding='ascii'))
    aim_checks = lua.execute((ROOT / 'tests/aim.lua').read_text(encoding='ascii'), aim, modules[0], modules[1])
    check(aim_checks >= 25)
    pose_checks = lua.execute((ROOT / 'tests/pose.lua').read_text(encoding='ascii'), modules[7], modules[0], modules[1])
    check(pose_checks >= 25)
    avoidance = lua.execute((ROOT / 'src/avoidance.lua').read_text(encoding='ascii'))
    query = lua.execute((ROOT / 'src/surface_query.lua').read_text(encoding='ascii'))
    avoidance_checks = lua.execute((ROOT / 'tests/avoidance.lua').read_text(encoding='ascii'), avoidance, modules[2])
    check(avoidance_checks >= 25)
    query_checks = lua.execute((ROOT / 'tests/surface_query.lua').read_text(encoding='ascii'), query, modules[0])
    check(query_checks >= 25)
    parts = lua.execute((ROOT / 'src/body_parts.lua').read_text(encoding='ascii'))
    part_checks = lua.execute((ROOT / 'tests/body_parts.lua').read_text(encoding='ascii'), parts,modules[0])
    check(part_checks >= 10)
    reader = lua.execute((ROOT / 'src/reader.lua').read_text(encoding='ascii'))
    arc_checks = lua.execute((ROOT / 'tests/arc_readiness.lua').read_text(encoding='ascii'),reader,modules[0])
    check(arc_checks >= 15)
    options = lua.execute((ROOT / 'src/options.lua').read_text(encoding='ascii'))
    options_checks = lua.execute((ROOT / 'tests/options.lua').read_text(encoding='ascii'), options, modules[0])
    check(options_checks >= 25)
    engine = lua.execute((ROOT / 'src/engine.lua').read_text(encoding='ascii'))
    engine_checks = lua.execute((ROOT / 'tests/engine.lua').read_text(encoding='ascii'), engine, modules[2])
    check(engine_checks >= 12)
    platform = lua.execute((ROOT / 'src/platform.lua').read_text(encoding='ascii'))
    platform_checks = lua.execute((ROOT / 'tests/platform.lua').read_text(encoding='ascii'), platform,modules[0])
    check(platform_checks >= 25)
    seeker_hotkey_checks = lua.execute((ROOT/'tests/seeker_hotkey.lua').read_text(encoding='ascii'),modules[9])
    check(seeker_hotkey_checks >= 15)
    guidance_checks = lua.execute((ROOT/'tests/seeker_guidance.lua').read_text(encoding='ascii'),modules[10],modules[2])
    check(guidance_checks >= 20)
    runtime = (ROOT / 'src/runtime.lua').read_text(encoding='ascii')
    for name in ('binary', 'lease', 'flight', 'avoidance', 'surface_query', 'control_hotkey', 'cooperation', 'options', 'aim', 'pose', 'platform', 'reader', 'body_resources', 'body_parts', 'seeker_reader', 'seeker_hotkey', 'seeker_control', 'seeker_guidance',
                 'engine', 'controller', 'clock'):
        stub = {'platform': 'return {new=function() return test_channel end}',
                'reader': 'return {new=function() return test_reader end}',
                'seeker_control': 'return {new=function() return {monitor=function() return false end,reset=function() end} end}',
                'engine': 'return {new=function() return {} end}',
                'controller': 'return {new=function(...) test_controller.options=select(11,...);return test_controller end}'}.get(name)
        runtime = runtime.replace('-- @' + name.upper() + '@', stub or
                                  (ROOT / 'src' / (name + '.lua')).read_text(encoding='ascii'))
    runtime_checks = lua.execute((ROOT / 'tests/runtime.lua').read_text(encoding='ascii'), runtime)
    check(runtime_checks >= 15)
    compiled = lua.eval('function(s) return loadstring(s) ~= nil end')(runtime_source())
    check(compiled)
    retained = ROOT.parent / 'BingusStratagemHotkeys/scratch/game-module.bin'
    if retained.exists():
        import re
        image = retained.read_bytes()
        source_platform = (ROOT / 'src/platform.lua').read_text(encoding='ascii') + (ROOT / 'src/reader.lua').read_text(encoding='ascii') + (ROOT / 'src/seeker_reader.lua').read_text(encoding='ascii')
        for rva, raw in re.findall(r"\{(0x[0-9A-F]+),'([0-9a-f]+)'\}", source_platform):
            offset, expected = int(rva, 16), bytes.fromhex(raw)
            check(image[offset:offset + len(expected)] == expected)
        for guard in query.game_guards.values():
            offset, expected = guard[1], bytes.fromhex(guard[2])
            check(image[offset:offset+len(expected)] == expected)
        for guard in parts.game_guards.values():
            offset,expected = guard[1],bytes.fromhex(guard[2])
            check(image[offset:offset+len(expected)] == expected)
    retained_engine = ROOT.parent / 'MissionMedalForecast/scratch/engine-code-20261005.bin'
    if retained_engine.exists():
        image = retained_engine.read_bytes()
        for at, expected in [(0x40784E, 'c1ef02'), (0x9DA48, '24033c01'),
                             (0x3EB4D9, '8d148d01000000'),
                             (0x442882, '488d1517020000'),
                             (0x442AB3, 'ba04000000'), (0x442AD3, 'ba03000000'),
                             (0x442AE9, 'ba02000000'), (0x442AFE, 'ba01000000'),
                             (0x44216F, 'f3440f594b04'),
                             (0x407190, '48895c24084889742410574883ec20ba01000000')]:
            check(image[at:at+len(bytes.fromhex(expected))] == bytes.fromhex(expected))
        for guard in query.engine_guards.values():
            offset, expected = guard[1], bytes.fromhex(guard[2])
            check(image[offset:offset+len(expected)] == expected)
        for guard in parts.engine_guards.values():
            offset,expected = guard[1],bytes.fromhex(guard[2])
            check(image[offset:offset+len(expected)] == expected)

    source = assembled_source()
    check(source.startswith('-- HD2-Addon: mods/codex/drone_remote_control_probe\n'))
    check('-- @PROBE@' not in source)
    for version in [0, 17, 999]:
        vm = LuaRuntime(unpack_returned_tuples=True)
        vm.execute('messages={}; print=function(s) messages[#messages+1]=s end; '
                   'original_calls=0; original_shutdowns=0; '
                   'update=function(...) original_calls=original_calls+1; '
                   'assert(select("#",...)==3); return 7,nil,"tail" end; '
                   'shutdown=function(x) original_shutdowns=original_shutdowns+1; return x end')
        vm.globals().CowboyBingusModLoader = vm.table_from({'api': 1, 'version': version})
        vm.execute(source)
        wrapped = vm.globals().update
        check(wrapped(1, 2, 3) == (7, None, 'tail'))
        check(vm.globals().original_calls == 1)
        state = vm.globals().DroneRemoteControlProbe
        check(state.read_only is True and state.remote_control_enabled is False)
        check(state.status == 'waiting_for_engine')
        vm.execute(source)
        check(vm.eval('update == ...', wrapped))
        check(vm.globals().shutdown('preserved') == 'preserved')
        check(state.stopped is True)
        check(vm.globals().original_shutdowns == 1)
    vm = LuaRuntime()
    vm.execute('print=function() end; update=function() return 42 end')
    vm.execute(source)
    check(vm.globals().DroneRemoteControlProbe is None)
    check(vm.globals().update() == 42)
    vm = LuaRuntime()
    vm.execute('print=function() end; CowboyBingusModLoader={api=1}; '
               'update=function() error("foreign-update-error") end')
    vm.execute(source)
    ok, why = vm.eval('pcall(update)')
    check(not ok and 'foreign-update-error' in why)
    check(vm.globals().DroneRemoteControlProbe.frames == 0)

    spec = importlib.util.spec_from_file_location('drone_probe', ROOT / 'tools/read_drone_state.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    check(module.u32(bytes.fromhex('04000000')) == 4)
    for manifest in ('manifest.json', 'manifest-ko.json'):
        data = json.loads((ROOT / manifest).read_text(encoding='utf-8'))
        check('0.2.27' in data['Name'] and data['Description'].startswith('0.2.27'))
        check(data['Guid'] == '73c9cb24-d2ee-4bd1-818c-a07a570885a7')
        check(data['Options'][0]['Include'] == ['Addon'])
    suite = unittest.defaultTestLoader.discover(str(ROOT / 'tests'), pattern='test_*.py')
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    check(result.wasSuccessful())
    report = {'checks': checks, 'control_checks': control_checks, 'engine_mock_checks': engine_checks,
              'runtime_lifecycle_checks': runtime_checks,
              'platform_input_checks': platform_checks,
              'seeker_hotkey_checks': seeker_hotkey_checks,
              'seeker_guidance_checks': guidance_checks,
              'seeker_entry_delay_s': 0.5,
              'seeker_aim_mode_detonates': False,
              'seeker_same_owner_storage_relocation_supported': True,
              'seeker_homing_default': False,
              'seeker_homing_manual_override': True,
              'in_game_seeker_homing_tested': False,
              'body_surface_query_filters': [f'{int(value):08x}' for value in query.filters.values()],
              'player_enemy_body_clearance_m': avoidance.body_clearance,
              'player_enemy_body_clearance_cm': avoidance.body_clearance * 100,
              'body_blocking_enabled': True,
              'body_collision_geometry': 'verified native projectile collision filter; per-model limb gaps require live testing',
              'body_part_checks': part_checks,
              'body_named_health_actor_filter': True,
              'moving_body_overlap_allows_escape': True,
              'surface_query_hit_capacity': 32,
              'signed_penetration_plane_recovery': True,
              'own_body_equipment_excluded_before_geometry': True,
              'initial_overlap_reverse_probe_recovery': True,
              'initial_overlap_recovery_max_probe_count': 28,
              'unresolved_overlap_holds_flight': True,
              'body_damage_probe_half_extent_m': 0.001,
              'terrain_probe_half_extent_m': 0.2,
              'body_classification': 'guarded UnitRef-to-entity map; player avatars and reviewed enemy archetypes',
              'in_game_body_clearance_tested': False,
              'allow_multiplayer_default': False,
              'multiplayer_preserves_own_drone_identity': True,
              'in_game_multiplayer_tested': False,
              'cooperation_checks': cooperation_checks,
              'manual_aim_checks': aim_checks, 'in_game_options_checks': options_checks,
              'pose_ownership_checks': pose_checks,
              'surface_clearance_checks': avoidance_checks,
              'surface_query_checks': query_checks,
              'k9_arc_readiness_checks': arc_checks,
              'k9_arc_readiness_source': 'ArcWeaponComponent remaining timer / instance fire interval',
              'k9_arc_display_optional': True,
              'in_game_k9_readiness_display_tested': False,
              'nonphysical_surface_clearance_m': 1,
              'surface_sample_interval_ms': 50,
              'in_game_surface_avoidance_tested': False,
              'supported_guard_dog_families': 5,
              'throwable_seeker_control_included': True,
              'seeker_native_throw_on_attack_release': True,
              'seeker_mapped_quick_throw_supported': True,
              'seeker_quick_creation_timeout_s': 3,
              'seeker_passive_backpack_error_preserves_hotkeys': True,
              'seeker_flight_states': [3, 4],
              'seeker_explosion_releases_native_control_immediately': True,
              'seeker_exploded_meshes_hidden': True,
              'seeker_post_explosion_camera_hold_s': 0.7,
              'seeker_signal_range_limit_m': None,
              'seeker_surface_clearance_m': 0.5,
              'seeker_control_lifetime_s': 30,
              'in_game_seeker_control_tested': False,
              'snapshot_tests': result.testsRun,
              'lua_engine_calls': 0, 'game_process_accessed': False,
              'remote_control_implemented': True, 'in_game_control_tested': False}
    print(json.dumps(report, indent=2))
    return report


if __name__ == '__main__':
    run()
