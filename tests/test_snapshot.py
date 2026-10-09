"""Synthetic process memory fixtures. No Windows or game API calls."""
import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('snapshot_probe', ROOT / 'tools/read_drone_state.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class Memory:
    def __init__(self):
        self.bytes = {}
        self.cursor = 0x80000000
        self.maps = {}
        self.reads = 0
        self.changed = None
        self.observed = {}
        self.game, self.engine = 0x10000000, 0x40000000
        for base, size in [(self.game, 0x4744000), (self.engine, 0x39E8000)]:
            self.put(base, bytes(4096))
            self.put(base, b'MZ')
            self.word(base + 60, 128)
            self.put(base + 128, b'PE\0\0')
            self.word(base + 136, 0x6AB3B43F)
            self.word(base + 208, size)
        for site, target in [(0x3A4BDE, 0x3326468), (0xBA043, 0x346BF98),
                             (0xA7D744, 0x3326D20), (0x54BB7A, 0x3326460),
                             (0x54DDA4, 0x3326DE0), (0x5349AA, 0x3326780),
                             (0x53F8C4, 0x3326D30), (0x548F84, 0x3326740),
                             (0x533F5A, 0x33265E8), (0x54108A, 0x3326738)]:
            self.put(self.game + site, b'\x48\x8b\x05' + struct.pack('<i', target - site - 7))
        actor, backpack, drone, gun = self.record(1242, 1, 476), self.record(1290, 4, 523), \
            self.record(1291, 2, 525), self.record(1292, 3, 524)
        players, authored, avatars = self.root(0x3326468), self.root(0x346BF98), self.root(0x3326D20)
        self.word(players + 936, 476)
        self.mapping(authored, 15871688, {476: 0})
        self.put(authored + 15937304, actor)
        self.mapping(avatars, 248, {1242: 0})
        self.word(avatars + 108, 1)
        self.put(avatars + 0x53D8B0, bytes(0x1238))
        self.word(avatars + 0x53D8B0 + 0xBD4, 1242)
        self.put(avatars + 0x546B50, bytes(0x1B8))
        inventory = bytearray(48)
        struct.pack_into('<I', inventory, 12, 1290)
        self.inventory = self.component(0x3326738, 40, 64, 80, 20, actor, inventory)
        deposit = self.component(0x33265E8, 32, 56, 80, 12, backpack, struct.pack('<II', 4, 525))
        self.pointer(deposit + 72, self.allocate(struct.pack('<II', 4, 3)))
        mount = self.root(0x3326438)
        self.word(mount + 16, 1)
        self.pointer(mount + 56, self.allocate(struct.pack('<Q', self.allocate(drone))))
        self.pointer(mount + 72, self.allocate(struct.pack('<6I', 1292, 0, 0, 0, 0, 0)))
        heat = self.root(0x3326D48)
        self.word(heat + 20, 1)
        self.pointer(heat + 64, self.allocate(struct.pack('<Q', self.allocate(gun))))
        self.pointer(heat + 88, self.allocate(struct.pack('<If4B', 3, 12.5, 0, 0, 0, 0)))
        self.component(0x3326CE0,48,72,88,24,gun,bytes(0x3F0))
        boids = self.component(0x3326460, 48, 72, 80, 24, drone, bytes(0x534))
        self.word(boids + 32, 1)
        self.pointer(boids + 88, self.allocate(bytes(0x184)))
        self.pointer(boids + 96, self.allocate(bytes(56)))
        targeting = self.component(0x3326D30, 0x150, 0x168, 0x170, 0x13C, drone, bytes(0x50))
        self.pointer(targeting + 0x178, self.allocate(bytes(0xD0)))
        behavior_data = bytearray(0x1F8)
        struct.pack_into('<I', behavior_data, 8, 3)
        behavior = self.component(0x3326740, 64, 88, 96, 44, drone, behavior_data)
        self.pointer(behavior + 104, self.allocate(bytes(0xA0)))
        for rva in [0x3326DE0, 0x3326780]:
            self.mapping(self.root(rva), 32, {})
        camera = self.root(0x346D560)
        self.put(camera, bytes(0x2100))
        registry = self.allocate(bytes(0xA8))
        self.pointer(self.engine + 0x1A100F0, registry)
        rows, generations = self.allocate(bytes(40)), self.allocate(b'\0\1\1\1\1')
        self.put(registry + 0x88, struct.pack('<QQIIQ', rows, 0, 5, 0, generations))
        for index, xyz in [(1, (0, 0, 0)), (2, (3, 4, 0)), (3, (3, 4, 0)), (4, (0, 0, 1))]:
            obj, vtable, matrix = self.allocate(bytes(0x1E8)), self.allocate(bytes(0x1E8)), \
                self.allocate(bytes(64))
            self.pointer(rows + index * 8, obj)
            self.pointer(obj, vtable)
            self.word(obj + 8, 0x400000 + index)
            self.pointer(vtable + 0xE8, self.engine + 0x2BD870)
            self.pointer(vtable + 0x1E0, self.engine + 0x2BD9E0)
            self.pointer(obj + 0x88, matrix)
            self.put(matrix + 48, struct.pack('<3f', *xyz))

    def put(self, at, raw):
        self.bytes.update((at + offset, value) for offset, value in enumerate(raw))

    def word(self, at, value):
        self.put(at, struct.pack('<I', value))

    def pointer(self, at, value):
        self.put(at, struct.pack('<Q', value))

    def allocate(self, raw):
        at = self.cursor
        self.cursor += max(len(raw), 0x100) + 0x100
        self.put(at, raw)
        return at

    def root(self, rva):
        at = self.allocate(bytes(0x2200 if rva == 0x346D560 else 0x400))
        self.pointer(self.game + rva, at)
        return at

    def record(self, entity, unit, goid):
        return struct.pack('<QIIII', 0x0123456789ABCDEF, entity, 0x400000 + unit, goid, 0)

    def mapping(self, manager, offset, mapping):
        self.maps[manager, offset] = mapping
        self.put(manager + offset, bytes(20))

    def component(self, rva, map_at, back_at, rows_at, count_at, owner, state):
        manager = self.root(rva)
        entity = struct.unpack_from('<I', owner, 8)[0]
        self.mapping(manager, map_at, {entity: 0})
        self.word(manager + count_at, 1)
        self.pointer(manager + back_at, self.allocate(struct.pack('<Q', self.allocate(owner))))
        self.pointer(manager + rows_at, self.allocate(state))
        return manager

    def module(self, name):
        return (self.game if name == 'game.dll' else self.engine), name

    def mapped(self, manager, offset, key):
        try:
            return self.maps[manager, offset][key]
        except KeyError:
            raise ValueError('Entity not mapped') from None

    def read(self, at, size):
        self.reads += 1
        assert 0 < size <= 0x100000
        self.observed[at] = self.observed.get(at, 0) + 1
        raw = bytes(self.bytes[index] for index in range(at, at + size))
        if at == self.changed and self.observed[at] >= 2:
            return bytes([raw[0] ^ 1]) + raw[1:]
        return raw


class SnapshotTests(unittest.TestCase):
    def test_valid_link_reads_representation_and_current_runtime_separately(self):
        result = probe.capture(Memory(), 'fixture')
        self.assertTrue(result['read_only'])
        self.assertFalse(result['remote_control_enabled'])
        self.assertEqual(result['deployed_drone_candidate']['descriptor']['goid'], 525)
        self.assertEqual(result['deployed_drone_candidate']['behavior']['raw_state_number'], 3)
        self.assertEqual(result['distance_m'], 5)
        self.assertEqual(result['heat_components'][0]['heat'], 12.5)
        self.assertEqual(result['heat_components'][0]['reserve'], 3)
        self.assertNotEqual(result['backpack']['state']['base64'], result['backpack']['local_runtime']['base64'])

    def test_unmapped_weapon_targeting_is_not_required_for_rover(self):
        result = probe.capture(Memory(), 'fixture')
        self.assertIn('weapon_targeting_unavailable', result['deployed_drone_candidate'])

    def test_unsupported_binary_refuses_before_component_reads(self):
        reader = Memory()
        reader.word(reader.game + 136, 0)
        with self.assertRaisesRegex(ValueError, 'Unsupported game build'):
            probe.capture(reader, 'fixture')
        self.assertEqual(reader.reads, 1)

    def test_instruction_guard_failure(self):
        reader = Memory()
        reader.put(reader.game + 0x548F84, b'\x90' * 7)
        with self.assertRaisesRegex(ValueError, 'locator guard failed'):
            probe.capture(reader, 'fixture')

    def test_empty_collection_rejects_a_stale_dense_mapping(self):
        reader = Memory()
        reader.word(reader.inventory + 20, 0)
        with self.assertRaisesRegex(ValueError, 'Component index exceeds bounds'):
            probe.capture(reader, 'fixture')

    def test_collection_budget_is_enforced(self):
        reader = Memory()
        reader.word(reader.inventory + 20, 513)
        with self.assertRaisesRegex(ValueError, 'Component collection exceeds bounds'):
            probe.capture(reader, 'fixture')

    def test_snapshot_rejects_root_changed_after_capture(self):
        reader = Memory()
        reader.changed = reader.game + 0x3326460
        with self.assertRaisesRegex(ValueError, 'Identity changed during snapshot'):
            probe.capture(reader, 'fixture')


if __name__ == '__main__':
    unittest.main()
