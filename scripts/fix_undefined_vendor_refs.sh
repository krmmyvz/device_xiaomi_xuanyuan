#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan: tanimsiz modullere olan referanslari kaldirir.
#
# SORUN
# -----
# Android 16'da bazi HIDL HAL'ler tamamen kaldirildi - ornegin FM HAL'i
# (com.dsi.ant, vendor.qti.hardware.fm). Xiaomi'nin vendor agaci bu
# modullere hala referans veriyor:
#
#   error: "libbt-hidlclient" depends on undefined module
#          "vendor.qti.hardware.fm@1.0".
#   Or did you mean ["vendor.qti.hardware.pal@1.0" ...]?
#
# Bu moduller agacin hicbir yerinde tanimli degil, dolayisiyla cihazda
# da yoklar.
#
# COZUM
# -----
# Verilen moduller icin shared_libs / static_libs girdileri kaldirilir.
#
# Bu guvenli: sadece HIDL/HAL kutuphanelerine referans veriyorlar ve
# ilgili HAL'ler cihazda mevcut degil.
#
# KULLANIM
#   bash scripts/fix_undefined_vendor_refs.sh <modul> [<modul> ...]
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

if [ $# -lt 1 ]; then
  err "kullanim: $0 <modul> [...]"
  exit 1
fi

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

python3 - "$TARGET" "$@" <<'PY'
import re, sys
p = sys.argv[1]
names = sys.argv[2:]
s = open(p).read()
total = 0
for name in names:
    # Ayni modul birden fazla yerde referans verilmis olabilir
    # (or. vendor.qti.hardware.fm@1.0 iki blokta geciyor).
    pat = r'^[ \t]*"%s",[ \t]*\n' % re.escape(name)
    s, n = re.subn(pat, '', s, flags=re.M)
    if n:
        print("[+] kaldirildi: %s (%d referans)" % (name, n))
        total += n
if total:
    open(p, "w").write(s)
else:
    print("[✓] kaldirilacak referans yok")
PY

for name in "$@"; do
  if grep -q "\"$name\"" "$TARGET" 2>/dev/null; then
    err "referans hala var: $name"
    exit 1
  fi
done
ok "dogrulama: referanslar kaldirildi"
log "tamamlandi"
