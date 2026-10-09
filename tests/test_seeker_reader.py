"""Owned held-to-thrown Seeker fixtures; no game or native calls."""
import struct
import unittest
import test_runtime_reader as fixtures
ROOT = fixtures.ROOT


class SeekerReaderTests(unittest.TestCase):
    def setUp(self):
        fixtures.RuntimeReaderTests.setUp(self)
        m = self.memory
        self.ptr = lambda at: struct.unpack('<Q',m.read(at,8))[0]
        self.root = lambda rva: self.ptr(m.game+rva)
        self.identity = struct.pack('<QIIII',0x8E325C933E55BF62,1291,0x400002,525,1)
        for rva,back in ((0x3326740,88),(0x3326460,72),(0x3326558,0x48B8),(0x3326508,0x58)):
            m.put(self.ptr(self.ptr(self.root(rva)+back)),self.identity)
        self.brain = self.ptr(self.root(0x3326740)+96)
        m.word(self.brain,4)
        m.word(self.brain+8,1)
        self.motion = m.motion_metadata+32
        m.put(self.motion,b'\0')
        self.obj = self.ptr(m.unit_rows+16)
        self.actor_obj = self.ptr(m.unit_rows+8)
        m.pointer(self.obj+0x1D0,self.actor_obj)
        m.word(self.ptr(m.inventory+80)+28,4)
        m.word(self.ptr(m.inventory+80)+16,1291)
        actor = m.record(1242,1,476)
        self.wield = m.component(0x3326420,48,72,96,24,actor,bytes(0x1D0))
        m.word(self.ptr(self.wield+96),1291)
        self.explosive = m.component(0x3326728,56,80,96,44,self.identity,bytes(64))
        m.word(self.explosive+40,1)
        self.explosion_rows = self.ptr(self.explosive+96)
        module = self.lua.execute((ROOT/'src/seeker_reader.lua').read_bytes())
        self.guidance_guards = list(module[b'guidance_guards'].values())
        for guard in self.guidance_guards:
            m.put(m.game+guard[1],bytes.fromhex(guard[2].decode()))
        binary = self.lua.execute((ROOT/'src/binary.lua').read_bytes())
        self.reader = module.new(self.native,self.lua.globals().channel,binary)

    def capture(self):
        return self.reader.capture(self.reader)

    def throw(self):
        self.memory.pointer(self.obj+0x1D0,0)
        self.memory.word(self.brain+8,3)
        self.memory.put(self.motion,b'\1')

    def test_owned_buffer_relocation_preserves_token_not_old_storage_validity(self):
        ticket = self.capture()
        self.throw()
        before = self.reader.snapshot(self.reader,ticket)
        for rva,offset,size,field in ((0x3326740,96,0x1F8,b'brain'),
                                     (0x3326460,96,56,b'motion'),
                                     (0x3326558,0x48C0,0x1C,b'movement')):
            with self.subTest(field=field):
                at = self.root(rva)+offset
                old = self.ptr(at)
                fresh = self.memory.allocate(self.memory.read(old,size))
                self.memory.pointer(at,fresh)
                after = self.reader.snapshot(self.reader,ticket)
                self.assertFalse(before[field][b'valid']())
                self.assertTrue(after[b'unit_valid']())
                self.assertNotEqual(before[field][b'address'],after[field][b'address'])
                self.assertEqual(before[b'token'],after[b'token'])
                self.assertEqual(before[b'ownership_key'],after[b'ownership_key'])
                before = after

    def test_multiplayer_toggle_applies_to_held_thrown_and_camera_ownership(self):
        players = self.root(0x3326468)
        self.options[b'allow_multiplayer'] = True
        self.memory.word(players+132,4)
        ticket = self.capture()
        self.throw()
        sample = self.reader.snapshot(self.reader,ticket)
        camera = self.reader.camera_snapshot(self.reader,ticket)
        self.assertTrue(sample[b'unit_valid']())
        self.assertTrue(sample[b'detonation_valid']())
        self.options[b'allow_multiplayer'] = False
        self.assertFalse(sample[b'unit_valid']())
        self.assertFalse(sample[b'detonation_valid']())
        self.assertTrue(camera[b'camera_valid']())
        self.assertTrue(sample[b'brain'][b'valid']())
        with self.assertRaisesRegex(Exception,'solo_required'):
            self.reader.snapshot(self.reader,ticket)
        self.options[b'allow_multiplayer'] = True
        self.assertTrue(sample[b'unit_valid']())
        self.memory.word(players+136,2)
        self.assertFalse(sample[b'unit_valid']())
        with self.assertRaisesRegex(Exception,'solo_required'):
            self.reader.snapshot(self.reader,ticket)

    def test_multiplayer_permission_never_adopts_another_seekers_owner(self):
        players = self.root(0x3326468)
        self.options[b'allow_multiplayer'] = True
        self.memory.word(players+132,2)
        ticket = self.capture()
        foreign_actor = self.ptr(self.memory.unit_rows+24)
        self.memory.pointer(self.obj+0x1D0,foreign_actor)
        with self.assertRaisesRegex(Exception,'held_seeker_changed'):
            self.capture()
        self.assertIsNotNone(ticket)

    def guide(self):
        ticket = self.capture()
        self.throw()
        m = self.memory
        m.word(self.brain+8,4)
        m.word(self.brain+0x18,1292)
        m.put(self.brain+0x1C,struct.pack('<3f',12,30,4))
        m.put(self.brain+0x78,b'\1')
        authored = self.root(0x346BF98)
        m.mapping(authored,0xF1AEB0,{1292: 1})
        self.target_record = authored+0xF32F18+24
        m.put(self.target_record,m.record(1292,3,524))
        return self.reader.snapshot(self.reader,ticket)

    def test_guidance_uses_guarded_native_selected_target_and_point(self):
        sample = self.guide()
        point = sample[b'guidance_target']()
        self.assertEqual(list(point.values()),[12,30,4])

    def test_guidance_never_follows_inactive_or_paused_behavior(self):
        sample = self.guide()
        for at,raw in ((self.brain,struct.pack('<I',0)),
                       (self.brain+8,struct.pack('<I',3)),(self.brain+0x78,b'\0')):
            with self.subTest(at=at):
                saved = self.memory.read(at,len(raw))
                self.memory.put(at,raw)
                self.assertIsNone(sample[b'guidance_target']())
                self.memory.put(at,saved)

    def test_guidance_refuses_self_owner_and_unmapped_targets(self):
        sample = self.guide()
        for entity in (0,1242,1291,0xFFFFFFFF,4000):
            with self.subTest(entity=entity):
                self.memory.word(self.brain+0x18,entity)
                self.assertIsNone(sample[b'guidance_target']())

    def test_recycled_target_unit_never_receives_guidance(self):
        sample = self.guide()
        registry = self.ptr(self.memory.engine+0x1A100F0)
        self.memory.put(self.ptr(registry+0xA0)+3,b'\2')
        self.assertIsNone(sample[b'guidance_target']())

    def test_changed_target_identity_does_not_transfer_guidance(self):
        sample = self.guide()
        self.memory.changed = self.target_record
        self.memory.observed[self.target_record] = 0
        self.assertIsNone(sample[b'guidance_target']())

    def test_guidance_refuses_changed_native_instructions(self):
        sample = self.guide()
        for guard in self.guidance_guards:
            at,raw = self.memory.game+guard[1],bytes.fromhex(guard[2].decode())
            with self.subTest(at=at):
                self.memory.put(at,bytes(len(raw)))
                self.assertIsNone(sample[b'guidance_target']())
                self.memory.put(at,raw)

    def test_guidance_refuses_invalid_target_position(self):
        sample = self.guide()
        for value in (float('nan'),float('inf'),100001):
            with self.subTest(value=value):
                self.memory.put(self.brain+0x1C,struct.pack('<3f',value,1,2))
                self.assertIsNone(sample[b'guidance_target']())

    def test_guidance_lost_on_party_join(self):
        sample = self.guide()
        self.memory.word(self.root(0x3326468)+136,2)
        self.assertIsNone(sample[b'guidance_target']())

    def test_exact_held_entity_retained_after_native_throw_and_inventory_change(self):
        ticket = self.capture()
        self.assertEqual(ticket[b'name'],b'G-60 ANTI-TANK SEEKER')
        self.assertEqual(ticket[b'entity'],1291)
        held = self.reader.snapshot(self.reader,ticket)
        self.assertFalse(held[b'deployed'])
        self.assertFalse(held[b'detonation_valid']())
        self.throw()
        self.memory.word(self.ptr(self.memory.inventory+80)+28,1)
        self.memory.word(self.ptr(self.wield+96),1292)
        sample = self.reader.snapshot(self.reader,ticket)
        self.assertTrue(sample[b'deployed'])
        self.assertTrue(sample[b'detonation_valid']())
        self.assertEqual(sample[b'kind'],b'seeker')

    def test_quick_throw_with_same_identity_never_adopts_recycled_entity(self):
        ticket = self.capture()
        self.throw()
        owners = self.ptr(self.root(0x3326740)+88)
        self.memory.word(self.ptr(owners)+12,0x800002)
        with self.assertRaisesRegex(Exception,'seeker_identity_changed'):
            self.reader.snapshot(self.reader,ticket)

    def test_other_throwables_and_not_equipped_are_ignored(self):
        self.memory.word(self.ptr(self.memory.inventory+80)+28,1)
        self.assertIsNone(self.capture())
        self.memory.word(self.ptr(self.memory.inventory+80)+28,4)
        owner = self.ptr(self.ptr(self.root(0x3326740)+88))
        self.memory.put(owner,struct.pack('<Q',0x123456789ABCDEF0))
        self.assertIsNone(self.capture())

    def test_both_seeker_resources_supported(self):
        owner = self.ptr(self.ptr(self.root(0x3326740)+88))
        self.memory.put(owner,struct.pack('<Q',0x2D398D1EC35E0838))
        self.assertEqual(self.capture()[b'name'],b'G-50 SEEKER')

    def test_solo_join_and_triggered_explosion_prevent_native_detonation(self):
        ticket = self.capture()
        self.throw()
        sample = self.reader.snapshot(self.reader,ticket)
        self.memory.put(self.explosion_rows+36,b'\1')
        self.assertFalse(sample[b'detonation_valid']())
        self.assertTrue(self.reader.snapshot(self.reader,ticket)[b'detonating'])
        self.memory.put(self.explosion_rows+36,b'\0')
        players = self.root(0x3326468)
        self.memory.word(players+136,2)
        self.assertFalse(sample[b'unit_valid']())
        self.assertFalse(sample[b'detonation_valid']())
        with self.assertRaisesRegex(Exception,'solo_required'):
            self.reader.snapshot(self.reader,ticket)

    def test_foreign_parent_and_remote_explosive_are_refused(self):
        ticket = self.capture()
        self.memory.pointer(self.obj+0x1D0,self.ptr(self.memory.unit_rows+24))
        with self.assertRaisesRegex(Exception,'seeker_foreign_parent'):
            self.reader.snapshot(self.reader,ticket)
        self.throw()
        self.memory.word(self.explosive+40,0)
        with self.assertRaisesRegex(Exception,'seeker_not_local'):
            self.reader.snapshot(self.reader,ticket)

    def test_player_death_or_replacement_does_not_transfer_ticket(self):
        ticket = self.capture()
        authored = self.root(0x346BF98)
        self.memory.word(authored+15937304+12,0x800001)
        with self.assertRaises(Exception):
            self.reader.snapshot(self.reader,ticket)

    def test_quick_capture_uses_owned_inventory_not_the_wielded_rifle(self):
        self.memory.word(self.ptr(self.memory.inventory+80)+28,1)
        self.memory.word(self.ptr(self.wield+96),1292)
        self.assertIsNone(self.capture())
        ticket = self.reader.capture(self.reader,True)
        self.assertEqual(ticket[b'entity'],1291)
        self.throw()
        self.memory.word(self.ptr(self.memory.inventory+80)+16,0)
        self.assertTrue(self.reader.snapshot(self.reader,ticket)[b'deployed'])

    def test_quick_capture_never_adopts_a_detached_or_foreign_seeker(self):
        self.throw()
        with self.assertRaisesRegex(Exception,'held_seeker_changed'):
            self.reader.capture(self.reader,True)
        self.memory.pointer(self.obj+0x1D0,self.ptr(self.memory.unit_rows+24))
        with self.assertRaisesRegex(Exception,'held_seeker_changed'):
            self.reader.capture(self.reader,True)

    def test_quick_throw_can_create_the_inventory_item_after_the_key_press(self):
        inventory = self.ptr(self.memory.inventory+80)
        self.memory.word(inventory+28,1)
        self.memory.word(inventory+16,0)
        self.assertIsNone(self.reader.capture(self.reader,True))
        self.memory.word(inventory+16,1291)
        ticket = self.reader.capture(self.reader,True)
        self.assertEqual(ticket[b'entity'],1291)
        self.throw()
        self.memory.word(self.brain+8,4)
        self.memory.word(inventory+16,0)
        sample = self.reader.snapshot(self.reader,ticket)
        self.assertTrue(sample[b'deployed'])
        self.assertEqual(sample[b'motion'][b'enabled'],b'\1')

    def test_only_verified_free_flight_states_are_deployed(self):
        ticket = self.capture()
        self.throw()
        for state in (0,1,2,5,0xFFFFFFFF):
            self.memory.word(self.brain+8,state)
            self.assertFalse(self.reader.snapshot(self.reader,ticket)[b'deployed'])
        for state in (3,4):
            self.memory.word(self.brain+8,state)
            self.assertTrue(self.reader.snapshot(self.reader,ticket)[b'deployed'])
        self.memory.pointer(self.obj+0x1D0,self.actor_obj)
        self.assertFalse(self.reader.snapshot(self.reader,ticket)[b'deployed'])

    def test_visual_cleanup_requires_an_exploded_owned_seeker(self):
        ticket = self.capture()
        self.throw()
        sample = self.reader.snapshot(self.reader,ticket)
        self.assertFalse(sample[b'explosion_valid']())
        self.memory.put(self.explosion_rows+36,b'\1')
        self.assertTrue(sample[b'explosion_valid']())
        self.memory.word(self.explosive+44,0)
        self.assertFalse(sample[b'explosion_valid']())

    def test_missing_quick_inventory_item_is_ignored(self):
        self.memory.word(self.ptr(self.memory.inventory+80)+16,0)
        self.assertIsNone(self.reader.capture(self.reader,True))

    def test_aftermath_camera_survives_drone_component_destruction(self):
        ticket = self.capture()
        self.throw()
        self.memory.word(self.root(0x3326740)+44,0)
        self.memory.word(self.explosive+44,0)
        registry = self.ptr(self.memory.engine+0x1A100F0)
        self.memory.put(self.ptr(registry+0xA0)+2,b'\2')
        camera = self.reader.camera_snapshot(self.reader,ticket)
        self.assertTrue(camera[b'camera_valid']())
        with self.assertRaises(Exception):
            self.reader.snapshot(self.reader,ticket)

    def test_aftermath_party_join_exits_but_same_actor_camera_can_restore(self):
        ticket = self.capture()
        camera = self.reader.camera_snapshot(self.reader,ticket)
        self.memory.word(self.root(0x3326468)+136,2)
        self.assertTrue(camera[b'camera_valid']())
        with self.assertRaisesRegex(Exception,'solo_required'):
            self.reader.camera_snapshot(self.reader,ticket)

    def test_aftermath_actor_or_camera_replacement_invalidates_camera(self):
        ticket = self.capture()
        camera = self.reader.camera_snapshot(self.reader,ticket)
        self.memory.word(self.root(0x346BF98)+15937304+12,0x800001)
        self.assertFalse(camera[b'camera_valid']())
        with self.assertRaises(Exception):
            self.reader.camera_snapshot(self.reader,ticket)
