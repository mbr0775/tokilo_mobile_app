"""Inspect the actual release bundle's native ELF program headers."""
import json
import struct
import sys
import zipfile
from pathlib import Path

artifact = Path(sys.argv[1])
results = []
with zipfile.ZipFile(artifact) as archive:
    for name in archive.namelist():
        if not name.endswith('.so'):
            continue
        data = archive.read(name)
        if data[:4] != b'\x7fELF':
            raise SystemExit(f'Invalid native library: {name}')
        endian = '<' if data[5] == 1 else '>'
        is64 = data[4] == 2
        phoff = struct.unpack_from(endian + ('Q' if is64 else 'I'), data, 32 if is64 else 28)[0]
        entsize, count = struct.unpack_from(endian + 'HH', data, 54 if is64 else 42)
        alignments = []
        for index in range(count):
            position = phoff + index * entsize
            if struct.unpack_from(endian + 'I', data, position)[0] != 1:
                continue
            offset, virtual = struct.unpack_from(endian + ('QQ' if is64 else 'II'), data, position + (8 if is64 else 4))
            alignment = struct.unpack_from(endian + ('Q' if is64 else 'I'), data, position + (48 if is64 else 28))[0]
            alignments.append(alignment)
            if is64 and (alignment < 16384 or (offset - virtual) % 16384 != 0):
                raise SystemExit(f'16 KB page alignment failed: {name}')
        results.append({'library': name, 'bits': 64 if is64 else 32, 'load_alignments': alignments})
if not results:
    raise SystemExit('No native libraries found')
print(json.dumps({'artifact': artifact.name, 'native_64bit_alignment': 'passed', 'libraries': results}, indent=2))
