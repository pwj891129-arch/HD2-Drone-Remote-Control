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
        actor = m.record(1242,1,476)
        self.wield = m.component(0x3326420,48,72,96,24,actor,bytes(0x1D0))
        m.word(self.ptr(self.wield+96),1291)
        self.explosive = m.component(0x3326728,56,80,96,44,self.identity,bytes(64))
        m.word(self.explosive+40,1)
        self.explosion_rows = self.ptr(self.explosive+96)
        module = self.lua.execute((ROOT/'src/seeker_reader.lua').read_bytes())
        binary = self.lua.execute((ROOT/'src/binary.lua').read_bytes())
        self.reader = module.new(self.native,self.lua.globals().channel,binary)

    def capture(self):
        return self.reader.capture(self.reader)

    def throw(self):
        self.memory.pointer(self.obj+0x1D0,0)
        self.memory.word(self.brain+8,3)
        self.memory.put(self.motion,b'\1')

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
