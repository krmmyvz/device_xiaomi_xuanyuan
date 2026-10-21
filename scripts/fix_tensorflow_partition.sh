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
# Uc blok birlikte kaldirilir:
#   - cc_library_shared "libtensorflowlite_c"   (cihaz kaynak modulunun
#     yerini Xiaomi'nin vendor prebuilt'i aliyor)
#   - cc_test "libtensorflowlite_c_api_test"
#   - cc_test "libtensorflowlite_c_test"
#
# Bu testler host_supported: true, yani yalnizca "m test" gibi ozel
# hedeflerde calisir; cihaz ROM'unun bir parcasi degildir. Bu yuzden
# kaldirilmalari cihaz build'ini etkilemez.
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
removed = []

# 1) Kaynak modül: "Standalone shared library" yorumuyla gelen blok.
pat_mod = re.compile(
    r"\n// Standalone shared library that exports the pure TensorFlow Lite C API\.\n"
    r"cc_library_shared \{\n"
    r"    name: \"libtensorflowlite_c\",.*?\n\}\n",
    re.S)
m = pat_mod.search(s)
if m:
    s = s[:m.start()] + "\n" + s[m.end():]
    removed.append("cc_library_shared libtensorflowlite_c")

# 2) Iki host testi. Govdeleri blok basindan karsilik gelen "}"a kadar.
for name in ("libtensorflowlite_c_api_test", "libtensorflowlite_c_test"):
    m = re.search(r'\ncc_test \{\n    name: "%s",.*?\n\}\n' % re.escape(name), s, re.S)
    if m:
        s = s[:m.start()] + "\n" + s[m.end():]
        removed.append("cc_test " + name)

if removed:
    open(p, "w").write(s)
    for r in removed:
        print("[+] kaldirildi: " + r)
else:
    print("[✓] kaldirilacak blok yok")
PY

# Dogrulama
if grep -q 'name: "libtensorflowlite_c"' "$TARGET" 2>/dev/null; then
  err "libtensorflowlite_c hala tanimli"
  exit 1
fi
if grep -qE 'name: "libtensorflowlite_c(_api_test|_test)"' "$TARGET" 2>/dev/null; then
  err "host testleri hala tanimli"
  exit 1
fi
ok "dogrulama: kaynak modul ve host testleri yok"
log "tamamlandi"
