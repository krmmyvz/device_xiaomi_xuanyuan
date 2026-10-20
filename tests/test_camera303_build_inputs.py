from pathlib import Path
import hashlib
import struct
import unittest

DEVICE = Path(__file__).resolve().parents[1]
TREE = DEVICE.parents[2]


def elf_needed(data):
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected little-endian ELF64')
    offset = struct.unpack_from('<Q', data, 40)[0]
    size, count = struct.unpack_from('<HH', data, 58)
    sections = []
    for i in range(count):
        p = offset + i * size
        sections.append((struct.unpack_from('<I', data, p + 4)[0],
                         struct.unpack_from('<Q', data, p + 24)[0],
                         struct.unpack_from('<Q', data, p + 32)[0],
                         struct.unpack_from('<I', data, p + 40)[0]))
    dynamic = next(s for s in sections if s[0] == 6)
    strings = sections[dynamic[3]][1]
    result = set()
    for p in range(dynamic[1], dynamic[1] + dynamic[2], 16):
        tag, value = struct.unpack_from('<QQ', data, p)
        if tag == 1:
            start = strings + value
            result.add(data[start:data.index(b'\0', start)].decode())
    return result


class Camera303BuildInputs(unittest.TestCase):
    def test_normal_provider_loads_verified_heap_constructor(self):
        provider = TREE / 'vendor/xiaomi/xuanyuan/proprietary/odm/bin/hw/vendor.qti.camera.provider-service_64'
        self.assertIn('libcamera_heap_compat.so', elf_needed(provider.read_bytes()))

    def test_camera_graphics_inputs_are_exact_stock303(self):
        expected = {
            'hw/mapper.qti.so': '3dd9ef132c54c54e6b39a9e21b3beb66575cec9d1f8837b590e2b55a27708dba',
            'libtinyxml2.so': 'a1ccedf9d850ba83a646460532de4d2fa783c8d5a3f3643931dcee3d13eea6f0',
            'libgralloctypes.so': '2a4c66300e9d383355c731ec872bef0cadc9e2cc1120a68c2cdbf2a5502d8441',
            'libmapperutils.so': '0bad74f9c40874b44beeb1c9d40291594da51432d7e6d20c4e31a3981d7a722a',
            'vendor.qti.hardware.display.snapalloc-impl.so': '879e416d953a6c81c5d4d456c850e497e0521c9b38df798adfe39b0c22392819',
        }
        for relative, digest in expected.items():
            with self.subTest(relative=relative):
                blob = DEVICE / 'prebuilts/camera/lib64' / relative
                self.assertTrue(blob.is_file(), f'Missing camera-local stock303 input: {relative}')
                self.assertEqual(hashlib.sha256(blob.read_bytes()).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
