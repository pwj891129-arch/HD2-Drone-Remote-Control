"""Bounded read-only drone snapshots. No process writes, injection or input."""

import argparse
import base64
from datetime import datetime, timezone
import importlib.util
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def camera_module():
    path = ROOT.parent / 'VehicleDualControl/tools/read-camera-state.py'
    spec = importlib.util.spec_from_file_location('drone_readonly', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def u32(raw, offset=0):
    return struct.unpack_from('<I', raw, offset)[0]


def descriptor(raw):
    return {'resource': f'{struct.unpack_from("<Q", raw)[0]:016x}',
            'entity': u32(raw, 8), 'unit': u32(raw, 12), 'goid': u32(raw, 16)}


def block(address, raw):
    return {'address': hex(address), 'base64': base64.b64encode(raw).decode('ascii')}


def capture(reader, label):
    base, path = reader.module('game.dll')
    header = reader.read(base, 4096)
    pe = u32(header, 60)
    if header[:2] != b'MZ' or not 64 <= pe < 2048 or header[pe:pe + 4] != b'PE\0\0':
        raise ValueError('Invalid PE')
    if u32(header, pe + 8) != 0x6AB3B43F or u32(header, pe + 80) not in (0x4744000, 0x4747000):
        raise ValueError('Unsupported game build')
    # Exact instruction bytes in the retained native build, not guessed globals.
    for site, target in [(0x3A4BDE, 0x3326468), (0xBA043, 0x346BF98),
                         (0xA7D744, 0x3326D20), (0x54BB7A, 0x3326460),
                         (0x54DDA4, 0x3326DE0), (0x5349AA, 0x3326780),
                         (0x53F8C4, 0x3326D30), (0x548F84, 0x3326740),
                         (0x533F5A, 0x33265E8), (0x54108A, 0x3326738)]:
        instruction = reader.read(base + site, 7)
        if instruction[:2] not in (b'\x48\x8b', b'\x4c\x8b') or instruction[2] & 0xC7 != 5 or \
                site + 7 + struct.unpack_from('<i', instruction, 3)[0] != target:
            raise ValueError('Actor locator guard failed')
    stable = []

    def pin(address, size):
        value = reader.read(address, size)
        if len(stable) >= 1024:
            raise ValueError('Snapshot identity budget exceeded')
        stable.append((address, value))
        return value

    def ptr(address):
        value = struct.unpack('<Q', pin(address, 8))[0]
        if not 0x10000 <= value < 0x800000000000:
            raise ValueError('Invalid snapshot pointer')
        return value

    def root(rva):
        return ptr(base + rva)

    def mapped(manager, offset, entity):
        pin(manager + offset, 20)
        return reader.mapped(manager, offset, entity)

    def component(rva, map_offset, back_offset, entity, rows=None, stride=0,
                  count_offset=None, limit=512):
        manager = root(rva)
        dense = mapped(manager, map_offset, entity)
        if count_offset is None:
            raise ValueError('Component count layout is not verified')
        count = u32(pin(manager + count_offset, 4))
        if count > limit:
            raise ValueError('Component collection exceeds bounds')
        if dense >= count:
            raise ValueError('Component index exceeds bounds')
        at = ptr(ptr(manager + back_offset) + dense * 8)
        raw = pin(at, 24)
        item = descriptor(raw)
        if item['entity'] != entity:
            raise ValueError('Component entity identity mismatch')
        result = {'manager': hex(manager), 'dense': dense, 'descriptor': item}
        if rows is not None:
            address = ptr(manager + rows) + dense * stride
            result['state'] = block(address, reader.read(address, stride))
        return result

    engine, engine_path = reader.module('helldivers2.exe')
    engine_header = reader.read(engine, 4096)
    engine_pe = u32(engine_header, 60)
    if engine_header[:2] != b'MZ' or not 64 <= engine_pe < 2048 or \
            engine_header[engine_pe:engine_pe + 4] != b'PE\0\0' or \
            u32(engine_header, engine_pe + 80) != 0x39E8000:
        raise ValueError('Unsupported engine build')

    def position(unit):
        registry = ptr(engine + 0x1A100F0)
        header = pin(registry + 0x88, 32)
        rows, count, generations = struct.unpack_from('<Q', header)[0], u32(header, 16), \
            struct.unpack_from('<Q', header, 24)[0]
        index, generation = unit % 0x400000, unit // 0x400000
        if not 0 <= index < count <= 0x400000 or generation > 255:
            raise ValueError('Engine unit index exceeds bounds')
        if pin(generations + index, 1)[0] != generation:
            raise ValueError('Stale engine unit generation')
        obj = ptr(rows + index * 8)
        vtable = ptr(obj)
        if ptr(vtable + 0xE8) not in (engine + 0x2BD870, engine + 0x2BD880):
            raise ValueError('Unsupported engine unit transform accessor')
        matrices = ptr(obj + 0x88)
        xyz = struct.unpack('<3f', reader.read(matrices + 48, 12))
        if not all(math.isfinite(value) and abs(value) < 100000 for value in xyz):
            raise ValueError('Invalid engine unit position')
        return {'xyz': xyz, 'object': hex(obj), 'matrix': hex(matrices)}

    players, authored, avatars = root(0x3326468), root(0x346BF98), root(0x3326D20)
    local_goid = u32(pin(players + 936, 4))
    index = mapped(authored, 15871688, local_goid)
    if index >= 100000:
        raise ValueError('Local descriptor index exceeds bounds')
    actor_raw = pin(authored + 15937304 + index * 24, 24)
    actor = descriptor(actor_raw)
    if not 0 < actor['goid'] < 32767 or actor['goid'] != local_goid or actor['entity'] in (0, 0xFFFFFFFF):
        raise ValueError('Local avatar unavailable')
    dense = mapped(avatars, 248, actor['entity'])
    count = u32(pin(avatars + 108, 4))
    if not dense < count <= 32:
        raise ValueError('Avatar index out of bounds')
    avatar = reader.read(avatars + 0x53D8B0 + dense * 0x1238, 0x1238)
    if u32(avatar, 0xBD4) != actor['entity']:
        raise ValueError('Local avatar identity mismatch')
    backpack_state = reader.read(avatars + 0x546B50 + dense * 0x1B8, 0x1B8)
    inv = component(0x3326738, 40, 64, actor['entity'], 80, 48, 20, 512)
    inventory_raw = base64.b64decode(inv['state']['base64'])
    pack = u32(inventory_raw, 12)
    backpack = component(0x33265E8, 32, 56, pack, 80, 8, 12, 512)
    pack_manager, pack_slot = int(backpack['manager'], 16), backpack['dense']
    backpack['local_runtime'] = block(ptr(pack_manager + 72) + pack_slot * 8,
                                     reader.read(ptr(pack_manager + 72) + pack_slot * 8, 8))
    link_address = int(backpack['state']['address'], 16) + 4
    link_raw = pin(link_address, 4)

    # All mounted inventories, including deployed Guard Dog bodies. This is not
    # nearest-object ownership; the actual avatar-to-drone link is investigated separately.
    mount = root(0x3326438)
    mount_count = u32(pin(mount + 16, 4))
    if mount_count > 128:
        raise ValueError('Mounted inventory collection exceeds limit')
    mounted = []
    if mount_count:
        owners, rows = ptr(mount + 56), ptr(mount + 72)
        for slot in range(mount_count):
            raw = pin(ptr(owners + slot * 8), 24)
            identity = descriptor(raw)
            state = pin(rows + slot * 24, 24)
            mounted.append({'descriptor': identity, 'slots': list(struct.unpack('<6I', state))})
    heat_manager = root(0x3326D48)
    heat_count = u32(pin(heat_manager + 20, 4))
    if heat_count > 512:
        raise ValueError('Heat collection exceeds limit')
    heat = []
    if heat_count:
        owners, rows = ptr(heat_manager + 64), ptr(heat_manager + 88)
        for slot in range(heat_count):
            identity = descriptor(pin(ptr(owners + slot * 8), 24))
            state = reader.read(rows + slot * 12, 12)
            value = struct.unpack_from('<f', state, 4)[0]
            heat.append({'descriptor': identity, 'reserve': u32(state),
                         'heat': value if math.isfinite(value) else None,
                         'overheated': state[8], 'state_hex': state.hex()})
    deploy_goid = u32(link_raw)
    candidates = [row for row in mounted if row['descriptor']['goid'] == deploy_goid]
    drone = None
    if len(candidates) == 1:
        drone = candidates[0]
        entity = drone['descriptor']['entity']
        boids = component(0x3326460, 48, 72, entity, 80, 0x534, 24, 256)
        manager, slot = int(boids['manager'], 16), boids['dense']
        count, owned = u32(pin(manager + 24, 4)), u32(pin(manager + 32, 4))
        if not 0 <= slot < count <= 256 or not 0 <= owned <= count:
            raise ValueError('Boids collection exceeds limit')
        boids['locally_owned'] = slot < owned
        boids['simulation'] = block(ptr(manager + 88) + slot * 0x184,
                                    reader.read(ptr(manager + 88) + slot * 0x184, 0x184))
        boids['configuration'] = block(ptr(manager + 96) + slot * 56,
                                       reader.read(ptr(manager + 96) + slot * 56, 56))
        drone['boids'] = boids
        gun = drone['slots'][0]
        weapon = component(0x3326CE0,48,72,gun,88,0x3F0,24,4096)
        drone['weapon'] = weapon
        heat_feed = [row for row in heat if row['descriptor']['entity'] == gun]
        if len(heat_feed) == 1:
            if heat_feed[0]['descriptor'] != weapon['descriptor']:
                raise ValueError('Weapon/heat identity mismatch')
            drone['feed'] = dict(heat_feed[0], kind='heat')
        else:
            magazine = component(0x3326648,32,56,gun,80,12,12,512)
            if magazine['descriptor'] != weapon['descriptor']:
                raise ValueError('Weapon/magazine identity mismatch')
            state = base64.b64decode(magazine['state']['base64'])
            chambers = ptr(int(magazine['manager'],16)+72)
            chamber = u32(reader.read(chambers+magazine['dense']*16+8,4))
            drone['feed'] = {'kind': 'magazine', 'reserve': u32(state), 'ammo': u32(state,4),
                             'chamber': chamber, 'component': magazine}
        for name, subject, spec in [
            ('navigation', entity, (0x3326DE0, 32, 56, 64, 0x1178, 8, 256)),
            ('targeting', entity, (0x3326D30, 0x150, 0x168, 0x170, 0x50, 0x13C, 512)),
            ('mount_firing', entity, (0x3326780, 32, 56, 64, 0x1C, 12, 512)),
            ('weapon_targeting', gun, (0x3326D30, 0x150, 0x168, 0x170, 0x50, 0x13C, 512)),
            ('behavior', entity, (0x3326740, 64, 88, 96, 0x1F8, 44, 4096)),
        ]:
            rva, map_at, back_at, rows_at, stride, count_at, limit = spec
            try:
                item = component(rva, map_at, back_at, subject, rows_at, stride, count_at, limit)
                manager, slot = int(item['manager'], 16), item['dense']
                if name == 'navigation':
                    item['motion'] = block(ptr(manager + 72) + slot * 28,
                                           reader.read(ptr(manager + 72) + slot * 28, 28))
                    item['extra'] = block(ptr(manager + 80) + slot * 64,
                                          reader.read(ptr(manager + 80) + slot * 64, 64))
                if name.endswith('targeting'):
                    item['simulation'] = block(ptr(manager + 0x178) + slot * 0xD0,
                                               reader.read(ptr(manager + 0x178) + slot * 0xD0, 0xD0))
                if name == 'behavior':
                    item['simulation'] = block(ptr(manager + 104) + slot * 0xA0,
                                               reader.read(ptr(manager + 104) + slot * 0xA0, 0xA0))
                    item['raw_state_number'] = u32(base64.b64decode(item['state']['base64']), 8)
                drone[name] = item
            except ValueError as error:
                drone[name + '_unavailable'] = str(error)
        drone['position'] = position(drone['descriptor']['unit'])
        drone['weapon_position'] = position(weapon['descriptor']['unit'])
    actor_position = position(actor['unit'])
    distance = math.dist(actor_position['xyz'], drone['position']['xyz']) if drone else None
    camera = root(0x346D560)
    camera_state = block(camera, reader.read(camera, 0x2100))
    result = {'time_utc': datetime.now(timezone.utc).isoformat(), 'label': label,
              'read_only': True, 'module': path, 'base': hex(base), 'actor': actor,
              'avatar_dense': dense, 'actor_position': actor_position, 'engine_module': engine_path,
              'avatar_base64': base64.b64encode(avatar).decode('ascii'),
              'backpack_state_base64': base64.b64encode(backpack_state).decode('ascii'),
              'inventory': inv, 'backpack': backpack, 'mounted_inventories': mounted,
              'heat_components': heat, 'deployed_drone_candidate': drone,
              'camera': camera_state, 'distance_m': distance,
              'remote_control_enabled': False}
    for address, raw in stable:
        if reader.read(address, len(raw)) != raw:
            raise ValueError('Identity changed during snapshot; retry')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--label', default='rover-deployed')
    args = parser.parse_args()
    module = camera_module()
    reader = module.Reader(args.pid)
    try:
        result = capture(reader, args.label)
    finally:
        reader.close()
    destination = ROOT / 'research'
    destination.mkdir(exist_ok=True)
    filename = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '.json'
    path = destination / filename
    path.write_text(json.dumps(result, indent=2) + '\n', encoding='ascii')
    drone = result['deployed_drone_candidate']
    print(json.dumps({'path': str(path), 'actor': result['actor'], 'backpack': result['backpack'],
                      'actor_position': result['actor_position'],
                      'drone': drone['descriptor'] if drone else None,
                      'drone_position': drone.get('position') if drone else None,
                      'distance_m': result['distance_m'],
                      'raw_ai_state': drone.get('behavior', {}).get('raw_state_number') if drone else None,
                      'components': [name for name in ('boids', 'behavior', 'navigation', 'targeting',
                                                       'mount_firing', 'weapon_targeting')
                                     if drone and name in drone],
                      'heat_components': result['heat_components'], 'read_only': True}, indent=2))


if __name__ == '__main__':
    main()
