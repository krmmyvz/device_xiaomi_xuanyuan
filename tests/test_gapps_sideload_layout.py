from pathlib import Path
import re
import subprocess
import tempfile
import unittest

DEVICE = Path(__file__).resolve().parents[1]
TREE = DEVICE.parents[2]


class GappsSideloadLayoutTest(unittest.TestCase):
    def test_install_targets_are_writable_ext4_with_stock_package_space(self):
        board = (DEVICE / 'BoardConfig.mk').read_text()
        fstab = (DEVICE / 'rootdir/etc/fstab.qcom').read_text()
        for name in ('PRODUCT', 'SYSTEM_EXT'):
            self.assertRegex(board, rf'(?m)^BOARD_{name}IMAGE_FILE_SYSTEM_TYPE := ext4$')
        product_space = re.search(r'(?m)^BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := (\d+)$', board)
        self.assertIsNotNone(product_space)
        self.assertGreaterEqual(int(product_space.group(1)), 2_250_000_000)
        for mount in ('product', 'system_ext'):
            self.assertRegex(fstab, rf'(?m)^{mount}\s+/{mount}\s+ext4\s+')

    def test_vendor_boot_first_stage_fstab_matches_device_tree(self):
        image = DEVICE / 'prebuilts/vendor_boot.img'
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            subprocess.run(['python3', str(TREE / 'system/tools/mkbootimg/unpack_bootimg.py'), '--boot_img', str(image), '--out', str(out)], check=True, stdout=subprocess.DEVNULL)
            cpio = out / 'ramdisk.cpio'
            # Header v3 uses one vendor_ramdisk; v4 uses numbered fragments.
            fragments = sorted(out.glob('vendor_ramdisk[0-9]*'))
            # Later platform fragments override the stock first-stage fstab.
            ramdisk = fragments[-1] if fragments else out / 'vendor_ramdisk'
            with cpio.open('wb') as dst:
                subprocess.run(['lz4', '-dc', str(ramdisk)], stdout=dst, check=True)
            root = out / 'root'
            root.mkdir()
            with cpio.open('rb') as src:
                subprocess.run(['cpio', '-idmu'], cwd=root, stdin=src, stderr=subprocess.DEVNULL, check=True)
            self.assertEqual((root / 'first_stage_ramdisk/fstab.qcom').read_bytes(), (DEVICE / 'rootdir/etc/fstab.qcom').read_bytes())


if __name__ == '__main__':
    unittest.main()
