#!/usr/bin/env bash
# Kalan engelleri kaldirir:
#   1) hardware/qcom-caf/sm8750/display/hal -> checkout hatasi
#   2) packages/resources/devicesettings    -> yerel degisiklik engelliyor
set -u
cd /mnt/src

echo "=== 1) hedefleri temizle ==="
for p in hardware/qcom-caf/sm8750/display/hal packages/resources/devicesettings; do
  rm -rf "$p" ".repo/projects/$p.git"
  echo "  silindi: $p"
done

echo "=== 2) force-sync ==="
repo sync --force-sync -j2 hardware/qcom-caf/sm8750/display/hal packages/resources/devicesettings 2>&1 | tail -5

echo "=== 3) tam dogrulama ==="
repo sync -c -j4 > /mnt/out/sync-final.log 2>&1
RC=$?
echo "  rc=$RC"
tail -5 /mnt/out/sync-final.log
if [ $RC -ne 0 ]; then
  echo "--- kalan hatalar ---"
  grep -oE "on [a-zA-Z0-9_/.+-]+ failed|unsupported checkout state|not a git repository: '[^']+'|object file [^ ]+ is empty|cannot overwrite a local work tree" /mnt/out/sync-final.log | sort -u | head -12
  grep -oE "on [a-zA-Z0-9_/.+-]+ failed" /mnt/out/sync-final.log | sort -u | head -12
fi
