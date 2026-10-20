#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROM_DIR="$(cd "$DEVICE_DIR/../../.." && pwd)"
IMAGE="$DEVICE_DIR/prebuilts/vendor_boot.img"
FSTAB="$DEVICE_DIR/rootdir/etc/fstab.qcom"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

python3 "$ROM_DIR/system/tools/mkbootimg/unpack_bootimg.py" --boot_img "$IMAGE" --out "$WORK/unpacked" >/dev/null
mkdir -p "$WORK/root/first_stage_ramdisk"
cp "$FSTAB" "$WORK/root/first_stage_ramdisk/fstab.qcom"
(
  cd "$WORK/root"
  find first_stage_ramdisk -print | cpio -o -H newc -R 0:0 2>/dev/null > "$WORK/fstab.cpio"
)
lz4 -l -f "$WORK/fstab.cpio" "$WORK/fstab.ramdisk" >/dev/null 2>&1

python3 "$ROM_DIR/system/tools/mkbootimg/mkbootimg.py" \
  --header_version 4 --pagesize 4096 --base 0 \
  --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 --dtb_offset 0x01f00000 \
  --vendor_cmdline 'video=vfb:640x400,bpp=32,memsize=3072000 erofs.reserved_pages=64 swinfo.fingerprint=xuanyuan:15/OS3.0.303.0.WOAEUXM:user mtdoops.fingerprint=xuanyuan:15/OS3.0.303.0.WOAEUXM:user bootmonitor.fingerprint=xuanyuan:15/OS3.0.303.0.WOAEUXM:user minidump.stack_dump=true bootconfig' \
  --dtb "$WORK/unpacked/dtb" \
  --vendor_bootconfig "$WORK/unpacked/bootconfig" \
  --ramdisk_type platform --ramdisk_name '' --vendor_ramdisk_fragment "$WORK/unpacked/vendor_ramdisk00" \
  --ramdisk_type platform --ramdisk_name fstabfix --vendor_ramdisk_fragment "$WORK/fstab.ramdisk" \
  --vendor_boot "$WORK/new-vendor_boot.img"

python3 "$ROM_DIR/system/tools/mkbootimg/unpack_bootimg.py" --boot_img "$WORK/new-vendor_boot.img" --out "$WORK/verified" >/dev/null
cmp "$WORK/unpacked/vendor_ramdisk00" "$WORK/verified/vendor_ramdisk00"
cmp "$WORK/unpacked/dtb" "$WORK/verified/dtb"
cmp "$WORK/unpacked/bootconfig" "$WORK/verified/bootconfig"
lz4 -dc "$WORK/verified/vendor_ramdisk01" > "$WORK/verified-fstab.cpio"
mkdir "$WORK/verified-root"
(cd "$WORK/verified-root" && cpio -idmu < "$WORK/verified-fstab.cpio" 2>/dev/null)
cmp "$FSTAB" "$WORK/verified-root/first_stage_ramdisk/fstab.qcom"
test "$(stat -c %s "$WORK/new-vendor_boot.img")" -le 100663296
cp "$WORK/new-vendor_boot.img" "$IMAGE"
sha256sum "$IMAGE"
