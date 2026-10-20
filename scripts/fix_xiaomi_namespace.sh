#!/usr/bin/env bash
# hardware/xiaomi namespace duzeltmesi.
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
# Ama bu namespace'i tanimlayan bir soong_namespace blogu hicbir yerde
# yok. Kaynak proje (xiaomi-8750/android_hardware_xiaomi, branch beryl)
# Android.bp dosyasi BOS bir blok iceriyor:
#
#     soong_namespace {
#     }
#
# "name" alani olmayan bir soong_namespace blogu namespace OLUSTURMAZ,
# bu yuzden import cozulemiyor:
#
#   error: device/xiaomi/xuanyuan/Android.bp:6:1: module "soong_namespace":
#          namespace hardware/xiaomi does not exist
#
# COZUM
# -----
# Soong'da bir namespace'i iki yolla cozebilirsin:
#   1) soong_namespace { name: "X" } blogu - bu AOSP'de GECERSIZ:
#      "error: module \"soong_namespace\": unrecognized property \"name\""
#   2) X yolunu PRODUCT_SOONG_NAMESPACES'e eklemek - Soong bu yolu
#      namespace olarak tanir ve imports listesi cozulur.
#
# Bu script 2. yolu kullanir: device.mk icindeki PRODUCT_SOONG_NAMESPACES
# listesine "hardware/xiaomi" ekler. hardware/xiaomi/Android.bp ise
# upstream ile ayni sekilde name'siz birakilir.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
DEVICE_MK="$AOSP/device/xiaomi/xuanyuan/device.mk"
HW_BP="$AOSP/hardware/xiaomi/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

# --- 1) PRODUCT_SOONG_NAMESPACES'e hardware/xiaomi ekle --------------------
if [ ! -f "$DEVICE_MK" ]; then
  err "bulunamadi: $DEVICE_MK"; exit 1
fi

if grep -qE '^\s*hardware/xiaomi\s*\\?\s*$' "$DEVICE_MK" 2>/dev/null; then
  ok "PRODUCT_SOONG_NAMESPACES zaten hardware/xiaomi iceriyor"
else
  python3 - "$DEVICE_MK" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
m = re.search(r'(PRODUCT_SOONG_NAMESPACES\s*\+?=)(.*?)(\n\n)', s, re.S)
if not m:
    raise SystemExit("PRODUCT_SOONG_NAMESPACES blogu bulunamadi")
head, body, tail = m.group(1), m.group(2), m.group(3)
lines = [l for l in body.splitlines() if l.strip()]
if not lines:
    raise SystemExit("bos namespace blogu")
last = lines[-1].rstrip()
if last.endswith("\\"):
    last = last + "\n    hardware/xiaomi"
else:
    last = last + " \\\n    hardware/xiaomi"
# body'daki son satiri degistir
newbody = body.rstrip("\n")
newbody = newbody[:newbody.rfind("\n")+1] + last + "\n"
s = s[:m.start()] + head + newbody + tail + s[m.end():]
open(p, "w").write(s)
PY
  ok "PRODUCT_SOONG_NAMESPACES'e hardware/xiaomi eklendi"
fi

# --- 2) hardware/xiaomi/Android.bp'yi name'siz halde birak ----------------
if [ -f "$HW_BP" ]; then
  if grep -qE 'name\s*:' "$HW_BP" 2>/dev/null; then
    printf 'soong_namespace {\n}\n' > "$HW_BP"
    ok "hardware/xiaomi/Android.bp duzeltildi (gecersiz 'name' alani kaldirildi)"
  else
    ok "hardware/xiaomi/Android.bp zaten duzgun"
  fi
fi

# --- 3) Dogrulama -------------------------------------------------------
if grep -q 'hardware/xiaomi' "$DEVICE_MK" 2>/dev/null; then
  ok "dogrulama: device.mk hardware/xiaomi iceriyor"
else
  err "dogrulama basarisiz"; exit 1
fi

log "tamamlandi"
