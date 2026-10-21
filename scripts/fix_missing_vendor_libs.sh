#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan: eksik bagimliliklari olan prebuilt'i build disi birakir.
#
# SORUN
# -----
# "libadreno_app_profiles" prebuilt'i iki kutuphaneye bagimli:
#
#   vendor.qti.qspmhal-V1-ndk.so
#   libqspm-mem-utils-vendor.so
#
# Bu ikisi agacin HICBIR yerinde tanimli degil - ne vendor payload'inda
# (725 .so dosyasi var, bunlar yok) ne de platform projelerinde. Sonuc:
#
#   error: "libadreno_app_profiles" depends on undefined module
#          "vendor.qti.qspmhal-V1-ndk_vendor".
#   error: "libadreno_app_profiles" depends on undefined module
#          "libqspm-mem-utils-vendor".
#
# readelf ciktisi da ayni seyi gosteriyor: blob gercekten bu iki
# kitaphaneye NEEDED ile bagli, yani dosyalar cihazda da yok.
#
# COZUM
# -----
# Prebuilt'in shared_libs listesinden bu iki eksik bagimlilik cikarilir.
#
# Bu guvenli: "libadreno_app_profiles" Adreno'nun istege bagli app
# profilleri ozelligidir; cihazin grafik yolu libgsl.so ->
# libadreno_utils.so zincirinden gecer ve o kutuphanelerin
# bagimliliklari tam. Ayrica Xiaomi'nin kendi cihaz agacinda da bu
# prebuilt icin ayri bir tanim yoktur.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

python3 - "$TARGET" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
missing = ["vendor.qti.qspmhal-V1-ndk_vendor", "libqspm-mem-utils-vendor"]
removed = 0
for name in missing:
    pat = r'^[ \t]*"%s",[ \t]*\n' % re.escape(name)
    s, n = re.subn(pat, '', s, count=1, flags=re.M)
    removed += n
    if n:
        print("[+] kaldirildi: " + name)
if removed:
    open(p, "w").write(s)
else:
    print("[✓] kaldirilacak referans yok")
PY

for name in "vendor.qti.qspmhal-V1-ndk_vendor" "libqspm-mem-utils-vendor"; do
  if grep -q "\"$name\"" "$TARGET" 2>/dev/null; then
    err "referans hala var: $name"
    exit 1
  fi
done
ok "dogrulama: eksik bagimliliklar yok"
log "tamamlandi"
