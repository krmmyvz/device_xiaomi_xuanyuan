#!/usr/bin/env bash
# Platform yamalarini dogrula ve uygula; vendor/proprietary agacini kur.
set -u
cd /mnt/src
TREE=/mnt/src/device/xiaomi/xuanyuan

echo "=== 1) patch base SHA dogrulama ==="
cd "$TREE"
python3 scripts/verify_patch_bases.py 2>&1 | tail -12

echo
echo "=== 2) platform yamalarini uygula ==="
bash scripts/apply_platform_patches.sh 2>&1 | tail -20

echo
echo "=== 3) sonuc: patch uygulama durumu ==="
cd /mnt/src
for d in build/soong build/make frameworks/base system/core hardware/interfaces; do
  if [ -d "$d" ]; then
    st=$(git -C "$d" status --porcelain 2>/dev/null | grep -c "^ M\|^M")
    printf "  %-26s degistirilmis dosya: %s\n" "$d" "$st"
  fi
done

echo
echo "=== 4) proprietary payload (kamera APK vb.) ==="
cd "$TREE"
bash scripts/sync_proprietary.sh 2>&1 | tail -8

echo
echo "=== 5) tailscale durumu ==="
/usr/bin/tailscale status 2>&1 | head -3
