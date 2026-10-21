#!/usr/bin/env bash
# Soong hata mesajindan eksik namespace import'larini toplar.
#
# KULLANIM
#   bash scripts/find_missing_namespace_imports.sh [hata_dosyasi]
#
# Soong, bir modulun bagimliligi gorunur olmadiginda su bicimde
# bildirim verir:
#
#   error: "qti" depends on undefined module "librmnetctl".
#   Module "qti" is defined in namespace "vendor/xiaomi/xuanyuan" which
#   can read these 6 namespaces: [...]
#   Module "librmnetctl" can be found in these namespaces:
#   ["vendor/qcom/opensource/dataservices"]
#
# "can be found in these namespaces" satirindaki adlar, vendor
# namespace'inin import listesine eklenmesi gerekenlerdir. Bu script
# bunlari cikarir ve hazir bir IMPORTS listesi olarak yazar.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
ERRLOG="${1:-$AOSP/out/error.log}"
OUT="${OUT:-$AOSP/out/missing_namespace_imports.txt}"

if [ ! -f "$ERRLOG" ]; then
  echo "hata dosyasi bulunamadi: $ERRLOG" >&2
  exit 1
fi

# "can be found in these namespaces:" satirindan sonraki satir
# [ "a" "b" ] formatinda oluyor.
python3 - "$ERRLOG" "$OUT" <<'PY'
import re, sys
errlog, out = sys.argv[1], sys.argv[2]
lines = open(errlog, errors="replace").read().splitlines()

names = []
for i, l in enumerate(lines):
    if "can be found in these namespaces" not in l:
        continue
    # Sonraki 1-2 satiri tara: [ "x" "y" ] veya bos satir + liste
    for j in range(i + 1, min(i + 4, len(lines))):
        m = re.search(r'\[([^\]]*)\]', lines[j])
        if not m:
            continue
        for n in re.findall(r'"([^"]+)"', m.group(1)):
            if n not in names:
                names.append(n)
        break

# Mevcut vendor namespace'inin importlarini cikarma
vendor_bp = None
for cand in ["/mnt/src/vendor/xiaomi/xuanyuan/Android.bp"]:
    try:
        vendor_bp = open(cand, errors="replace").read()
        break
    except OSError:
        pass

existing = set()
if vendor_bp:
    m = re.search(r'soong_namespace \{\s*\n\s*imports: \[\s*\n(.*?)\s*\],', vendor_bp, re.S)
    if m:
        existing = set(re.findall(r'"([^"]+)"', m.group(1)))

missing = [n for n in names if n not in existing]

with open(out, "w") as f:
    for n in missing:
        f.write(n + "\n")

print("bulunan namespace adedi: %d" % len(names))
print("mevcut import'lar: %d" % len(existing))
print("eklenmesi gereken: %d" % len(missing))
print()
for n in missing:
    print("  " + n)
print()
print("liste yazildi: " + out)
PY
