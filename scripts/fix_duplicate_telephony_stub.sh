#!/usr/bin/env bash
# Cihaz agacindaki yinelenen "xiaomi-telephony-stub" modulunu kaldirir.
#
# SORUN
# -----
# Xiaomi'nin upstream hardware/xiaomi/telephony/Android.bp dosyasi
# "xiaomi-telephony-stub" adli bir java_library tanimliyor:
#
#   java_library { name: "xiaomi-telephony-stub", ... }
#
# Cihaz agaci da ayni isimli bir modul tanimliyor:
#
#   device/xiaomi/xuanyuan/telephony_stub/Android.bp
#     java_library { name: "xiaomi-telephony-stub", ... }
#
# "hardware/xiaomi" PRODUCT_SOONG_NAMESPACES'e eklenince (namespace'i
# cozmek icin eklenmesi gerekiyor) iki modul farkli namespace'lerde
# ayni isimle gorunur ve Soong analizi duruyor:
#
#   error: device/xiaomi/xuanyuan/telephony_stub/Android.bp:1:1:
#          module "xiaomi-telephony-stub" variant "android_common":
#          found in multiple namespaces(hardware/xiaomi and
#          device/xiaomi/xuanyuan) when including in system partition
#
# COZUM
# -----
# Cihaz agacindaki modul kaldirilir; upstream'in modulu ayni isimle
# PRODUCT_PACKAGES'a ekleniyor (device/xiaomi/sm8750-common/common.mk).
# Iki modul ayni isi yapiyor: ikisi de TelephonyBaseUtilsStub.java
# sagliyor. Cihaz agacindaki modulun ek olarak
# com/xiaomi/telephony/Stub.java dosyasi var, ancak o sınıf agacin
# hicbir yerinde referans almadigi icin kaybi bir sey degistirmiyor.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
STUB_DIR="$AOSP/device/xiaomi/xuanyuan/telephony_stub"
BP="$STUB_DIR/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

if [ ! -f "$BP" ]; then
  ok "cihaz agacinda telephony_stub modulu zaten yok"
  exit 0
fi

# Modulun gercekten ayni isimli oldugunu dogrula (yanlis dosyayi
# silmemek icin).
if ! grep -q 'name: "xiaomi-telephony-stub"' "$BP" 2>/dev/null; then
  ok "telephony_stub farkli bir modul tanimliyor, dokunulmadi"
  exit 0
fi

rm -rf "$STUB_DIR"
if [ -d "$STUB_DIR" ]; then
  err "kaldirilamadi: $STUB_DIR"
  exit 1
fi
ok "cihaz agacindaki xiaomi-telephony-stub kaldirildi"
log "tamamlandi"
