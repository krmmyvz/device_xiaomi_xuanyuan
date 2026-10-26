#!/usr/bin/env bash
# Uctan uca dogrulama: guncelle -> manifest uret -> sync -> yamalar -> payload.
set -u
cd /mnt/src

echo "=== 1) cihaz agaci guncelleniyor ==="
bash -c "cd /mnt/src/device/xiaomi/xuanyuan && git fetch -q github-non-los main && git reset --hard github-non-los/main && git log --oneline -1"

echo
echo "=== 2) local manifest uretiliyor ==="
bash -c "cd /mnt/src && python3 device/xiaomi/xuanyuan/scripts/generate_local_manifest.py /mnt/src"

echo
echo "=== 3) repo init + repo sync -c ==="
bash -c "cd /mnt/src && repo init -u https://github.com/Evolution-X/manifest -b bka --depth=1 2>&1 | tail -3"
bash -c "cd /mnt/src && repo sync -c -j4 > /mnt/out/sync-verify.log 2>&1; echo \"  rc=\$?\"; tail -3 /mnt/out/sync-verify.log"

echo
echo "=== 4) patch base dogrulama ==="
bash -c "cd /mnt/src/device/xiaomi/xuanyuan && python3 scripts/verify_patch_bases.py 2>&1 | tail -3"

echo
echo "=== 5) yamalar uygulaniyor ==="
bash -c "cd /mnt/src/device/xiaomi/xuanyuan && bash scripts/apply_platform_patches.sh 2>&1 | tail -3"

echo
echo "=== 6) payload ==="
bash -c "cd /mnt/src/device/xiaomi/xuanyuan && bash scripts/sync_proprietary.sh 2>&1 | tail -4"

echo
echo "=== 7) vendor blob agaci ==="
bash -c "cd /mnt/src && bash device/xiaomi_xuanyuan/scripts/install_vendor_tree.sh --verify 2>&1 | tail -6"

echo
echo "=== 8) tailscale ==="
/usr/bin/tailscale status 2>&1 | head -2
