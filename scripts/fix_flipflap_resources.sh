#!/usr/bin/env bash
# packages/apps/FlipFlap: AOSPA fork'unda bulunmayan modulu referanstan cikarir.
#
# SORUN
# -----
# packages/resources/devicesettings projesi AOSPA fork'una yonlendirildi
# (hardware/xiaomi/dolby -> "co.aospa.resources" bagimliligi icin).
# AOSPA fork'unda modul adi "co.aospa.resources"; LineageOS'unki
# "org.lineageos.settings.resources" idi. LineageOS modulu kayboldu, ve
# packages/apps/FlipFlap ona bagimli oldugu icin Soong analizi duruyor:
#
#   error: packages/apps/FlipFlap/Android.bp:17:1: "FlipFlap" depends on
#          undefined module "org.lineageos.settings.resources"
#
# COZUM
# -----
# FlipFlap'in static_libs listesinden "org.lineageos.settings.resources"
# cikarilir.
#
# Bu guvenli: FlipFlap bu cihaz urununun PRODUCT_PACKAGES listesinde
# degil, yani cihaz ROM'unda derlenmiyor. Bagimlilik yalnizca FlipFlap'in
# kendi ayarlar ekranini besliyor.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/packages/apps/FlipFlap/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

if [ ! -f "$TARGET" ]; then
  ok "FlipFlap projesi yok, dokunulmadi"
  exit 0
fi

if ! grep -q '"org.lineageos.settings.resources"' "$TARGET"; then
  ok "referans zaten yok"
  exit 0
fi

python3 - "$TARGET" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(r'^[ \t]*"org\.lineageos\.settings\.resources",[ \t]*\n', '', s, count=1, flags=re.M)
if s2 == s:
    raise SystemExit("referans kaldirilamadi")
open(p, "w").write(s2)
print("[+] static_libs'tan org.lineageos.settings.resources cikarildi")
PY

if grep -q '"org.lineageos.settings.resources"' "$TARGET"; then
  err "referans hala var"
  exit 1
fi
ok "dogrulama: referans yok"
log "tamamlandi"
