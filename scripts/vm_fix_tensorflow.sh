#!/usr/bin/env bash
set -u
cd /mnt/src
TREE=/mnt/src/device/xiaomi/xuanyuan
PATCH_DIR="$TREE/build-support/platform-patches"

echo "=== 1) tensorflow patch'i agacin gercek halinden yeniden uret ==="
cd /mnt/src/external/tensorflow
git diff -- tensorflow/lite/Android.bp > /tmp/tf.patch
cd /mnt/src
if [ -s /tmp/tf.patch ]; then
  cp /tmp/tf.patch "$PATCH_DIR/external__tensorflow.patch"
  echo "  yeniden uretildi: $(wc -l < "$PATCH_DIR/external__tensorflow.patch") satir"
else
  echo "  HATA: agac temiz, patch uretilemedi"
fi

echo
echo "=== 2) payload kontrolu ==="
echo "--- prebuilts/camera ---"
find "$TREE/prebuilts" -name "*.apk" -printf "%10s  %p\n" 2>/dev/null | head -5
echo "--- camera-graphs ---"
ls "$TREE/configs/camera" 2>/dev/null | head -5
echo "--- neoteric_compat ---"
ls "$TREE/neoteric_compat" 2>/dev/null | head -5

echo
echo "=== 3) yamalar tekrar uygulaniyor (tutarlilik kontrolu) ==="
cd "$TREE"
bash scripts/apply_platform_patches.sh 2>&1 | tail -6

echo
echo "=== 4) payload yeniden kurulumu ==="
bash scripts/sync_proprietary.sh 2>&1 | tail -8
