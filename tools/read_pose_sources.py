"""Read canonical rotation inputs without writing or calling engine functions."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'VehicleDualControl/.test-deps'))
from lupa.luajit21 import LuaRuntime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('rpm', ROOT.parent / 'VehicleDualControl/tools/read-camera-state.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    reader = module.Reader(args.pid)
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
        players, authored = native.root(native, 0x3326468), native.root(native, 0x346BF98)
        goid = native.word(native, players+936)
        dense = native.map(native, authored+15871688, goid)
        actor = native.word(native, authored+15937304+dense*24+8)
        subjects = {'actor': actor}
        result = {'read_only': True, 'game_writes': 0, 'engine_calls': 0}
        try:
            snapshot = native.snapshot(native)
            subjects['drone'] = snapshot[b'drone_entity']
        except Exception as error:
            result['snapshot_unavailable'] = str(error).split('\n')[0]
        for name, entity in subjects.items():
            output = result[name] = {'entity': entity}
            for kind, spec in (
                ('rotator', (0x33264A0,0x38,0x50,0x2C,0x58,0x298,0x60,0xC,None)),
                ('interpolation', (0x3326B28,0x28,0x40,0x14,0x50,0x20,0x58,0x20,0x18)),
                ('spatial', (0x3326508,0x40,0x58,0x2C,0x68,0x308,None,None,None)),
            ):
                try:
                    rva, map_at, back, count, rows, stride, replica, replica_stride, local_at = spec
                    comp = native.component(native,rva,map_at,back,count,entity,rows,stride,100000)
                    raw = reader.read(comp[b'address'],stride)
                    item = output[kind] = {'dense': comp[b'dense'], 'raw':raw.hex()}
                    if replica is not None:
                        address = native.ptr(native,comp[b'root']+replica)+comp[b'dense']*replica_stride
                        item['replica'] = reader.read(address,replica_stride).hex()
                        if local_at is not None:
                            item['local_count'] = native.word(native,comp[b'root']+local_at)
                    if kind == 'rotator':
                        override = native.ptr(native,comp[b'root']+0x68)+comp[b'dense']*8
                        item['override'] = reader.read(override,8).hex()
                        item['enabled'] = reader.read(address+8,1)[0]
                        item['target_yaw'] = struct.unpack('<f',reader.read(address,4))[0]
                    if kind == 'spatial':
                        item['rotation'] = struct.unpack('<4f',raw[0x2D0:0x2E0])
                    if kind == 'interpolation':
                        item['target_rotation'] = struct.unpack('<4f',reader.read(address+12,16))
                    if not comp[b'valid']():
                        raise ValueError('Pose identity changed')
                except Exception as error:
                    output[kind] = {'error':str(error).split('\n')[0]}
        path = ROOT/'research'/(datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'-pose-sources.json')
        path.write_text(json.dumps(result,indent=2)+'\n',encoding='ascii')
        print(json.dumps({'path':str(path),**result},indent=2))
    finally:
        reader.close()


if __name__ == '__main__':
    main()
