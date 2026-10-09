"""Native body identity classification; no process access or engine calls."""
import struct
import unittest
import test_runtime_reader as fixtures


class CharacterBodyTests(unittest.TestCase):
    def setUp(self):
        fixtures.RuntimeReaderTests.setUp(self)
        self.ptr = lambda at: struct.unpack('<Q',self.memory.read(at,8))[0]
        self.authored = self.ptr(self.memory.game+0x346BF98)
        self.at = self.authored+0xF32F18+24
        reader = self.lua.execute((fixtures.ROOT/'src/reader.lua').read_bytes())
        for guard in reader[b'body_guards'].values():
            self.memory.put(self.memory.game+guard[1],bytes.fromhex(guard[2].decode()))
        self.snapshot = self.lua.table_from({b'actor_unit': 0x400001})

    def classify(self,resource,entity=1291):
        self.memory.mapping(self.authored,0xF2AEE0,{0x400002: entity})
        self.memory.mapping(self.authored,0xF1AEB0,{entity: 1})
        self.memory.put(self.at,struct.pack('<QIIII',resource,entity,0x400002,525,1))
        result = self.native.character_body(self.native,0x400002,self.snapshot)
        return result[0] if isinstance(result,tuple) else result

    def test_body_metadata_lease_expires_when_descriptor_changes(self):
        self.classify(0x1A7FCDFF98C664B0)
        body,meta = self.native.character_body(self.native,0x400002,self.snapshot)
        self.assertTrue(body)
        self.assertTrue(meta[b'valid']())
        self.memory.word(self.at+12,0x400003)
        self.assertFalse(meta[b'valid']())

    def test_known_monster_body_is_classified_through_full_unit_reference(self):
        for resource in (0x1A7FCDFF98C664B0,0x960B48A421A3FAAA,0x965EAE5A51ACDD4A):
            with self.subTest(resource=resource):
                self.assertTrue(self.classify(resource))

    def test_player_bodies_are_not_limited_to_the_local_actor(self):
        self.assertTrue(self.native.character_body(self.native,0x400001,self.snapshot))
        self.assertTrue(self.classify(123,entity=1242))

    def test_structures_backpacks_forcefields_and_unknown_archetypes_keep_normal_margin(self):
        avatars = self.ptr(self.memory.game+0x3326D20)
        self.memory.mapping(avatars,248,{1242: 0})
        for resource in (0xAF9B683CCB6DDC02,0xD37E8D120D2836E3,0xDAC7D53FE0749F5F,
                         0x2CF3488C4845F8BD,123):
            with self.subTest(resource=resource):
                self.assertFalse(self.classify(resource))

    def test_missing_authored_entity_is_an_unknown_obstacle_not_a_body(self):
        self.memory.mapping(self.authored,0xF2AEE0,{1: 0})
        self.assertFalse(self.native.character_body(self.native,0x400002,self.snapshot))
        for unit in (0,0xFFFFFFFF,-1,1.5):
            self.assertFalse(self.native.character_body(self.native,unit,self.snapshot))

    def test_descriptor_reuse_or_unit_generation_mismatch_is_refused(self):
        self.assertTrue(self.classify(0x1A7FCDFF98C664B0))
        self.memory.word(self.at+12,0x400003)
        with self.assertRaisesRegex(Exception,'body_descriptor_changed'):
            self.native.character_body(self.native,0x400002,self.snapshot)
        self.classify(0x1A7FCDFF98C664B0)
        registry = self.ptr(self.memory.engine+0x1A100F0)
        generations = self.ptr(registry+0xA0)
        self.memory.put(generations+2,b'\2')
        with self.assertRaisesRegex(Exception,'unit_generation'):
            self.native.character_body(self.native,0x400002,self.snapshot)

    def test_changed_native_lookup_bytes_are_refused(self):
        self.classify(0x1A7FCDFF98C664B0)
        self.memory.put(self.memory.game+0x4BE704,bytes(13))
        with self.assertRaisesRegex(Exception,'body_lookup_code_changed'):
            self.native.character_body(self.native,0x400002,self.snapshot)


if __name__ == '__main__':
    unittest.main()
