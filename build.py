"""Build guarded Guard Dog and Seeker control; no installation or game access."""
import hashlib
import json
from pathlib import Path
import struct
import zipfile
import test

ROOT = Path(__file__).resolve().parent
RESOURCE = 'mods/codex/drone_remote_control'
PATCH = '9ba626afa44a3aa3.patch_0'
LUA_TYPE = 0xA14E8DFA2CD117E2


def murmur64(data):
    mask, multiplier = (1 << 64) - 1, 0xC6A4A7935BD1E995
    value = len(data) * multiplier & mask
    end = len(data) // 8 * 8
    for offset in range(0, end, 8):
        word = int.from_bytes(data[offset:offset + 8], 'little') * multiplier & mask
        word ^= word >> 47
        word = word * multiplier & mask
        value = (value ^ word) * multiplier & mask
    if end < len(data):
        value ^= int.from_bytes(data[end:], 'little')
        value = value * multiplier & mask
    value ^= value >> 47
    value = value * multiplier & mask
    return value ^ (value >> 47)


def archive(source):
    assert source.startswith(('-- HD2-Addon: ' + RESOURCE + '\n').encode('ascii'))
    payload = struct.pack('<II', len(source), 2) + source
    length = (192 + len(payload) + 15) // 16 * 16
    data = struct.pack('<III20sQQ24s', 0xF0000011, 1, 1, b'', length, 0, b'')
    data += struct.pack('<IIQIIII', 0, 0, LUA_TYPE, 1, 0, 16, 16)
    data += struct.pack('<7Q6I', murmur64(RESOURCE.encode('ascii')), LUA_TYPE, 192,
                        0, 0, 0, 0, len(payload), 0, 0, 16, 16, 0)
    data += b'\0' * (192 - len(data)) + payload
    return data + b'\0' * (length - len(data))


def verify(data, source):
    assert struct.unpack_from('<III', data) == (0xF0000011, 1, 1)
    assert struct.unpack_from('<Q', data, 32)[0] == len(data)
    assert struct.unpack_from('<QQQ', data, 104) == (murmur64(RESOURCE.encode('ascii')), LUA_TYPE, 192)
    assert struct.unpack_from('<I', data, 160)[0] == len(source) + 8
    assert struct.unpack_from('<II', data, 192) == (len(source), 2)
    assert data[200:200 + len(source)] == source


def main():
    report = test.run()
    source = test.runtime_source().encode('ascii')
    patch = archive(source)
    verify(patch, source)
    releases = ROOT / 'releases'
    releases.mkdir(exist_ok=True)
    packages = []
    for language, manifest_name in [('EN', 'manifest.json'), ('KO', 'manifest-ko.json')]:
        files = {'manifest.json': (ROOT / manifest_name).read_bytes(),
                 'Addon/' + PATCH: patch, 'Addon/' + PATCH + '.stream': b'',
                 'Addon/' + PATCH + '.gpu_resources': b'',
                 'README-KO.md': (ROOT / 'README-KO.md').read_bytes(),
                 'README.md': (ROOT / 'README.md').read_bytes()}
        for path in [*(ROOT / 'src').glob('*.lua'), *(ROOT / 'tests').glob('*.py'), *(ROOT / 'tests').glob('*.lua'),
                     ROOT / 'test.py', ROOT / 'build.py', ROOT / 'requirements-dev.txt',
                     ROOT / 'tools/read_drone_state.py', ROOT / 'tools/preflight.py',
                     ROOT / 'tools/observe_control.py', ROOT / 'tools/read_pose_sources.py',
                     ROOT / 'tools/check_surface_query.py',
                     ROOT / 'research/guard-dog-catalog.json']:
            files['Source/' + path.relative_to(ROOT).as_posix()] = path.read_bytes()
        files['Source/validation.json'] = (json.dumps(report, indent=2) + '\n').encode('ascii')
        files['SHA256SUMS.txt'] = ''.join(hashlib.sha256(value).hexdigest() + '  ' + name + '\n'
                                         for name, value in sorted(files.items())).encode('ascii')
        path = releases / f'Drone-Remote-Control-0.2.22-private-test-{language}.zip'
        with zipfile.ZipFile(path, 'w') as output:
            for name, value in sorted(files.items()):
                entry = zipfile.ZipInfo(name, (2026, 10, 9, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                output.writestr(entry, value)
        with zipfile.ZipFile(path) as result:
            assert result.testzip() is None and set(result.namelist()) == set(files)
            for name, value in files.items():
                assert result.read(name) == value
            verify(result.read('Addon/' + PATCH), source)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        path.with_suffix('.zip.sha256').write_text(digest + '  ' + path.name + '\n', encoding='ascii')
        packages.append({'language': language, 'path': str(path), 'sha256': digest,
                         'entries': len(files), 'verified': True})
    print(json.dumps({'packages': packages, 'auto_installed': False, 'published': False,
                      'in_game_tested': False, 'remote_control_implemented': True,
                      'scope': 'five solo Guard Dog backpacks and G-50/G-60 Seekers; not a stable release'}, indent=2))


if __name__ == '__main__':
    main()
