"""Bounded read-only input/transform observation; no writes or engine calls."""
import argparse
import base64
import ctypes
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
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
    parser.add_argument('--seconds', type=int, default=90)
    parser.add_argument('--keys', type=int, nargs='+', required=True)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 120 or not all(1 <= key <= 254 for key in args.keys):
        parser.error('Observation is bounded to 120 seconds and valid virtual keys')
    spec = importlib.util.spec_from_file_location('rpm', ROOT.parent / 'VehicleDualControl/tools/read-camera-state.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    reader = module.Reader(args.pid)
    frames, previous, events = [], None, []
    start = time.monotonic()
    try:
        lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
        lua.globals().rpm = reader.read
        lua.globals().base = reader.module('game.dll')[0]
        lua.globals().exe = reader.module('helldivers2.exe')[0]
        lua.execute(b'''
local ffi=require('ffi'); channel={base=base,exe_base=exe}
function channel:read(a,n) return rpm(a,n) end
function channel:float(s,a)
    local f=ffi.new('float[1]'); ffi.copy(f,s:sub(a+1,a+4),4); return tonumber(f[0])
end
function channel:vector(s,a) return {self:float(s,a),self:float(s,a+4),self:float(s,a+8)} end
''')
        load = lambda name: lua.execute((ROOT / 'src' / (name + '.lua')).read_bytes())
        native = load('reader').new(lua.globals().channel, load('binary'), load('flight'))
        user = ctypes.WinDLL('user32')
        user.GetAsyncKeyState.argtypes = [ctypes.c_int]
        user.GetAsyncKeyState.restype = ctypes.c_short
        print('Read-only control observation ready; no writes or engine calls.', flush=True)
        while time.monotonic() - start < args.seconds:
            frame = {'elapsed': round(time.monotonic() - start, 3),
                     'down': [key for key in args.keys if user.GetAsyncKeyState(key) < 0]}
            try:
                snapshot = native.snapshot(native)
                players, authored = native.root(native, 0x3326468), native.root(native, 0x346BF98)
                actor_index = native.map(native, authored+15871688, native.word(native, players+936))
                actor_entity = native.word(native, authored+15937304+actor_index*24+8)
                avatars = native.root(native, 0x3326D20)
                avatar_index = native.map(native, avatars+248, actor_entity)
                avatar_at = avatars+0x53D8B0+avatar_index*0x1238
                frame['avatar'] = reader.read(avatar_at, 0x1238).hex()
                frame['native_camera_forward'] = struct.unpack('<3f',reader.read(snapshot[b'camera']+0x5C,12))
                entity = snapshot[b'drone_entity']
                boid = native.component(native, 0x3326460, 48, 72, 24, entity, 80, 0x534, 256)
                fire = native.component(native, 0x3326420, 48, 72, 24, entity, 96, 0x1D0, 512)
                mover = native.component(native, 0x3326558, 0x48A0, 0x48B8, 0x4888,
                                         entity, 0x48C0, 0x1C, 4096)
                obj, valid = native.unit_object(native, snapshot[b'drone_unit'])
                matrix = native.ptr(native, obj + 0x88)
                pose = reader.read(matrix, 64)
                local_matrix = native.ptr(native, obj + 0x80)
                local_position = struct.unpack('<3f', reader.read(local_matrix + 0x24, 12))
                simulation = native.ptr(native, boid[b'root'] + 0x58) + boid[b'dense'] * 0x184
                if not valid() or not boid[b'valid']() or not fire[b'valid']() or not mover[b'valid']():
                    raise ValueError('Observed component changed')
                brain = snapshot[b'brain']
                metadata = native.ptr(native, boid[b'root'] + 0x60) + boid[b'dense'] * 0x38
                metadata_raw = reader.read(metadata, 0x38)
                trigger = native.ptr(native, fire[b'root'] + 0x58) + fire[b'dense'] * 32
                states = native.ptr(native, fire[b'root'] + 0x68) + fire[b'dense'] * 4
                frame.update(token=hashlib.sha256(snapshot[b'token']).hexdigest()[:16],
                             unit=snapshot[b'drone_unit'],
                             brain_address=hex(int(brain[b'address'])),
                             handler=native.word(native, brain[b'address']),
                             camera_row=hex(int(snapshot[b'camera_row'])),
                             camera_type=struct.unpack('<H', reader.read(snapshot[b'camera_row'], 2))[0],
                             parent=snapshot[b'drone_parent_unit'], heat=snapshot[b'heat'],
                             targeting_mode=native.word(native,snapshot[b'targeting'][b'flags']),
                             aim_motor_reason=(snapshot[b'aim_motor_reason'] or b'').decode('ascii'),
                             model_aim_point=struct.unpack('<3f',reader.read(snapshot[b'aim_motor'][b'position'],12)) if snapshot[b'aim_motor'] else None,
                             model_aim_engaged=reader.read(snapshot[b'aim_motor'][b'engaged'],1)[0] if snapshot[b'aim_motor'] else None,
                             firing_aim_point=struct.unpack('<3f',reader.read(snapshot[b'aim_motor'][b'fire_position'],12)) if snapshot[b'aim_motor'] else None,
                             weapon_forward=[snapshot[b'weapon_forward'][i] for i in (1,2,3)],
                             reserve=snapshot[b'reserve'],
                             position=[snapshot[b'drone_position'][i] for i in (1, 2, 3)],
                             local_position=local_position,
                             camera_position=struct.unpack('<3f', reader.read(snapshot[b'camera_row'] + 0xB8, 12)),
                             boid_simulation=reader.read(simulation, 0x184).hex(),
                             actor=[snapshot[b'actor_position'][i] for i in (1, 2, 3)],
                             boid_enabled=metadata_raw[0x20], boid_config=metadata_raw.hex(),
                             fire_inputs=reader.read(trigger, 32).hex(),
                             fire_state=struct.unpack('<I', reader.read(states, 4))[0],
                             movement_address=hex(int(mover[b'address'])),
                             movement_direction_speed=struct.unpack('<4f', reader.read(mover[b'address'], 16)),
                             movement_runtime=reader.read(native.ptr(native, mover[b'root']+0x48D0)+
                                                         mover[b'dense']*0xA4, 0xA4).hex(),
                             matrix=base64.b64encode(pose).decode('ascii'))
                try:
                    beam = native.component(native, 0x3326A20, 0x40, 0x58, 0x2C,
                                            native.word(native, fire[b'address']), 0x60, 0x70, 512)
                    if not beam[b'valid']():
                        raise ValueError('Beam identity changed')
                    frame['beam'] = {'address': hex(int(beam[b'address'])),
                                     'raw': reader.read(beam[b'address'], 0x70).hex()}
                except Exception as error:
                    frame['beam_unavailable'] = str(error).split('\n')[0]
                for name, component, size in [('boid', boid, 0x534), ('fire', fire, 0x1D0),
                                              ('brain', brain, 0x1F8)]:
                    frame[name] = {'address': hex(int(component[b'address'])),
                                   'raw': base64.b64encode(reader.read(component[b'address'], size)).decode('ascii')}
                frame['camera_rotation'] = struct.unpack('<4f', reader.read(snapshot[b'camera_row']+0xC8,16))
                for subject in ('actor', 'drone', 'gun'):
                    unit = snapshot[(subject + '_unit').encode()]
                    obj, unit_valid = native.unit_object(native, unit)
                    pose_at = native.ptr(native, obj+0x88)
                    frame[subject+'_matrix'] = struct.unpack('<16f',reader.read(pose_at,64))
                    frame[subject+'_local_pose'] = reader.read(native.ptr(native,obj+0x80),0x30).hex()
                    subject_entity = actor_entity if subject == 'actor' else snapshot[b'drone_entity'] if subject == 'drone' else native.word(native,fire[b'address'])
                    if subject in ('actor','drone'):
                        sources = frame[subject+'_pose_sources'] = {}
                        for kind,spec in (
                            ('rotator',(0x33264A0,0x38,0x50,0x2C,0x58,0x298)),
                            ('interpolation',(0x3326B28,0x28,0x40,0x14,0x50,0x20)),
                            ('spatial',(0x3326508,0x40,0x58,0x2C,0x68,0x308)),
                        ):
                            try:
                                rva,map_at,back,count,rows,stride=spec
                                comp=native.component(native,rva,map_at,back,count,subject_entity,rows,stride,100000)
                                item=sources[kind]={'dense':comp[b'dense']}
                                if kind=='rotator':
                                    replica=native.ptr(native,comp[b'root']+0x60)+comp[b'dense']*12
                                    override=native.ptr(native,comp[b'root']+0x68)+comp[b'dense']*8
                                    item.update(enabled=reader.read(replica+8,1)[0],
                                                target_yaw=struct.unpack('<f',reader.read(replica,4))[0],
                                                override=reader.read(override,8).hex())
                                elif kind=='interpolation':
                                    replica=native.ptr(native,comp[b'root']+0x58)+comp[b'dense']*32
                                    item.update(local_count=native.word(native,comp[b'root']+0x18),
                                                runtime=reader.read(comp[b'address'],32).hex(),
                                                target_rotation=struct.unpack('<4f',reader.read(replica+12,16)))
                                else:
                                    item['rotation']=struct.unpack('<4f',reader.read(comp[b'address']+0x2D0,16))
                                if not comp[b'valid']():
                                    raise ValueError('Pose source changed')
                            except Exception as error:
                                sources[kind]={'error':str(error).split('\n')[0]}
                    try:
                        attachment = native.component(native,0x3326698,0x18,0x30,0x14,
                                                      subject_entity,0x38,0xAC,100000)
                        frame[subject+'_attachment'] = reader.read(attachment[b'address'],0xAC).hex()
                        if not attachment[b'valid']():
                            raise ValueError('Attachment identity changed')
                    except Exception as error:
                        frame[subject+'_attachment_unavailable'] = str(error).split('\n')[0]
                    if subject == 'actor':
                        if not unit_valid():
                            raise ValueError('Actor identity changed')
                        continue
                    entity = snapshot[b'drone_entity'] if subject == 'drone' else native.word(native,fire[b'address'])
                    for name, spec in (
                        ('targeting',(0x3326D30,0x150,0x168,0x13C,0x170,0x50)),
                        ('turret',(0x3326D70,0x28,0x40,0x14,0x50,0x84)),
                    ):
                        try:
                            rva, map_at, back, count, rows, stride = spec
                            comp = native.component(native,rva,map_at,back,count,entity,rows,stride,4096)
                            raw = reader.read(comp[b'address'],stride)
                            item = {'address':hex(int(comp[b'address'])),'raw':raw.hex()}
                            if name == 'targeting':
                                at = native.ptr(native,comp[b'root']+0x178)+comp[b'dense']*0xD0
                                item['simulation'] = reader.read(at,0xD0).hex()
                            else:
                                at = native.ptr(native,comp[b'root']+0x58)+comp[b'dense']*16
                                item['input'] = reader.read(at,16).hex()
                            if not comp[b'valid']() or not unit_valid():
                                raise ValueError('Aim identity changed')
                            frame[subject+'_'+name] = item
                        except Exception as error:
                            frame[subject+'_'+name+'_unavailable'] = str(error).split('\n')[0]
            except Exception as error:
                frame.update(stage=str(native[b'stage']), error=str(error).split('\n')[0])
            frames.append(frame)
            event = {key: frame[key] for key in ('down', 'token', 'handler', 'camera_row', 'camera_type',
                                               'parent', 'boid_enabled', 'fire_inputs', 'fire_state',
                                               'beam_unavailable', 'stage', 'error') if key in frame}
            if event != previous:
                previous = event
                events.append(dict(elapsed=frame['elapsed'], **event))
                print(json.dumps(events[-1]), flush=True)
            time.sleep(0.1)
    finally:
        reader.close()
    folder = ROOT / 'research'
    folder.mkdir(exist_ok=True)
    path = folder / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '-control.json')
    path.write_text(json.dumps({'read_only': True, 'game_writes': 0, 'engine_calls': 0,
                                'frames': frames, 'events': events}, indent=2) + '\n', encoding='ascii')
    print(json.dumps({'path': str(path), 'samples': len(frames), 'events': len(events)}), flush=True)


if __name__ == '__main__':
    main()
