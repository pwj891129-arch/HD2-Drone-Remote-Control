"""Read-only code/world verification. Never invokes a game function or writes memory."""
import argparse
import ctypes
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'VehicleDualControl/.test-deps'))
from lupa.luajit21 import LuaRuntime


class Region(ctypes.Structure):
    _fields_ = [('base', ctypes.c_void_p), ('allocation', ctypes.c_void_p),
                ('allocation_protection', ctypes.c_uint32), ('partition', ctypes.c_uint16),
                ('size', ctypes.c_size_t), ('state', ctypes.c_uint32),
                ('protection', ctypes.c_uint32), ('type', ctypes.c_uint32)]


def inspect(reader):
    game, _ = reader.module('game.dll')
    engine, _ = reader.module('helldivers2.exe')
    lua = LuaRuntime(unpack_returned_tuples=True)
    query = lua.execute((ROOT / 'src/surface_query.lua').read_text(encoding='ascii'))
    body_reader = lua.execute((ROOT / 'src/reader.lua').read_text(encoding='ascii'))
    guards = []
    for name, base in [('game', game), ('engine', engine)]:
        for guard in query[name + '_guards'].values():
            at, expected = guard[1], bytes.fromhex(guard[2])
            actual = reader.read(base + at, len(expected))
            guards.append({'module': name, 'rva': hex(at), 'matched': actual == expected})
    for guard in body_reader.body_guards.values():
        at,expected = guard[1],bytes.fromhex(guard[2])
        actual = reader.read(game+at,len(expected))
        guards.append({'module': 'game','purpose': 'body_identity','rva': hex(at),'matched': actual == expected})
    if not all(guard['matched'] for guard in guards):
        raise ValueError('Unsupported surface function bytes: ' + json.dumps(guards))
    api = reader.pointer(game + 0x3326328)
    if api != engine + 0x27CDB40 or reader.pointer(api) != engine + 0x79F860 or \
            reader.pointer(api + 0x80) != engine + 0x7F9070:
        raise ValueError('Surface API table changed')
    settings = reader.pointer(engine+0x27C5E48)
    count = reader.u32(settings+0xF8)
    if not 0 < count <= 512:
        raise ValueError('Surface filter bounds changed')
    rows = reader.read(reader.pointer(settings+0x100),count*4)
    registered = {int.from_bytes(rows[i:i+4],'little') for i in range(0,len(rows),4)}
    filters = list(query.filters.values())
    if any(value not in registered for value in filters):
        raise ValueError('Required body/geometry filter is not registered')
    projectile = reader.pointer(game+0x37C7678)
    if reader.u32(projectile+0xF8) != filters[1]:
        raise ValueError('Native projectile collision filter changed')
    reader.kernel.VirtualQueryEx.argtypes = [ctypes.c_void_p, ctypes.c_void_p,
                                             ctypes.POINTER(Region), ctypes.c_size_t]
    reader.kernel.VirtualQueryEx.restype = ctypes.c_size_t

    def executable(at):
        region = Region()
        if reader.kernel.VirtualQueryEx(reader.handle, at, ctypes.byref(region),
                                         ctypes.sizeof(region)) != ctypes.sizeof(region):
            return False
        return region.state == 0x1000 and region.type == 0x1000000 and region.protection in (0x20, 0x40)

    if not executable(engine + 0x7F9070):
        raise ValueError('Query target is not an executable image page')
    samples = []
    for _ in range(20):
        world = reader.pointer(game + 0x346BFA0)
        registered = [int.from_bytes(reader.read(engine + 0x27BAB30 + i * 8, 8), 'little') for i in range(4)]
        if registered.count(world) != 1:
            raise ValueError('Active world is not uniquely registered')
        index = registered.index(world)
        physics = reader.pointer(engine + 0x27BA890 + index * 0xB0)
        vtable = reader.pointer(physics + 0x20)
        if not executable(reader.pointer(vtable + 0x150)):
            raise ValueError('Physics query target is not executable')
        avatar = reader.pointer(game + 0x3326D20)
        scheduler = reader.pointer(avatar + 0x28)
        count = reader.u32(scheduler + 0x40000)
        jobs = [reader.u32(scheduler + 0x4000C + i * 12) for i in range(8)]
        samples.append({'world_index': index, 'pending_queries': count, 'jobs': jobs,
                        'idle': count == 0 and all(job == 1 for job in jobs)})
        time.sleep(0.05)
    return {'read_only': True, 'game_writes': 0, 'game_function_calls': 0,
            'code_guards': guards, 'api_table_verified': True,
            'registered_probe_filters': [f'{value:08x}' for value in filters],
            'native_projectile_filter_verified': True,
            'body_hits_tested': False,
            'body_identity_connections_tested': False,
            'physics_world_verified': True, 'idle_samples': sum(row['idle'] for row in samples),
            'sample_count': len(samples), 'samples': samples,
            'surface_hits_tested': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--save', action='store_true')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('reader', ROOT.parent / 'VehicleDualControl/tools/read-camera-state.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    reader = module.Reader(args.pid)
    try:
        result = inspect(reader)
        print(json.dumps(result, indent=2))
        if args.save:
            path = ROOT / 'research' / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '-surface-query.json')
            path.write_text(json.dumps(result, indent=2) + '\n', encoding='ascii')
            print(json.dumps({'path': str(path)}))
    finally:
        reader.close()


if __name__ == '__main__':
    main()
