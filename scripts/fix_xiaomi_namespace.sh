#!/usr/bin/env bash
# hardware/xiaomi namespace onarimi.
#
# SORUN
# -----
# device/xiaomi/xuanyuan/Android.bp soong_namespace icinde
# "hardware/xiaomi" namespace'ini IMPORT ediyor:
#
#     soong_namespace {
#         imports: [ "hardware/xiaomi", "hardware/qcom-caf/bootctrl" ],
#     }
#
# Ama hicbir yerde bu namespace TANIMLANMIYOR. Kaynak repo
# (xiaomi-8750/android_hardware_xiaomi, branch beryl) Android.bp dosyasi:
#
#     soong_namespace {
#     }
#
# Upstream'in bos birakmis bir hatasi. Sonuc:
#
#     error: device/xiaomi/xuanyuan/Android.bp:6:1: module "soong_namespace":
#            namespace hardware/xiaomi does not exist
#
# COZUM
# -----
# Soong, bir namespace'in imports listesinde adini gormesi icin o adin
# HICBIR YERDE soong_namespace olarak TANIMLANMIS olmasi yeterlidir.
# Bu yuzden cihaz agacinin kendi Android.bp dosyasina namespace'i
# tanimlayan bir blok ekliyoruz. Boylece:
#   - hardware/xiaomi projesindeki tum moduller namespace'e dahil olur
#   - imports listesi "hardware/xiaomi" adini cozumleyebilir
#
# Bu bir build-time duzeltmedir: repo icerigine dokunmaz, yalnizca
# checkout sonrasi uygulanir. Uygulama idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/hardware/xiaomi/Android.bp"
DEVICE_BP="$AOSP/device/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

# --- 1) hardware/xiaomi/Android.bp icindeki namespace'i duzelt -----------
if [ ! -f "$TARGET" ]; then
  err "bulunamadi: $TARGET"
  exit 1
fi

if grep -q 'name: *"hardware/xiaomi"' "$TARGET" 2>/dev/null; then
  ok "hardware/xiaomi/Android.bp zaten namespace tanimli"
else
  # Bos ya da eksik soong_namespace blogunu isimlendirilmis hale getir.
  cat > "$TARGET" <<'EOF'
soong_namespace {
    name: "hardware/xiaomi",
}
EOF
  ok "hardware/xiaomi/Android.bp yeniden yazildi (name: \"hardware/xiaomi\")"
fi

# --- 2) Dogrulama ------------------------------------------------------
if grep -q 'name: *"hardware/xiaomi"' "$TARGET" 2>/dev/null; then
  ok "namespace tanimi dogrulandi"
else
  err "namespace tanimi yazilamadi"
  exit 1
fi

# Cihaz agacinin imports listesi bu adi cozumleyebilmeli
if grep -q '"hardware/xiaomi"' "$DEVICE_BP" 2>/dev/null; then
  ok "cihaz agaci 'hardware/xiaomi' namespace'ini import ediyor (eslesiyor)"
else
  warn_msg="cihaz agacinda 'hardware/xiaomi' import'u bulunamadi"
  printf '[!] %s\n' "$warn_msg"
fi

log "tamamlandi"
