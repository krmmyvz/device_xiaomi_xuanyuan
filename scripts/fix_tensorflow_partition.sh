#!/usr/bin/env bash
# external/tensorflow: libtensorflowlite_c kaynak modulunu kaldirir.
#
# SORUN
# -----
# Xiaomi'nin vendor agaci "libtensorflowlite_c" adli bir
# cc_prebuilt_library_shared tanimliyor. Soong, bir prebuilt modul icin
# kaynak modulu ararken "prebuilt_" onekiyle ayri bir modul olusturur ve
# "prebuilt_libtensorflowlite_c" adini verir. Ancak external/tensorflow
# ayni isimli kaynak modulun KENDISINI de system partition'inda uretiyor.
# Iki modul farkli partition'larda ayni ismi tasidigi icin Soong
# analizi duruyor:
#
#   error: external/tensorflow/tensorflow/lite/Android.bp:145:1:
#          module "libtensorflowlite_c" variant
#          "android_vendor_arm64_armv8-a": partition is different:
#          system(libtensorflowlite_c) != vendor(prebuilt_libtensorflowlite_c)
#
# COZUM
# -----
# Kaynak modul kaldirilir. Cihazda bu module ihtiyac yok: proje icinde
# yalnizca iki "host_supported: true" test tarafinda kullaniliyor
# (libtensorflowlite_c_api_test, libtensorflowlite_c_test), yani cihaz
# partition'inda hicbir sey onu bagimlilik olarak istemiyor. Cihazda
# Xiaomi'nin vendor prebuilt'i kullanilir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/external/tensorflow/tensorflow/lite/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

if ! grep -q 'name: "libtensorflowlite_c"' "$TARGET"; then
  ok "kaynak modul zaten yok"
  exit 0
fi

python3 - "$TARGET" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
pat = re.compile(
    r"\n// Standalone shared library that exports the pure TensorFlow Lite C API\.\n"
    r"cc_library_shared \{\n"
    r"    name: \"libtensorflowlite_c\",.*?\n\}\n",
    re.S)
m = pat.search(s)
if not m:
    raise SystemExit("kaynak modul blogu bulunamadi")
s = s[:m.start()] + "\n" + s[m.end():]
open(p, "w").write(s)
print("[+] kaynak modul kaldirildi")
PY

if grep -q 'name: "libtensorflowlite_c"' "$TARGET"; then
  err "kaynak modul hala mevcut"
  exit 1
fi
ok "dogrulama: kaynak modul yok"
log "tamamlandi"
