"""Read-only verification of the runtime reader. No writes or engine calls."""
import argparse
import ctypes
from datetime import datetime, timezone
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'VehicleDualControl/.test-deps'))
from lupa.luajit21 import LuaRuntime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--watch-seconds', type=int, default=0)
    parser.add_argument('--save', action='store_true', help='Save the one-shot read-only report locally')
    parser.add_argument('--seeker', action='store_true', help='Check the currently held Seeker without writes or native calls')
    parser.add_argument('--observe-keys', type=int, nargs=2, metavar=('AIM_MODE_VK', 'BACKPACK_VK'))
    args = parser.parse_args()
    if not 0 <= args.watch_seconds <= 120:
        parser.error('--watch-seconds must be between 0 and 120')
    if args.observe_keys and (not args.watch_seconds or not all(1 <= key <= 254 for key in args.observe_keys)):
        parser.error('--observe-keys is only for bounded read-only observation')
    spec = importlib.util.spec_from_file_location('rpm', ROOT.parent / 'VehicleDualControl/tools/read-camera-state.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    reader = module.Reader(args.pid)
    try:
        lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
        lua.globals().read_process = reader.read
        lua.globals().game_base = reader.module('game.dll')[0]
        lua.globals().exe_base = reader.module('helldivers2.exe')[0]
        lua.execute(b'''
local ffi=require('ffi')
channel={base=game_base,exe_base=exe_base,mouse_keys={[0]=1,[1]=2,[2]=4,[4]=5,[5]=6}}
function channel:read(at,size) return read_process(at,size) end
function channel:float(s,at) local f=ffi.new('float[1]');ffi.copy(f,s:sub(at+1,at+4),4);return tonumber(f[0]) end
function channel:vector(s,at) return {self:float(s,at),self:float(s,at+4),self:float(s,at+8)} end
''')
        load = lambda name: lua.execute((ROOT / 'src' / (name + '.lua')).read_bytes())
        native = load('reader').new(lua.globals().channel, load('binary'), load('flight'))
        keys = lua.table_from(dict(zip((b'aim_mode', b'backpack'), args.observe_keys))) if args.observe_keys \
            else native.bindings(native)
        if args.seeker:
            if args.watch_seconds:
                parser.error('--seeker is a one-shot read-only check')
            seeker = load('seeker_reader').new(native,lua.globals().channel,load('binary'))
            ticket = seeker.capture(seeker)
            if ticket is None:
                print(json.dumps({'read_only':True,'held_seeker':False,'game_writes':0,'native_calls':0}))
                return
            sample = seeker.snapshot(seeker,ticket)
            guards = load('platform').detonation_guards
            checks = {hex(guard[1]):reader.read(lua.globals().game_base+guard[1],len(guard[2])//2).hex() ==
                      guard[2].decode('ascii') for guard in guards.values()}
            output = {'read_only':True,'game_writes':0,'native_calls':0,'held_seeker':True,
                      'name':ticket[b'name'].decode('ascii'),'entity':ticket[b'entity'],'unit':ticket[b'unit'],
                      'deployed':sample[b'deployed'],'unit_valid':sample[b'unit_valid'](),
                      'graph_valid':sample[b'graph_valid'](),'camera_valid':sample[b'camera_valid'](),
                      'motion_enabled':sample[b'motion'][b'enabled'] == b'\1',
                      'detonation_valid':sample[b'detonation_valid'](),
                      'detonation_code_guards':checks,'brain_type':native.word(native,sample[b'brain'][b'address']),
                      'brain_state':native.word(native,sample[b'brain'][b'address']+8),
                      'aim_mode_key':keys[b'aim_mode'],'attack_key':keys[b'fire']}
            if args.save:
                path = ROOT/'research'/(datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'-seeker-preflight.json')
                path.write_text(json.dumps(output,indent=2)+'\n',encoding='ascii')
                output['saved_path'] = str(path)
            print(json.dumps(output,indent=2))
            return
        if args.watch_seconds:
            user = ctypes.WinDLL('user32')
            user.GetAsyncKeyState.argtypes = [ctypes.c_int]
            user.GetAsyncKeyState.restype = ctypes.c_short
            events, samples, previous = [], 0, None
            start = time.monotonic()
            print('Read-only entry observation ready; no writes or engine calls.', flush=True)
            while time.monotonic() - start < args.watch_seconds:
                event = {name + '_down': user.GetAsyncKeyState(keys[name.encode()]) < 0
                         for name in ('aim_mode', 'backpack')}
                try:
                    snapshot = native.snapshot(native)
                    event.update(menu_active=snapshot[b'menu_active'],
                                 deployed=snapshot[b'deployed'],
                                 brain_handler=native.word(native, snapshot[b'brain'][b'address']))
                except Exception as error:
                    event.update(stage=str(native[b'stage']), error=str(error).split('\n')[0])
                samples += 1
                if event != previous:
                    previous = event
                    event = dict(elapsed=round(time.monotonic() - start, 3), **event)
                    events.append(event)
                    print(json.dumps(event), flush=True)
                time.sleep(0.05)
            report = {'read_only': True, 'game_writes': 0, 'lua_engine_calls': 0,
                      'samples': samples, 'events': events}
            folder = ROOT / 'research'
            folder.mkdir(exist_ok=True)
            path = folder / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-entry.json')
            path.write_text(json.dumps(report, indent=2) + '\n', encoding='ascii')
            print(json.dumps({'path': str(path), 'samples': samples, 'events': len(events)}))
            return
        snapshot = native.snapshot(native)
        pose_sources = {}
        for name, entity in [('drone', snapshot[b'drone_entity'])]:
            for kind, spec in [('interpolation', (0x3326B28,0x28,0x40,0x14,0x58,0x20)),
                               ('spatial', (0x3326508,0x40,0x58,0x2C,0x68,0x308))]:
                try:
                    rva, map_at, back, count, rows, stride = spec
                    comp = native.component(native,rva,map_at,back,count,entity,rows,stride,100000)
                    raw = reader.read(comp[b'address'],stride)
                    assert comp[b'valid'](), 'Pose source changed'
                    pose_sources[name+'_'+kind] = {'address':hex(int(comp[b'address'])), 'raw':raw.hex()}
                except Exception as error:
                    pose_sources[name+'_'+kind] = {'error':str(error).split('\n')[0]}
        obj, valid = native.unit_object(native, snapshot[b'drone_unit'])
        local_matrices = native.ptr(native, obj + 0x80)
        relative = list(struct.unpack('<3f', reader.read(local_matrices + 0x24, 12)))
        if not valid() or native.ptr(native, obj + 0x80) != local_matrices:
            raise ValueError('Drone root changed during read-only observation')
        position = [snapshot[b'drone_position'][index] for index in (1, 2, 3)]
        owner = [snapshot[b'actor_position'][index] for index in (1, 2, 3)]
        if not all(math.isfinite(value) for value in relative + position + owner):
            raise ValueError('Nonfinite root pose')
        parent_relative = math.dist(relative, position) >= 0.02
        distance = math.dist(position, owner)
        output = {'read_only': True, 'snapshot_valid': True,
                  'pose_sources': pose_sources,
                  'keys': {name: keys[name.encode()] for name in
                           ('aim_mode', 'backpack', 'forward', 'back', 'left', 'right', 'up', 'down', 'fire')},
                  'brain_handler': native.word(native, snapshot[b'brain'][b'address']),
                  'autonomous_flight_enabled': snapshot[b'motion'][b'enabled'] == b'\1',
                  'motion_identity_valid': snapshot[b'motion'][b'valid'](),
                  'movement_identity_valid': snapshot[b'movement'][b'valid'](),
                  'movement_input_address': hex(int(snapshot[b'movement'][b'address'])),
                  'movement_direction_speed': struct.unpack('<4f', snapshot[b'movement'][b'original']),
                  'targeting_identity_valid': snapshot[b'targeting'][b'valid'](),
                  'targeting_flags': native.word(native, snapshot[b'targeting'][b'flags']),
                  'targeting_world_point': struct.unpack('<3f', reader.read(snapshot[b'targeting'][b'position'], 12)),
                  'aim_motor_valid': snapshot[b'aim_motor'][b'valid']() if snapshot[b'aim_motor'] else None,
                  'aim_motor_reason': (snapshot[b'aim_motor_reason'] or b'').decode('ascii'),
                  'model_aim_point': struct.unpack('<3f', reader.read(snapshot[b'aim_motor'][b'position'], 12)) if snapshot[b'aim_motor'] else None,
                  'model_aim_engaged': reader.read(snapshot[b'aim_motor'][b'engaged'], 1)[0] if snapshot[b'aim_motor'] else None,
                  'firing_aim_point': struct.unpack('<3f', reader.read(snapshot[b'aim_motor'][b'fire_position'], 12)) if snapshot[b'aim_motor'] else None,
                  'weapon_forward': [snapshot[b'weapon_forward'][index] for index in (1, 2, 3)],
                  'drone_name': snapshot[b'drone_name'].decode('ascii'),
                  'feed': snapshot[b'feed'].decode('ascii'), 'ammo': snapshot[b'ammo'],
                  'heat': snapshot[b'heat'], 'reserve': snapshot[b'reserve'],
                  'exhausted': snapshot[b'exhausted'],
                  'drone_deployed_candidate': snapshot[b'deployed'],
                  'root_node_index': snapshot[b'node_index'],
                  'drone_unit_ref': snapshot[b'drone_unit'], 'gun_unit_ref': snapshot[b'gun_unit'],
                  'drone_engine_resource': snapshot[b'drone_engine_resource'].decode('ascii'),
                  'gun_engine_resource': snapshot[b'gun_engine_resource'].decode('ascii'),
                  'unit_valid': snapshot[b'unit_valid'](),
                  'drone_root_local_position': relative, 'drone_root_world_position': position,
                  'root_parent_relative': parent_relative, 'distance_m': distance,
                  'actor_unit_ref': snapshot[b'actor_unit'], 'pack_unit_ref': snapshot[b'pack_unit'],
                  'drone_parent_unit_ref': snapshot[b'drone_parent_unit'],
                  'pack_parent_unit_ref': snapshot[b'pack_parent_unit'],
                  'gun_parent_unit_ref': snapshot[b'gun_parent_unit'],
                  'graph_valid': snapshot[b'graph_valid'](),
                  'docked_candidate': snapshot[b'drone_parent_unit'] == snapshot[b'pack_unit'],
                  'airborne_candidate': snapshot[b'drone_parent_unit'] is None and distance > 1.5,
                  'menu_active': snapshot[b'menu_active'],
                  'fire_valid': snapshot[b'fire_valid'](), 'camera_valid': snapshot[b'camera_valid'](),
                  'game_writes': 0, 'lua_engine_calls': 0}
        print(json.dumps(output, indent=2))
        if args.save:
            folder = ROOT / 'research'
            folder.mkdir(exist_ok=True)
            path = folder / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '-preflight.json')
            path.write_text(json.dumps(output, indent=2) + '\n', encoding='ascii')
            print(json.dumps({'path': str(path)}))
    finally:
        reader.close()


if __name__ == '__main__':
    main()
