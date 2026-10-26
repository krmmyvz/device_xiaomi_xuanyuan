#!/usr/bin/env bash
# Xuanyuan ROM build icin gereken TUM duzeltmeleri tek yerde uygular.
#
# Bu pipeline, asagidaki sorun siniflarini kapatir:
#
#  1) Vendor Android.bp adlandirmasi
#     fix_aidl_vendor_refs.py '_vendor' eklerini kaldirip platform adiyla
#     degistirir. Bu iki hata sinifi uretir:
#       a) ISIM CAKISMASI: ayni modul adi hem vendor/ hem system_ext/
#          partition'inda tanimli -> "module X already defined"
#       b) PARTITION MISMATCH: platform kaynak modulu 'system' partition'inda,
#          vendor prebuilt'i 'vendor' partition'inda -> "partition is different"
#     Cozum: upstream adlandirmasina don (175 '_vendor' modul) + platformda
#     karsiligi OLMAYAN 11 prebuilt 'xiaomi.prebuilt.' onekiyle ayrilir.
#
#  2) Platform <-> vendor namespace cakismasi
#     Cihaz agaci 'vendor/xiaomi/xuanyuan' namespace'ini import eder; ayni
#     adlari tasiyan platform modulleri "found in multiple namespaces" hatasi
#     verir. Cozum: vendor prebuilt'leri yeniden adlandirilir (1) veya
#     platformdaki kaynak moduller kaldirilir (stok blob kullanilir).
#
#  3) PRODUCT_PACKAGES / PRODUCT_COPY_FILES tutarliligi
#     - hicbir projede tanimli olmayan moduller listeden SILINIR
#     - yeniden adlandirilan modullerin kayitlari guncellenir
#     - yanlis yol / eksik kaynakli COPY_FILES kayitlari duzeltilir
#
#  4) Platform AIDL'lerinin vendor varyanti
#     'vendor: true' / 'vendor_available: true' olan AIDL'ler vendor
#     partition'da da '-ndk' modulu uretir; stok prebuilt ile ayni dosya
#     adini kurarlar -> "multiple rules generate". Cozum: vendor varyanti
#     kapatilir.
#
# Idempotenttir: her adim tekrar calistirilabilir.
#
# Kullanim:
#   bash scripts/apply_build_fixes.sh [--apply]
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TREE="$AOSP/device/xiaomi/xuanyuan"
APPLY=""
[ "${1:-}" = "--apply" ] && APPLY="--apply"

log() { printf '\n[==> ] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

cd "$TREE" || { err "cihaz agaci bulunamadi: $TREE"; exit 1; }

# ---------------------------------------------------------------- 1) vendor
log "1) Vendor Android.bp adlandirmasi (duplicate + partition mismatch)"
for s in fix_dup_vendor_modules.py fix_dangling_refs.py fix_prebuilt_name_shadow.py \
         fix_vendor_mk_refs.py; do
    if [ -f "scripts/$s" ]; then
        python3 "scripts/$s" $APPLY && ok "$s" || err "$s BASARISIZ"
    else
        err "eksik: scripts/$s"
    fi
done

# -------------------------------------------------------- 2) namespace/cihaz
log "2) Platform modullerinin devre disi birakilmasi (stok blob tercih)"
for s in disable_platform_fingerprint.py disable_platform_aidl_vendor.py; do
    if [ -f "scripts/$s" ]; then
        python3 "scripts/$s" $APPLY && ok "$s" || err "$s BASARISIZ"
    else
        err "eksik: scripts/$s"
    fi
done

# ---------------------------------------------------------- 3) device.mk
log "3) device.mk PRODUCT_PACKAGES / PRODUCT_COPY_FILES tutarliligi"
if [ -f scripts/fix_device_mk_all.py ]; then
    python3 scripts/fix_device_mk_all.py $APPLY && ok "device.mk" || err "device.mk BASARISIZ"
else
    err "eksik: scripts/fix_device_mk_all.py"
fi

# ------------------------------------------------ 4) init script rename'leri
log "4) Platform init script adlandirmasi (-xuanyuan)"
if [ -f scripts/fix_dup_init_platform.py ]; then
    python3 scripts/fix_dup_init_platform.py $APPLY && ok "init scripts" || err "init scripts BASARISIZ"
fi
if [ -f scripts/fix_vintf_clash.py ]; then
    python3 scripts/fix_vintf_clash.py $APPLY && ok "VINTF XML" || err "VINTF XML BASARISIZ"
fi

log "bitti"
