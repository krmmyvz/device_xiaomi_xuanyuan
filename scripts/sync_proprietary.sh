#!/usr/bin/env bash
# Proprietary payload'lari private repodan device tree'ye kopyalar (build-time).
#
#   scripts/sync_proprietary.sh [--private <yol>] [--device <yol>] [--clean]
#
# Gerekce: MiuiCamera APK'si (187 MB), stok init scriptleri ve kamera
# compat kutuphaneleri Xiaomi'nin ORIJINAL binary'leridir. Bunlar public
# repoda yayinlanamaz. Bunun yerine private repoda tutulur ve derlemeden
# once device tree'ye kopyalanir - boylece build kurallarindaki yollar
# degismez (path surgery minimumda kalir).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ROMBASE="${ROM:-${PROJECT_ROOT}/rom}"
PRIV="$ROMBASE/proprietary_vendor_xiaomi_xuanyuan"
DEV="$ROMBASE/device_xiaomi_xuanyuan"
CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --private) PRIV="$2"; shift ;;
    --device)  DEV="$2"; shift ;;
    --clean) CLEAN=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) die "Bilinmeyen arg: $1" ;;
  esac
  shift
done

[[ -d "$PRIV" ]] || die "Private repo yok: $PRIV"
[[ -d "$DEV" ]]  || die "Device tree yok: $DEV"

# LFS pointer kontrolu: private repo git-lfs kullanir. 'git lfs pull'
# calistirilmamissa APK'lar 131 baytlik stub olarak kalir ve build
# sessizce bozuk APK paketler. Bu durumda dur.
stub=$(find "$PRIV" -name "*.apk" -size -1k 2>/dev/null | head -1)
if [[ -n "$stub" ]]; then
  err "LFS icerigi eksik - '$stub' bir LFS pointer (stub), gercek dosya degil"
  dim  "  cd $PRIV && git lfs install --local && git lfs pull"
  exit 1
fi

PAYLOADS=(
  prebuilts/miuicamera
  prebuilts/camera
  prebuilts/esim
  prebuilts/stock-codecs
  prebuilts/stock
  prebuilts/product
  rootdir
  neoteric_compat
)

if (( CLEAN )); then
  log "Device tree'den payload'lar temizleniyor"
  for p in "${PAYLOADS[@]}"; do
    rm -rf "${DEV:?}/${p}"
  done
  ok "Temizlendi"
  exit 0
fi

log "Proprietary payload'lar kopyalaniyor: $PRIV -> $DEV"
COPIED=0
for p in "${PAYLOADS[@]}"; do
  src="$PRIV/$p"
  [[ -d "$src" ]] || continue
  dst="$DEV/$p"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  dim "$(printf '%-32s %s' "$p" "$(du -sh "$dst" | cut -f1)")"
  COPIED=$((COPIED+1))
done

ok "$COPIED payload kopyalandi"

# vendor blob agaci (Android.bp + proprietary/) zaten private repoda olmali
if [[ -d "$PRIV/proprietary" ]]; then
  n=$(find "$PRIV/proprietary" -type f | wc -l | tr -d ' ')
  ok "Vendor blob agaci hazir: $PRIV/proprietary ($n dosya)"
else
  warn "Vendor blob agaci yok: $PRIV/proprietary"
  dim "Uretmek icin: scripts/30_extract_vendor.sh (cihaz dump'indan)"
fi

cat <<EOF

Simdi derlemek icin:
  repo init -u https://github.com/Evolution-X/manifest -b bka
  mkdir -p .repo/local_manifests
  cp <device-tree>/build-support/evox-manifest-pinned.xml .repo/local_manifests/
  cp <device-tree>/build-support/local_manifests.xml .repo/local_manifests/
  source build/envsetup.sh
  lunch lineage_xuanyuan-bp4a-userdebug
  m evolution -j\$(nproc)
EOF
