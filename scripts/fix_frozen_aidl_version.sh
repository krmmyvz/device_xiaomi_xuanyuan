#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan: frozen AIDL arayuzunde uretilmeyen V1 modulunu
# V2'ye cevirir.
#
# SORUN
# -----
# Xiaomi'nin vendor agaci "vendor.qti.hardware.display.color-V1-ndk"
# modulune bagimli. Ancak AIDL arayuzu "frozen: true" oldugu icin Soong
# yalnizca en son surumu uretir:
#
#   vendor/qcom/opensource/commonsys-intf/display/aidl/color/Android.bp
#     aidl_interface {
#         name: "vendor.qti.hardware.display.color",
#         versions_with_info: [ { version: "1" }, { version: "2" } ],
#         frozen: true,
#     }
#
# "frozen" bir AIDL arayuzunde eski surumler uretilmez, dolayisiyla
# V1 modulu hicbir LineageOS branch'inde mevcut degil ve Soong analizi
# duruyor:
#
#   error: "ppd" depends on undefined module
#          "vendor.qti.hardware.display.color-V1-ndk".
#   Module "vendor.qti.hardware.display.color-V1-ndk" can be found in
#   these namespaces: ["vendor/qcom/opensource/commonsys-intf/display"]
#   Or did you mean [... "vendor.qti.hardware.display.color-V2-ndk"]?
#
# COZUM
# -----
# Referans V1'den V2'ye cevrilir. AIDL surumlari ayni arayuzu paylasir,
# sadece surum etiketi farklidir; Android 16 vendor HAL'lerini V2 ile
# konusur, dolayisiyla V2 dogru bagimliliktir.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

if ! grep -q '"vendor.qti.hardware.display.color-V1-ndk"' "$TARGET"; then
  ok "V1 referansi zaten yok"
  exit 0
fi

python3 - "$TARGET" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
n = s.count('"vendor.qti.hardware.display.color-V1-ndk"')
s = s.replace('"vendor.qti.hardware.display.color-V1-ndk"',
              '"vendor.qti.hardware.display.color-V2-ndk"')
open(p, "w").write(s)
print("[+] %d referans V1 -> V2 cevrildi" % n)
PY

if grep -q '"vendor.qti.hardware.display.color-V1-ndk"' "$TARGET"; then
  err "V1 referansi kaldi"
  exit 1
fi
ok "dogrulama: V1 referansi yok"
log "tamamlandi"
