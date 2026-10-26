#!/usr/bin/env bash
# Yeni local manifest uret + repo init + tam dogrulama.
set -u
cd /mnt/src

echo "=== 1) local manifest uretiliyor ==="
python3 /tmp/generate_local_manifest.py /mnt/src

echo
echo "=== 2) repo init ==="
repo init -u https://github.com/Evolution-X/manifest -b bka --depth=1 2>&1 | tail -4

echo
echo "=== 3) repo sync -c ==="
repo sync -c -j4 > /mnt/out/sync-final.log 2>&1
RC=$?
echo "  rc=$RC"
tail -6 /mnt/out/sync-final.log
if [ $RC -ne 0 ]; then
  echo "--- kalan hatalar ---"
  grep -oE "on [a-zA-Z0-9_/.+-]+ failed|unsupported checkout state|not a git repository: '[^']+'|object file [^ ]+ is empty|couldn't find remote ref[^']*'?" /mnt/out/sync-final.log | sort -u | head -12
fi
exit $RC
