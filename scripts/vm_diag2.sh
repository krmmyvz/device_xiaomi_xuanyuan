#!/usr/bin/env bash
set -u
cd /mnt/src

echo "=== 1) tensorflow: agac degisikligi vs patch dosyasi ==="
echo "--- agactaki degisiklik ---"
git -C external/tensorflow diff -- tensorflow/lite/Android.bp | head -40
echo "--- repodaki patch dosyasi (ilk 40 satir) ---"
head -40 /mnt/src/device/xiaomi/xuanyuan/build-support/platform-patches/external__tensorflow.patch

echo
echo "=== 2) cihaz agacindaki proprietary payload ==="
ls -la /mnt/src/device/xiaomi/xuanyuan/prebuilts/ 2>/dev/null | head -8
find /mnt/src/device/xiaomi/xuanyuan/prebuilts -name "*.apk" -exec ls -la {} \; 2>/dev/null | head -5
echo "--- neoteric_compat / camera-graphs ---"
ls /mnt/src/device/xiaomi/xuanyuan/neoteric_compat 2>/dev/null | head -5
ls /mnt/src/device/xiaomi/xuanyuan/configs/camera 2>/dev/null | head -5

echo
echo "=== 3) private repo manifest girdisi var mi ==="
grep -n "krmmyvz/proprietary" /mnt/src/device/xiaomi/xuanyuan/build-support/local_manifests.xml | head -4
echo "--- local manifestteki tum krmmyvz/xiaomi-8750 projeleri ---"
grep -oE 'name="[^"]*"' /mnt/src/device/xiaomi/xuanyuan/build-support/local_manifests.xml | head -12

echo
echo "=== 4) VM'de github ssh key var mi ==="
ls -la /home/builder/.ssh/ 2>/dev/null | head -6
