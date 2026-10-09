"""Decode fake light userdata in a separate local Lua VM, never in the game."""
import ctypes
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless((ROOT.parent / 'bin/lua51.dll').exists(), 'Local Lua runtime unavailable')
class EngineHandleTests(unittest.TestCase):
    def test_engine_returned_handle_decoding_does_not_construct_units(self):
        dll = ctypes.CDLL(str(ROOT.parent / 'bin/lua51.dll'))
        dll.luaL_newstate.restype = ctypes.c_void_p
        signatures = {
            'luaL_openlibs': [ctypes.c_void_p],
            'lua_pushlightuserdata': [ctypes.c_void_p, ctypes.c_void_p],
            'lua_setfield': [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p],
            'luaL_loadstring': [ctypes.c_void_p, ctypes.c_char_p],
            'lua_pcall': [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int],
            'lua_tolstring': [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)],
            'lua_settop': [ctypes.c_void_p, ctypes.c_int],
            'lua_close': [ctypes.c_void_p],
        }
        for name, args in signatures.items():
            getattr(dll, name).argtypes = args
        dll.lua_tolstring.restype = ctypes.c_char_p
        state = dll.luaL_newstate()
        self.assertTrue(state)
        source = (ROOT / 'src/platform.lua').read_bytes()
        try:
            dll.luaL_openlibs(state)
            samples = [(8397490 * 4 + 1, '8397490'), ((1073741823 * 4) + 1, '1073741823'),
                       (0, 'nil'), (1, 'nil'), (33554440, 'nil'), (33554442, 'nil'),
                       (33554443, 'nil'), (0x268FBFC49A0, 'nil')]
            for encoded, expected in samples:
                dll.lua_settop(state, 0)
                dll.lua_pushlightuserdata(state, encoded)
                dll.lua_setfield(state, -10002, b'handle')
                script = b'local Platform=(function()\n' + source + b'''\nend)()
local ffi=require('ffi')
assert(Platform.unit_ref(ffi,ffi.cast('void*',0x2000009))==nil)
assert(Platform.unit_ref(ffi,33554441)==nil)
return tostring(Platform.unit_ref(ffi,handle))
'''
                self.assertEqual(dll.luaL_loadstring(state, script), 0)
                status = dll.lua_pcall(state, 0, 1, 0)
                result = dll.lua_tolstring(state, -1, None)
                self.assertEqual(status, 0, result)
                self.assertEqual(result.decode('ascii'), expected)
        finally:
            dll.lua_close(state)


if __name__ == '__main__':
    unittest.main()
