"""Runtime reader fixtures. No real process memory or engine functions."""
import struct
import json
import sys
import unittest
from test_snapshot import Memory, ROOT

sys.path.insert(0, str(ROOT.parent / 'VehicleDualControl/.test-deps'))
from lupa.luajit21 import LuaRuntime


class RuntimeMemory(Memory):
    def root(self, rva):
        if rva == 0x3326558:
            manager = self.allocate(bytes(0x4900))
            self.pointer(self.game + rva, manager)
            return manager
        return super().root(rva)

    def __init__(self):
        super().__init__()
        pointer = lambda at: struct.unpack('<Q', self.read(at, 8))[0]
        root = lambda rva: pointer(self.game + rva)
        players = root(0x3326468)
        self.word(players + 132, 1)
        self.word(players + 136, 1)
        self.word(players + 936, 476)
        self.mapping(root(0x346BF98), 15871688, {476: 0})
        self.word(root(0x3326D20) + 0x53E888, 512)
        pack_root = root(0x33265E8)
        self.put(pointer(pointer(pack_root + 56)),
                 struct.pack('<QIIII', 0xAF9B683CCB6DDC02, 1290, 0x400004, 523, 0))
        self.component(0x3326DC0, 32, 56, 64, 12,
                       struct.pack('<QIIII', 0xAF9B683CCB6DDC02, 1290, 0x400004, 523, 0),
                       struct.pack('<12I', 0, 1242, *([0] * 10)))
        mount_root = root(0x3326438)
        drone = struct.pack('<QIIII', 0x5BEEC97F4C7F4AE9, 1291, 0x400002, 525, 0)
        gun = struct.pack('<QIIII', 0x2C66C201B2543D2C, 1292, 0x400003, 524, 0)
        self.put(pointer(pointer(mount_root + 56)), drone)
        self.mapping(mount_root, 32, {1291: 0})
        heat_root = root(0x3326D48)
        self.put(pointer(pointer(heat_root + 64)), gun)
        self.mapping(heat_root, 40, {1292: 0})
        brain = root(0x3326740)
        self.put(pointer(pointer(brain+88)),drone)
        self.word(pointer(brain + 96), 190)
        self.boids = root(0x3326460)
        self.motion_metadata = pointer(self.boids + 0x60)
        self.put(self.motion_metadata + 0x20, b'\1')
        self.mover = self.component(0x3326558, 0x48A0, 0x48B8, 0x48C0, 0x4888,
                                    drone, struct.pack('<4f3I', 0, 1, 0, 2, 0, 0, 0))
        self.word(self.mover + 0x4890, 1)
        self.movement_input = pointer(self.mover + 0x48C0)
        self.targeting = root(0x3326D30)
        self.put(pointer(pointer(self.targeting + 0x168)), drone)
        self.word(self.targeting + 0x144, 1)
        self.targeting_simulation = pointer(self.targeting + 0x178)
        self.targeting_replica = self.allocate(bytes(24))
        self.pointer(self.targeting + 0x180, self.targeting_replica)
        fire_rows = bytearray(0x1D0)
        struct.pack_into('<I', fire_rows, 0, 1292)
        self.fire_root = self.component(0x3326420, 48, 72, 96, 24, drone, fire_rows)
        self.word(self.fire_root + 0x20, 1)
        self.firing_input = self.allocate(bytes(0x3C))
        self.pointer(self.fire_root + 0x50, self.firing_input)
        self.look = self.component(0x33266B8, 0x30, 0x48, 0x50, 0x1C, drone, bytes(0x1C))
        self.word(self.look + 0x20, 1)
        self.look_input = pointer(self.look + 0x50)
        self.component(0x3326CE0, 48, 72, 88, 24, gun, bytes(0x3F0))
        self.word(self.game + 0x3483C20, 0)
        self.camera = root(0x346D560)
        self.word(self.camera + 0x1F8, 0)
        self.word(self.camera + 0x1FC, 1)
        self.word(self.camera + 0x204, 1242)
        self.word(self.camera + 0x208, 0x400001)
        self.word(self.camera + 0x200, 4)
        self.put(self.engine + 0x407851, bytes.fromhex('2b1d450a5001'))
        self.word(self.engine + 0x190829C, 0)
        self.put(self.engine + 0x40BD85, bytes.fromhex('488b5830488b1b'))
        self.put(self.engine + 0x2BD9E0, bytes.fromhex('488b81d0010000c3'))
        registry = pointer(self.engine + 0x1A100F0)
        self.unit_rows = pointer(registry + 0x88)
        self.native_resources = {}
        for index, resource in [(2, 0xCB8D6DBE2AD74BE4), (3, 0x5BEEC97F4C7F4AE9)]:
            obj = pointer(self.unit_rows + index * 8)
            at = self.allocate(struct.pack('<Q', resource))
            self.pointer(obj + 0x30, at)
            self.native_resources[index] = at
        self.pointer(pointer(self.unit_rows + 3 * 8) + 0x1D0, pointer(self.unit_rows + 2 * 8))
        self.pointer(pointer(self.unit_rows + 4 * 8) + 0x1D0, pointer(self.unit_rows + 1 * 8))
        self.gun_matrices = pointer(pointer(self.unit_rows + 3 * 8) + 0x88)
        self.put(self.gun_matrices + 16, struct.pack('<3f', 0, 1, 0))
        self.input = self.root(0x347CF18)
        self.buckets = self.allocate(bytes(256 * 328))
        self.pointer(self.input + 686800, self.buckets)
        self.word(self.input + 686808, 256)
        codes = [0x2001A, 0x20025, 0x20011, 0x2000C, 0x20009, 0x20000, 0x20001, 0x20002, 0x20003]
        keys = [70, 84, 32, 162, 1, 65, 68, 87, 83]
        for index, (code, vk) in enumerate(zip(codes, keys)):
            at = self.buckets + index * 328
            self.word(at, code)
            self.word(at + 4, 1)
            self.word(at + 8, (vk << 20) | 0xFF43 if vk != 1 else 0xFF44)
            self.word(at + 12, vk if vk != 1 else 32)
        actor = self.record(1242,1,476)
        self.rotator = self.component(0x33264A0,0x38,0x50,0x58,0x2C,actor,bytes(0x298))
        self.rotator_replica = self.allocate(struct.pack('<ff4B',0,0,1,0,0,0))
        self.rotator_override = self.allocate(bytes(8))
        self.pointer(self.rotator+0x60,self.rotator_replica)
        self.pointer(self.rotator+0x68,self.rotator_override)
        self.spatial = self.component(0x3326508,0x40,0x58,0x68,0x2C,drone,bytes(0x308))
        self.body_rotation = pointer(self.spatial+0x68)+0x2D0
        self.put(self.body_rotation,struct.pack('<4f',0,0,0,1))
        for at, raw in (
            (0x620C20,'498b4568f6041001740e498b4d600fb64410044288440108'),
            (0x620C7C,'4d8b65604869f198020000'),
            (0x620CE4,'43807cb408000f10b2d00200008b9ae8020000f2440f1092e00200000f11b530030000'),
            (0x5A29E2,'488b46684c69c208030000f3450f109400dc020000'),
        ):
            self.put(self.game+at,bytes.fromhex(raw))

    def mapping(self, manager, offset, mapping):
        self.maps[manager, offset] = mapping
        capacity, empty, multiplier = 64, 0xFFFFFFFF, 2
        rows = bytearray(struct.pack('<II', empty, 0) * capacity)
        for entity, dense in mapping.items():
            slot = entity * multiplier % capacity
            while struct.unpack_from('<I', rows, slot * 8)[0] != empty:
                slot = (slot + 1) % capacity
            struct.pack_into('<II', rows, slot * 8, entity, dense)
        table = self.allocate(rows)
        self.put(manager + offset, struct.pack('<QIII', table, capacity, empty, multiplier))


class RuntimeReaderTests(unittest.TestCase):
    def setUp(self):
        self.memory = RuntimeMemory()
        self.lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
        self.lua.globals().read_fixture = self.memory.read
        self.lua.execute(b'''
local ffi=require('ffi')
channel={base=0x10000000,exe_base=0x40000000,mouse_keys={[0]=1}}
function channel:read(at,size) return read_fixture(at,size) end
function channel:float(s,at) local f=ffi.new('float[1]');ffi.copy(f,s:sub(at+1,at+4),4);return tonumber(f[0]) end
function channel:vector(s,at) return {self:float(s,at),self:float(s,at+4),self:float(s,at+8)} end
''')
        load = lambda name: self.lua.execute((ROOT / 'src' / (name + '.lua')).read_bytes())
        self.native = load('reader').new(self.lua.globals().channel, load('binary'), load('flight'))
        self.families = load('reader').families

    def select_family(self, pack_hash):
        profile = self.families[pack_hash.encode()]
        pointer = lambda at: struct.unpack('<Q',self.memory.read(at,8))[0]
        root = lambda rva: pointer(self.memory.game+rva)
        for rva,back,resource in [(0x33265E8,56,pack_hash),(0x3326DC0,56,pack_hash),
                                  *[(rva,back,profile[b'body'].decode()) for rva,back in
                                    [(0x3326438,56),(0x3326740,88),(0x3326460,72),
                                     (0x3326558,0x48B8),(0x3326D30,0x168),(0x3326420,72),
                                     (0x33266B8,0x48),(0x3326508,0x58)]],
                                  (0x3326CE0,72,profile[b'weapon'].decode())]:
            at = pointer(pointer(root(rva)+back))
            self.memory.put(at,struct.pack('<Q',int(resource,16)))
        self.memory.word(pointer(root(0x3326740)+96),profile[b'behavior'])
        gun = struct.pack('<QIIII',int(profile[b'weapon'],16),1292,0x400003,524,0)
        if profile[b'feed'] == b'magazine':
            self.magazine = self.memory.component(0x3326648,32,56,80,12,gun,struct.pack('<3I',6,40,0))
            self.chambers = self.memory.allocate(bytes(16))
            self.memory.pointer(self.magazine+72,self.chambers)
            self.ammo_rows = pointer(self.magazine+80)
        else:
            self.memory.put(pointer(pointer(root(0x3326D48)+64)),gun)
        return profile

    def test_all_families_match_authored_catalog_and_behavior_evidence(self):
        evidence = json.loads((ROOT/'research/guard-dog-catalog.json').read_text())
        self.assertTrue(evidence['read_only'])
        self.assertEqual(len(evidence['entries']),5)
        self.assertEqual(len(list(self.families)),5)
        for entry in evidence['entries']:
            pack = entry['pack'][2:].lower()
            family = self.families[pack.encode()]
            self.assertEqual(family[b'body'].decode(),entry['body'][2:].lower())
            self.assertEqual(family[b'weapon'].decode(),entry['weapon'][2:].lower())
            self.assertEqual(family[b'feed'],b'heat' if entry['family'] == 'beam' else b'magazine')
            self.assertEqual(family[b'behavior'],entry['behavior'])

    def test_all_magazine_drones_resolve_without_laser_heat(self):
        for pack in ('255ebc5767d7ceec','3015626aa69f8d4d','c28da712b12e3dfa','bffcb4cd971a8eda'):
            with self.subTest(pack=pack):
                self.setUp()
                family = self.select_family(pack)
                sample = self.native.snapshot(self.native)
                self.assertEqual(sample[b'drone_name'],family[b'name'])
                self.assertEqual(sample[b'behavior_kind'],family[b'behavior'])
                self.assertEqual(sample[b'feed'],b'magazine')
                self.assertEqual(sample[b'ammo'],40)
                self.assertEqual(sample[b'reserve'],6)
                self.assertIsNone(sample[b'heat'])
                self.assertFalse(sample[b'exhausted'])
                self.assertTrue(sample[b'unit_valid']())
                self.assertTrue(sample[b'fire_valid']())

    def test_empty_magazine_checks_last_chamber_and_preserves_lease_identity(self):
        self.select_family('255ebc5767d7ceec')
        self.memory.word(self.ammo_rows+4,0)
        sample = self.native.snapshot(self.native)
        self.assertEqual(sample[b'ammo'],0)
        self.assertTrue(sample[b'exhausted'])
        self.memory.word(self.chambers+8,1)
        sample = self.native.snapshot(self.native)
        self.assertEqual(sample[b'ammo'],1)
        self.assertFalse(sample[b'exhausted'])
        self.memory.pointer(self.magazine+72,self.memory.allocate(bytes(16)))
        self.assertFalse(sample[b'unit_valid']())
        self.assertFalse(sample[b'fire_valid']())

    def test_magazine_drone_rejects_mismatched_or_recycled_weapon(self):
        self.select_family('255ebc5767d7ceec')
        owner = struct.unpack('<Q',self.memory.read(self.magazine+56,8))[0]
        descriptor = struct.unpack('<Q',self.memory.read(owner,8))[0]
        self.memory.put(descriptor,struct.pack('<Q',0x2C66C201B2543D2C))
        with self.assertRaisesRegex(Exception,'drone_weapon_resource'):
            self.native.snapshot(self.native)

    def test_unknown_backpack_is_not_treated_as_a_guard_dog(self):
        pack = struct.unpack('<Q',self.memory.read(self.memory.game+0x33265E8,8))[0]
        owners = struct.unpack('<Q',self.memory.read(pack+56,8))[0]
        descriptor = struct.unpack('<Q',self.memory.read(owners,8))[0]
        self.memory.put(descriptor,struct.pack('<Q',0x123456789ABCDEF0))
        with self.assertRaisesRegex(Exception,'guard_dog_required'):
            self.native.snapshot(self.native)

    def test_magazine_drone_rejects_invalid_ammo_reserve_and_chamber(self):
        for field,reason in (('ammo','ammo_bounds'),('reserve','reserve_bounds'),('chamber','chamber_bounds')):
            with self.subTest(field=field):
                self.setUp()
                self.select_family('255ebc5767d7ceec')
                address = {'ammo':self.ammo_rows+4,'reserve':self.ammo_rows,'chamber':self.chambers+8}[field]
                self.memory.word(address,0xFFFFFFFF)
                with self.assertRaisesRegex(Exception,reason):
                    self.native.snapshot(self.native)

    def test_magazine_drone_solo_roster_rechecked_at_capture_and_during_control(self):
        self.select_family('255ebc5767d7ceec')
        sample = self.native.snapshot(self.native)
        players = struct.unpack('<Q',self.memory.read(self.memory.game+0x3326468,8))[0]
        for field in (132,136):
            self.memory.word(players+field,2)
            self.assertFalse(sample[b'unit_valid']())
            with self.assertRaisesRegex(Exception,'solo_required'):
                self.native.snapshot(self.native)
            self.memory.word(players+field,1)
        replacement = self.memory.allocate(bytes(1024))
        self.memory.pointer(self.memory.game+0x3326468,replacement)
        self.assertFalse(sample[b'unit_valid']())

    def test_complete_snapshot_uses_game_object_id_not_engine_unit(self):
        sample = self.native.snapshot(self.native)
        self.assertEqual(sample[b'drone_entity'], 1291)
        self.assertEqual(sample[b'drone_unit'], 0x400002)
        self.assertEqual(sample[b'drone_goid'], 525)
        self.assertEqual(sample[b'gun_goid'], 524)
        self.assertTrue(sample[b'fire_valid']())
        self.assertTrue(sample[b'camera_valid']())
        self.assertTrue(sample[b'unit_valid']())
        self.assertEqual(sample[b'motion'][b'enabled'], b'\1')
        self.assertTrue(sample[b'motion'][b'valid']())
        self.assertTrue(sample[b'movement'][b'valid']())
        self.assertEqual(sample[b'movement'][b'address'], self.memory.movement_input)
        self.assertEqual(struct.unpack('<4f', sample[b'movement'][b'original']), (0, 1, 0, 2))
        self.assertEqual(sample[b'node_index'], 0)
        self.assertEqual(sample[b'drone_engine_resource'], b'cb8d6dbe2ad74be4')
        self.assertEqual(sample[b'gun_engine_resource'], b'5beec97f4c7f4ae9')
        self.assertTrue(sample[b'graph_valid']())
        self.assertTrue(sample[b'targeting'][b'valid']())
        self.assertEqual(sample[b'targeting'][b'flags'], self.memory.targeting_replica + 16)
        self.assertEqual(sample[b'targeting'][b'position'], self.memory.targeting_simulation + 8)
        self.assertTrue(sample[b'aim_motor'][b'valid']())
        self.assertEqual(sample[b'aim_motor'][b'position'], self.memory.look_input)
        self.assertEqual(sample[b'aim_motor'][b'engaged'], self.memory.look_input + 0x18)
        self.assertEqual(sample[b'aim_motor'][b'fire_position'], self.memory.firing_input)
        self.assertEqual(list(sample[b'weapon_forward'].values()), [0, 1, 0])
        self.assertIsNone(sample[b'drone_parent_unit'])
        self.assertEqual(sample[b'pack_parent_unit'], sample[b'actor_unit'])
        self.assertEqual(sample[b'gun_parent_unit'], sample[b'drone_unit'])

    def test_rotation_inputs_are_owned_and_body_rotator_is_optional(self):
        sample = self.native.snapshot(self.native)
        controls = self.native.rotation_controls(self.native,sample)
        self.assertIsNone(controls[b'actor'])
        self.assertIsNone(controls[b'body'])
        self.assertEqual(controls[b'rotation'],self.memory.body_rotation)
        self.assertTrue(controls[b'valid']())
        self.memory.put(self.memory.rotator_replica+8,b'\2')
        self.assertTrue(controls[b'valid']())  # Actor rotation is no longer an input to this path.
        self.memory.pointer(self.memory.rotator+0x60,self.memory.allocate(bytes(12)))
        self.assertTrue(controls[b'valid']())
        self.assertIsNone(self.native.rotation_controls(self.native,sample)[b'actor'])

    def test_rotation_refuses_bad_code_flags_quaternion_and_foreign_owner(self):
        sample = self.native.snapshot(self.native)
        original = self.memory.read(self.memory.game+0x620C20,1)
        self.memory.put(self.memory.game+0x620C20,b'\0')
        with self.assertRaisesRegex(Exception,'rotation_code_changed'):
            self.native.rotation_controls(self.native,sample)
        self.memory.put(self.memory.game+0x620C20,original)
        for quaternion in [(0,0,0,0),(float('nan'),0,0,1)]:
            self.memory.put(self.memory.body_rotation,struct.pack('<4f',*quaternion))
            with self.assertRaisesRegex(Exception,'body_pose_rotation_invalid'):
                self.native.rotation_controls(self.native,sample)
        self.memory.put(self.memory.body_rotation,struct.pack('<4f',0,0,0,1))
        pointer = lambda at: struct.unpack('<Q',self.memory.read(at,8))[0]
        descriptor = pointer(pointer(self.memory.spatial+0x58))
        self.memory.word(descriptor+12,0x400001)
        with self.assertRaisesRegex(Exception,'body_pose_owner_changed'):
            self.native.rotation_controls(self.native,sample)

    def test_rotation_revalidation_rejects_reused_spatial_rows(self):
        sample = self.native.snapshot(self.native)
        controls = self.native.rotation_controls(self.native,sample)
        self.memory.pointer(self.memory.spatial+0x68,self.memory.allocate(bytes(0x308)))
        self.assertFalse(controls[b'valid']())

    def test_present_body_rotator_is_checked_independently(self):
        sample = self.native.snapshot(self.native)
        actor = self.memory.record(1242,1,476)
        drone = sample[b'brain'][b'descriptor']
        root = self.memory.rotator
        self.memory.mapping(root,0x38,{1242:0,1291:1})
        self.memory.word(root+0x2C,2)
        refs = self.memory.allocate(struct.pack('<QQ',self.memory.allocate(actor),self.memory.allocate(drone)))
        self.memory.pointer(root+0x50,refs)
        self.memory.pointer(root+0x58,self.memory.allocate(bytes(2*0x298)))
        replicas = self.memory.allocate(struct.pack('<ff4B',0,0,1,0,0,0)*2)
        overrides = self.memory.allocate(bytes(16))
        self.memory.pointer(root+0x60,replicas)
        self.memory.pointer(root+0x68,overrides)
        controls = self.native.rotation_controls(self.native,sample)
        self.assertEqual(controls[b'body'][b'enabled'],replicas+12+8)
        self.assertEqual(controls[b'body'][b'override'],overrides+8+4)
        self.assertTrue(controls[b'body'][b'valid']())
        self.memory.put(replicas+12+8,b'\2')
        with self.assertRaisesRegex(Exception,'rotator_flag_invalid'):
            self.native.rotation_controls(self.native,sample)
        self.memory.put(replicas+12+8,b'\1')
        self.memory.word(root+0x2C,1)
        self.assertFalse(controls[b'body'][b'valid']())

    def test_rotation_resolver_follows_same_owner_storage_not_reused_identity(self):
        sample = self.native.snapshot(self.native)
        controls = self.native.rotation_controls(self.native,sample)
        pointer = lambda at: struct.unpack('<Q',self.memory.read(at,8))[0]
        rows = pointer(self.memory.spatial+0x68)
        new_rows = self.memory.allocate(self.memory.read(rows,0x308))
        self.memory.pointer(self.memory.spatial+0x68,new_rows)
        self.assertFalse(controls[b'valid']())
        refreshed = controls[b'resolve']()
        self.assertEqual(refreshed[b'rotation'],new_rows+0x2D0)
        self.assertEqual(refreshed[b'key'],controls[b'key'])
        self.assertTrue(refreshed[b'valid']())
        descriptor = pointer(pointer(self.memory.spatial+0x58))
        self.memory.word(descriptor+12,0x800002)
        with self.assertRaisesRegex(Exception,'body_pose_owner_changed'):
            controls[b'resolve']()

    def test_unrelated_registry_growth_or_relocation_does_not_force_exit(self):
        sample = self.native.snapshot(self.native)
        controls = self.native.rotation_controls(self.native,sample)
        pointer = lambda at: struct.unpack('<Q',self.memory.read(at,8))[0]
        registry = pointer(self.memory.engine+0x1A100F0)
        gens = pointer(registry+0xA0)
        rows = self.memory.allocate(self.memory.read(self.memory.unit_rows,40)+bytes(8))
        new_gens = self.memory.allocate(self.memory.read(gens,5)+b'\1')
        self.memory.put(registry+0x88,struct.pack('<QQIIQ',rows,123,6,7,new_gens))
        self.assertTrue(controls[b'valid']())
        self.assertTrue(sample[b'unit_valid']())
        self.assertEqual(controls[b'resolve']()[b'key'],controls[b'key'])
        self.memory.put(new_gens+2,b'\2')
        self.assertFalse(controls[b'valid']())
        self.assertFalse(sample[b'unit_valid']())
        with self.assertRaisesRegex(Exception,'rotation_owner_changed'):
            controls[b'resolve']()

    def test_same_reference_with_changed_native_object_is_not_the_same_owner(self):
        sample = self.native.snapshot(self.native)
        controls = self.native.rotation_controls(self.native,sample)
        self.memory.pointer(self.memory.unit_rows+16,self.memory.allocate(bytes(0x1E8)))
        self.assertFalse(controls[b'valid']())
        with self.assertRaisesRegex(Exception,'rotation_owner_changed'):
            controls[b'resolve']()

    def test_cleanup_ownership_key_excludes_storage_address_not_generation(self):
        sample = self.native.snapshot(self.native)
        pointer = lambda at: struct.unpack('<Q',self.memory.read(at,8))[0]
        brain = pointer(self.memory.game+0x3326740)
        rows = pointer(brain+96)
        self.memory.pointer(brain+96,self.memory.allocate(self.memory.read(rows,0x1F8)))
        fresh = self.native.snapshot(self.native)
        self.assertNotEqual(fresh[b'token'],sample[b'token'])
        self.assertEqual(fresh[b'ownership_key'],sample[b'ownership_key'])
        self.assertFalse(sample[b'brain'][b'valid']())
        self.assertTrue(fresh[b'unit_valid']())
        descriptor = pointer(pointer(brain+88))
        self.memory.word(descriptor+12,0x800002)
        changed = self.native.snapshot(self.native)
        self.assertNotEqual(changed[b'ownership_key'],fresh[b'ownership_key'])

    def test_docked_body_parent_is_owned_backpack_not_distance_or_ai_enum(self):
        pointer = lambda at: struct.unpack('<Q', self.memory.read(at, 8))[0]
        body = pointer(self.memory.unit_rows + 2 * 8)
        pack = pointer(self.memory.unit_rows + 4 * 8)
        self.memory.pointer(body + 0x1D0, pack)
        sample = self.native.snapshot(self.native)
        self.assertEqual(sample[b'drone_parent_unit'], sample[b'pack_unit'])
        self.assertTrue(sample[b'graph_valid']())
        self.memory.pointer(body + 0x1D0, 0)
        self.assertFalse(sample[b'graph_valid']())
        self.assertTrue(sample[b'unit_valid']())  # Detachment does not change owned identity.
        self.assertIsNone(self.native.snapshot(self.native)[b'drone_parent_unit'])

    def test_motion_pause_does_not_invalidate_owned_component(self):
        sample = self.native.snapshot(self.native)
        self.assertEqual(sample[b'motion'][b'address'], self.motion_address())
        self.memory.put(self.motion_address(), b'\0')
        self.assertTrue(sample[b'motion'][b'valid']())
        self.assertTrue(sample[b'unit_valid']())
        self.assertEqual(self.native.snapshot(self.native)[b'motion'][b'enabled'], b'\0')

    def motion_address(self):
        return self.memory.motion_metadata + 0x20

    def test_mover_input_changes_do_not_change_identity(self):
        sample = self.native.snapshot(self.native)
        self.memory.put(self.memory.movement_input, struct.pack('<4f', 1, 0, 0, 8))
        self.assertTrue(sample[b'movement'][b'valid']())
        self.assertTrue(sample[b'unit_valid']())
        self.assertEqual(struct.unpack('<4f', self.native.snapshot(self.native)[b'movement'][b'original']),
                         (1, 0, 0, 8))

    def test_manual_target_changes_preserve_component_identity(self):
        sample = self.native.snapshot(self.native)
        self.memory.word(self.memory.targeting_replica + 16, 2)
        self.memory.put(self.memory.targeting_simulation + 8, struct.pack('<3f', 100, 200, 300))
        self.assertTrue(sample[b'targeting'][b'valid']())
        self.assertTrue(sample[b'unit_valid']())

    def test_motor_native_outputs_do_not_invalidate_identity(self):
        sample = self.native.snapshot(self.native)
        for address in [self.memory.look_input, self.memory.firing_input]:
            self.memory.put(address, struct.pack('<3f', 10, 20, 30))
        self.memory.put(self.memory.look_input + 0x18, b'\1')
        self.assertTrue(sample[b'aim_motor'][b'valid']())
        self.assertTrue(sample[b'unit_valid']())

    def test_absent_optional_lookat_does_not_block_camera_or_movement(self):
        self.memory.mapping(self.memory.look, 0x30, {})
        sample = self.native.snapshot(self.native)
        self.assertIsNone(sample[b'aim_motor'])
        self.assertEqual(sample[b'aim_motor_reason'], b'lookat_component_absent')
        for key in [b'unit_valid', b'fire_valid', b'camera_valid', b'graph_valid']:
            self.assertTrue(sample[key]())
        self.assertTrue(sample[b'movement'][b'valid']())
        self.memory.word(self.memory.mover + 0x4890, 0)
        with self.assertRaisesRegex(Exception, 'drone_mover_not_owned'):
            self.native.snapshot(self.native)

    def test_corrupt_optional_map_is_not_treated_as_absence(self):
        self.memory.word(self.memory.look + 0x30 + 8, 0)
        with self.assertRaisesRegex(Exception, 'map_invalid'):
            self.native.snapshot(self.native)

    def test_foreign_optional_lookat_owner_is_refused(self):
        pointer = lambda at: struct.unpack('<Q', self.memory.read(at, 8))[0]
        descriptor = pointer(pointer(self.memory.look + 0x48))
        self.memory.word(descriptor + 12, 0x400003)
        with self.assertRaisesRegex(Exception, 'aim_motor_not_owned'):
            self.native.snapshot(self.native)

    def test_motor_reallocation_and_local_ownership_loss(self):
        for manager, pointer_offset, count_offset, stride in [
                (self.memory.look, 0x50, 0x20, 0x1C),
                (self.memory.fire_root, 0x50, 0x20, 0x3C)]:
            sample = self.native.snapshot(self.native)
            self.memory.pointer(manager + pointer_offset, self.memory.allocate(bytes(stride)))
            self.assertFalse(sample[b'aim_motor'][b'valid']())
            self.assertFalse(sample[b'unit_valid']())
            sample = self.native.snapshot(self.native)
            self.memory.word(manager + count_offset, 0)
            self.assertFalse(sample[b'aim_motor'][b'valid']())
            with self.assertRaisesRegex(Exception, 'aim_motor_not_owned'):
                self.native.snapshot(self.native)
            self.memory.word(manager + count_offset, 1)

    def test_weapon_forward_is_normalized_and_invalid_matrix_refused(self):
        self.memory.put(self.memory.gun_matrices + 16, struct.pack('<3f', 0, 2, 0))
        self.assertEqual(list(self.native.snapshot(self.native)[b'weapon_forward'].values()), [0, 1, 0])
        for values in [(0, 0, 0), (float('nan'), 1, 0), (0, float('inf'), 0)]:
            self.memory.put(self.memory.gun_matrices + 16, struct.pack('<3f', *values))
            with self.assertRaises(Exception):
                self.native.snapshot(self.native)

    def test_targeting_reallocation_and_owner_loss_refuse_old_addresses(self):
        for offset, size in [(0x170, 0x50), (0x178, 0xD0), (0x180, 24)]:
            sample = self.native.snapshot(self.native)
            self.memory.pointer(self.memory.targeting + offset, self.memory.allocate(bytes(size)))
            self.assertFalse(sample[b'targeting'][b'valid']())
            self.assertFalse(sample[b'unit_valid']())
        sample = self.native.snapshot(self.native)
        self.memory.word(self.memory.targeting + 0x144, 0)
        self.assertFalse(sample[b'targeting'][b'valid']())
        with self.assertRaisesRegex(Exception, 'targeting_not_owned'):
            self.native.snapshot(self.native)

    def test_targeting_metadata_change_during_capture_refuses_snapshot(self):
        self.memory.changed = self.memory.targeting + 0x180
        self.memory.observed.pop(self.memory.changed, None)
        with self.assertRaisesRegex(Exception, 'snapshot_changed'):
            self.native.snapshot(self.native)

    def test_mover_input_reallocation_or_ownership_loss_refuses_control(self):
        sample = self.native.snapshot(self.native)
        new = self.memory.allocate(bytes(0x1C))
        self.memory.pointer(self.memory.mover + 0x48C0, new)
        self.assertFalse(sample[b'movement'][b'valid']())
        self.assertFalse(sample[b'unit_valid']())
        sample = self.native.snapshot(self.native)
        self.memory.word(self.memory.mover + 0x4890, 0)
        self.assertFalse(sample[b'movement'][b'valid']())
        with self.assertRaisesRegex(Exception, 'drone_mover_not_owned'):
            self.native.snapshot(self.native)

    def test_mover_unit_reference_must_match_owned_drone(self):
        pointer = lambda at: struct.unpack('<Q', self.memory.read(at, 8))[0]
        descriptor = pointer(pointer(self.memory.mover + 0x48B8))
        self.memory.word(descriptor + 12, 0x800002)
        with self.assertRaisesRegex(Exception, 'drone_mover_not_owned'):
            self.native.snapshot(self.native)

    def test_mover_metadata_change_during_snapshot_is_refused(self):
        self.memory.changed = self.memory.mover + 0x48C0
        self.memory.observed.pop(self.memory.changed, None)
        with self.assertRaisesRegex(Exception, 'snapshot_changed'):
            self.native.snapshot(self.native)

    def test_motion_metadata_reallocation_or_ownership_loss_invalidates_lease(self):
        sample = self.native.snapshot(self.native)
        replacement = self.memory.allocate(bytes(0x38))
        self.memory.pointer(self.memory.boids + 0x60, replacement)
        self.assertFalse(sample[b'motion'][b'valid']())
        self.assertFalse(sample[b'unit_valid']())
        sample = self.native.snapshot(self.native)
        self.memory.word(self.memory.boids + 0x20, 0)
        self.assertFalse(sample[b'motion'][b'valid']())
        with self.assertRaisesRegex(Exception, 'drone_not_owned'):
            self.native.snapshot(self.native)

    def test_motion_flag_is_boolean_and_metadata_capture_is_revalidated(self):
        self.memory.put(self.motion_address(), b'\2')
        with self.assertRaisesRegex(Exception, 'drone_motion_flag_invalid'):
            self.native.snapshot(self.native)
        self.memory.put(self.motion_address(), b'\1')
        self.memory.changed = self.memory.boids + 0x60
        self.memory.observed.pop(self.memory.changed, None)
        with self.assertRaisesRegex(Exception, 'snapshot_changed'):
            self.native.snapshot(self.native)

    def test_stale_or_changed_parent_cannot_validate_docking(self):
        pointer = lambda at: struct.unpack('<Q', self.memory.read(at, 8))[0]
        pack = pointer(self.memory.unit_rows + 4 * 8)
        body = pointer(self.memory.unit_rows + 2 * 8)
        self.memory.put(self.memory.engine + 0x2BD9E0, bytes(8))
        with self.assertRaisesRegex(Exception, 'unit_parent_code_changed'):
            self.native.snapshot(self.native)
        self.memory.put(self.memory.engine + 0x2BD9E0, bytes.fromhex('488b81d0010000c3'))
        fake = self.memory.allocate(bytes(0x1E8))
        self.memory.word(fake + 8, 0x400004)
        self.memory.pointer(body + 0x1D0, fake)
        with self.assertRaisesRegex(Exception, 'unit_parent_reference_mismatch'):
            self.native.snapshot(self.native)
        self.memory.pointer(body + 0x1D0, pack)
        self.memory.observed.pop(body + 0x1D0, None)
        self.memory.changed = body + 0x1D0
        with self.assertRaisesRegex(Exception, 'unit_parent_changed'):
            self.native.snapshot(self.native)

    def test_authored_resource_is_not_the_native_engine_resource(self):
        sample = self.native.snapshot(self.native)
        self.assertNotEqual(sample[b'drone_engine_resource'], b'5beec97f4c7f4ae9')
        self.assertNotEqual(sample[b'gun_engine_resource'], b'2c66c201b2543d2c')
        self.assertTrue(sample[b'unit_valid']())
        self.memory.pointer(self.memory.native_resources[2], 0x0123456789ABCDEF)
        self.assertFalse(sample[b'unit_valid']())

    def test_native_resource_reader_rejects_changed_code_and_stale_unit(self):
        self.memory.put(self.memory.engine + 0x40BD85, bytes(7))
        with self.assertRaisesRegex(Exception, 'unit_resource_code_changed'):
            self.native.snapshot(self.native)
        self.memory.put(self.memory.engine + 0x40BD85, bytes.fromhex('488b5830488b1b'))
        obj = struct.unpack('<Q', self.memory.read(self.memory.unit_rows + 16, 8))[0]
        self.memory.word(obj + 8, 0x800002)
        with self.assertRaisesRegex(Exception, 'unit_reference_mismatch'):
            self.native.snapshot(self.native)

    def test_resource_relocated_or_changed_during_capture_is_refused(self):
        sample = self.native.snapshot(self.native)
        obj = struct.unpack('<Q', self.memory.read(self.memory.unit_rows + 16, 8))[0]
        same_hash = self.memory.allocate(self.memory.read(self.memory.native_resources[2], 8))
        self.memory.pointer(obj + 0x30, same_hash)
        self.assertFalse(sample[b'unit_valid']())
        self.memory.changed = same_hash
        with self.assertRaisesRegex(Exception, 'unit_resource_changed'):
            self.native.snapshot(self.native)

    def test_root_node_follows_runtime_index_offset(self):
        self.memory.word(self.memory.engine + 0x190829C, 1)
        sample = self.native.snapshot(self.native)
        self.assertEqual(sample[b'node_index'], 1)

    def test_unknown_node_index_or_changed_code_is_refused(self):
        self.memory.word(self.memory.engine + 0x190829C, 2)
        with self.assertRaisesRegex(Exception, 'node_index_invalid'):
            self.native.snapshot(self.native)
        self.memory.word(self.memory.engine + 0x190829C, 0)
        self.memory.put(self.memory.engine + 0x407851, bytes(6))
        with self.assertRaisesRegex(Exception, 'node_index_code_changed'):
            self.native.snapshot(self.native)

    def test_node_index_changed_during_snapshot_is_refused(self):
        self.memory.changed = self.memory.engine + 0x190829C
        with self.assertRaisesRegex(Exception, 'snapshot_changed'):
            self.native.snapshot(self.native)

    def test_binding_values_are_read_not_hardcoded(self):
        keys = self.native.bindings(self.native)
        self.assertEqual(keys[b'aim_mode'], 70)
        self.assertEqual(keys[b'backpack'], 84)
        self.assertEqual(keys[b'fire'], 1)
        self.assertEqual(keys[b'down'], 162)
        self.assertTrue(keys[b'valid']())
        self.memory.word(self.memory.buckets + 328 + 8, 0)
        self.assertTrue(keys[b'valid']())  # Our own backpack suppression is allowed.
        self.memory.word(self.memory.buckets + 4, 0)
        self.assertFalse(keys[b'valid']())  # A changed aim-mode binding is not.

    def test_input_gate_captures_gameplay_bindings_not_menu_bindings(self):
        at = self.memory.buckets + 9 * 328
        self.memory.word(at, 0x2000A)  # Reload, not one of the required drone keys.
        self.memory.word(at + 4, 1)
        self.memory.word(at + 8, (82 << 20) | 0xFF43)
        menu = self.memory.buckets + 10 * 328
        self.memory.word(menu, 0x10000)
        self.memory.word(menu + 4, 1)
        self.memory.word(menu + 8, (27 << 20) | 0xFF43)
        keys = self.native.bindings(self.native)
        addresses = {item[1] for item in keys[b'input_entries'].values()}
        self.assertIn(at + 4, addresses)
        self.assertNotIn(self.memory.buckets + 328 + 4, addresses)  # Separate backpack lease.
        self.assertNotIn(menu + 4, addresses)
        self.memory.word(at + 4, 0)
        self.assertFalse(keys[b'valid']())
        keys[b'inputs_suppressed'] = True
        for address in addresses:
            self.memory.word(address, 0)
        self.assertTrue(keys[b'valid']())
        self.assertEqual(keys[b'forward'], 87)
        self.assertEqual(keys[b'fire'], 1)  # Physical VKs are retained for remote input.
        self.memory.word(at + 12, 777)
        self.assertFalse(keys[b'valid']())

    def test_each_lease_restores_independently_of_another_binding_edit(self):
        keys = self.native.bindings(self.native)
        entries = list(keys[b'input_entries'].values())
        movement = next(item for item in entries if item[1] == self.memory.buckets + 5 * 328 + 4)
        aim = next(item for item in entries if item[1] == self.memory.buckets + 4)
        keys[b'inputs_suppressed'] = True
        self.memory.word(movement[1], 0)
        self.assertTrue(movement[3]())
        self.memory.word(aim[1] + 4, 1234)
        self.assertFalse(keys[b'valid']())
        self.assertFalse(aim[3]())
        self.assertTrue(movement[3]())  # Unchanged entries must remain restorable.
        self.memory.pointer(self.memory.input + 686800, self.memory.allocate(bytes(256 * 328)))
        self.assertFalse(movement[3]())  # Never write to a replaced binding table.

    def test_mouse_axes_are_unbound_by_count_without_rewriting_axis_payloads(self):
        for index, code in enumerate(range(0x20004, 0x20008), 10):
            at = self.memory.buckets + index * 328
            self.memory.word(at, code)
            self.memory.word(at + 4, 1)
            self.memory.word(at + 8, (6 << 20) | 0xFF84)
            self.memory.word(at + 12, 13)
        keys = self.native.bindings(self.native)
        entries = {item[1]: item for item in keys[b'input_entries'].values()}
        keys[b'inputs_suppressed'] = True
        for index in range(10, 14):
            at = self.memory.buckets + index * 328
            self.assertIn(at + 4, entries)
            self.memory.word(at + 4, 0)
            self.assertTrue(entries[at + 4][3]())
            self.assertEqual(self.memory.read(at + 8, 4), struct.pack('<I', (6 << 20) | 0xFF84))
        self.assertTrue(keys[b'valid']())
        self.memory.word(self.memory.buckets + 10 * 328 + 4, 2)
        self.assertFalse(keys[b'valid']())

    def test_stratagem_binding_is_not_required(self):
        at = self.memory.buckets + 9 * 328
        self.memory.word(at, 0x50000)
        self.memory.word(at + 4, 0)
        keys = self.native.bindings(self.native)
        self.assertEqual(keys[b'aim_mode'], 70)
        self.assertIsNone(keys[b'stratagem'])
        self.assertTrue(keys[b'valid']())
        self.memory.word(at + 4, 999)
        self.assertFalse(keys[b'valid']())  # Optional stratagem entries are tracked for input suppression.

    def test_missing_aim_mode_binding_is_refused_not_guessed(self):
        self.memory.word(self.memory.buckets, 0x50000)
        with self.assertRaisesRegex(Exception, 'binding_missing_aim_mode'):
            self.native.bindings(self.native)

    def test_multiplayer_is_refused(self):
        players = struct.unpack('<Q', self.memory.read(self.memory.game + 0x3326468, 8))[0]
        self.memory.word(players + 132, 2)
        with self.assertRaisesRegex(Exception, 'solo_required'):
            self.native.snapshot(self.native)

    def test_thumb_key_uses_engine_supplied_mouse_id_not_a_default_key(self):
        self.memory.word(self.memory.buckets + 8, (4 << 20) | 0xFF44)
        self.memory.word(self.memory.buckets + 12, 36)
        self.lua.globals().channel[b'mouse_keys'][4] = 6
        keys = self.native.bindings(self.native)
        self.assertEqual(keys[b'aim_mode'], 6)
        self.assertEqual(keys[b'backpack'], 84)
        self.assertTrue(keys[b'valid']())

    def test_lost_weapon_component_blocks_native_fire(self):
        sample = self.native.snapshot(self.native)
        rows = struct.unpack('<Q', self.memory.read(self.memory.fire_root + 96, 8))[0]
        self.memory.word(rows, 3333)
        self.assertFalse(sample[b'fire_valid']())

    def test_unit_ownership_rechecked_after_snapshot(self):
        sample = self.native.snapshot(self.native)
        inventory = struct.unpack('<Q', self.memory.read(self.memory.game+0x3326738,8))[0]
        rows = struct.unpack('<Q', self.memory.read(inventory+80,8))[0]
        self.memory.word(rows+12,0)
        self.assertFalse(sample[b'unit_valid']())

    def test_multiplayer_join_invalidates_existing_unit_lease(self):
        sample = self.native.snapshot(self.native)
        players = struct.unpack('<Q', self.memory.read(self.memory.game+0x3326468,8))[0]
        self.memory.word(players+132,2)
        self.assertFalse(sample[b'unit_valid']())

    def test_camera_reused_by_another_actor_is_not_restorable(self):
        sample = self.native.snapshot(self.native)
        self.memory.word(self.memory.camera + 0x204, 999)
        self.assertFalse(sample[b'camera_valid']())


if __name__ == '__main__':
    unittest.main()
