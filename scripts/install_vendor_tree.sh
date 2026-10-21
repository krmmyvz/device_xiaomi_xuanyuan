#!/usr/bin/env bash
# Vendor blob agacini ve proprietary payload'larini AOSP agacina yerlestirir.
#
#   scripts/install_vendor_tree.sh [--aosp <yol>] [--from <diz>] [--vendor <yol>]
#                                  [--private <yol>] [--device <yol>]
#                                  [--link] [--skip-vendor] [--skip-private] [--verify]
#
# Iki ayri kaynak vardir:
#
#   1) VENDOR AGACI  -> vendor/xiaomi/xuanyuan
#      xiaomi-8750/proprietary_vendor_xiaomi_xuanyuan (public, branch: beryl)
#      Icerir: Android.bp (1715 prebuilt modul), xuanyuan-vendor.mk (2636 kural),
#              BoardConfigVendor.mk, proprietary/ (4021 blob, ~9 GB)
#      Varsayilan kaynak: 'repo sync' ile gelen agac.
#      --from ile yerelde uretilmis bir agac da verilebilir; --link ile
#      symlink baglanir (disk tasarrufu + guncelleme kolayligi).
#
#   2) PROPRIETARY PAYLOAD -> device/xiaomi/xuanyuan/{prebuilts,rootdir,neoteric_compat}
#      krmmyvz/proprietary_vendor_xiaomi_xuanyuan (PRIVATE)
#      Icerir: MiuiCamera APK (200 MB), kamera compat katmani, esim jar'lar,
#              stok codec'ler, Xiaomi init script'leri, fingerprint/USB shim'leri
#      Bu agac git disidir; build oncesi kopyalanir.
#
# Yapilandirma (ortam degiskenleri veya argumanlar):
#   AOSP_ROOT / ROM          platform agacinin kok dizini
#   PROJECT_ROOT             device tree'nin ust dizini
#   VENDOR_TREE              vendor agacinin yolu (varsayilan: $AOSP_ROOT/vendor/xiaomi/xuanyuan)
#   PRIVATE_TREE             private payload deposunun yolu
#                            (varsayilan: $PROJECT_ROOT/proprietary_vendor_xiaomi_xuanyuan)
#   WORK_DIR                 yerel uretilmis vendor agacinin yolu
#
# Not: PRIVATE_TREE bir git deposudur ve LFS kullanir. Ilk klon sonrasi
# 'git lfs pull' calistirilmalidir, aksi halde APK'lar 131 baytlik pointer kalir.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

AOSP="${AOSP_ROOT:-${HOME}/android/evolution}"
ROMBASE="${ROM:-${PROJECT_ROOT}/rom}"
TREE="${DEVICE_TREE_DIR}"
VENDOR="${VENDOR_TREE:-${AOSP}/vendor/xiaomi/xuanyuan}"
PRIV="${PRIVATE_TREE:-${PROJECT_ROOT}/proprietary_vendor_xiaomi_xuanyuan}"
FROM="${WORK_DIR:-}/vendor-tree"

DO_VENDOR=1; DO_PRIVATE=1; VERIFY=0; LINK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aosp)         AOSP="$2"; VENDOR="$AOSP/vendor/xiaomi/xuanyuan"; shift ;;
    --from)         FROM="$2"; shift ;;
    --vendor)       VENDOR="$2"; shift ;;
    --private)      PRIV="$2"; shift ;;
    --device)       TREE="$2"; shift ;;
    --link)         LINK=1 ;;
    --skip-vendor)  DO_VENDOR=0 ;;
    --skip-private) DO_PRIVATE=0 ;;
    --verify)       VERIFY=1 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) die "Bilinmeyen arg: $1" ;;
  esac
  shift
done

# --------------------------------------------------------------- 1) vendor agaci
if (( DO_VENDOR )); then
  if [[ -n "${FROM:-}" && -d "$FROM/proprietary" && -f "$FROM/Android.bp" ]]; then
    # --from ile verilen yerel agac
    log "Yerel vendor agaci yerlestiriliyor: $FROM"
    dim "  hedef: $VENDOR"
    if (( LINK )); then
      mkdir -p "$(dirname "$VENDOR")"
      if [[ -d "$VENDOR" && ! -L "$VENDOR" ]]; then
        rm -rf "${VENDOR}.old"; mv "$VENDOR" "${VENDOR}.old"
        ln -s "$FROM" "$VENDOR"; rm -rf "${VENDOR}.old"
      else
        rm -rf "$VENDOR"; ln -s "$FROM" "$VENDOR"
      fi
    else
      mkdir -p "$(dirname "$VENDOR")"
      rm -rf "$VENDOR"; mkdir -p "$VENDOR"
      cp -R "$FROM/." "$VENDOR/"
    fi
  else
    # varsayilan: repo sync ile gelen agac
    log "Vendor agaci dogrulaniyor: $VENDOR"
    if [[ ! -d "$VENDOR" ]]; then
      err "Vendor agaci yok: $VENDOR"
      dim  "Bu agac 'repo sync' ile gelir. Once:"
      dim  "  repo init -u https://github.com/Evolution-X/manifest -b bka"
      dim  "  cp build-support/{evox-manifest-pinned,local_manifests}.xml .repo/local_manifests/"
      dim  "  repo sync -c --depth=1"
      dim
      dim  "Alternatif: yerelde uretilmis agaci ver  --from <diz> --link"
      exit 1
    fi
  fi

  missing=()
  for f in Android.bp xuanyuan-vendor.mk BoardConfigVendor.mk proprietary; do
    [[ -e "$VENDOR/$f" ]] || missing+=("$f")
  done
  if (( ${#missing[@]} )); then
    err "Vendor agacinda eksik: ${missing[*]}"
    dim "Repo 'beryl' branch'i olmayabilir ya da checkout yarim kalmis."
    exit 1
  fi
  nb=$(find "$VENDOR/proprietary" -type f 2>/dev/null | wc -l | tr -d ' ')
  ok "Vendor agaci tam: $nb blob, $(du -sh "$VENDOR/proprietary" 2>/dev/null | cut -f1) proprietary/"
fi

# ------------------------------------------------------- 2) proprietary payload
if (( DO_PRIVATE )); then
  log "Proprietary payload kopyalaniyor"
  if [[ ! -d "$PRIV" ]]; then
    # Private depo checkout edilmemisse payload device tree'de zaten yerinde
    # mi diye bak. Yerindeyse kopyalama adimini atla.
    if [[ -d "$TREE/prebuilts/miuicamera" ]]; then
      ok "Private payload deposu yok ama payload device tree'de zaten yerinde"
      dim "  $TREE/prebuilts/miuicamera"
      PRIV=""
    else
      err "Private payload deposu yok: $PRIV"
      dim  "Clone et:"
      dim  "  git clone https://github.com/krmmyvz/proprietary_vendor_xiaomi_xuanyuan \\"
      dim  "      $PRIV"
      dim  "  cd $PRIV && git lfs pull      # <-- APK'lar LFS pointer olarak gelir!"
      exit 1
    fi
  fi

  # LFS pointer kontrolu: 131 baytlik stub dosyalar gercek APK degildir.
  # Bu kontrol olmadan build bozuk APK paketler (sessiz hata).
  # PRIV="" ise payload zaten device tree'de; kopyalama adimi atlanir.
  if [[ -n "$PRIV" ]]; then
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
  COPIED=0
  for p in "${PAYLOADS[@]}"; do
    src="$PRIV/$p"
    [[ -d "$src" ]] || continue
    dst="$TREE/$p"
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
    dim "$(printf '%-28s %s' "$p" "$(du -sh "$dst" 2>/dev/null | cut -f1)")"
    COPIED=$((COPIED+1))
  done
  (( COPIED > 0 )) && ok "$COPIED payload kopyalandi -> $TREE" || warn "Hicbir payload kopyalanmadi"

  # Kamera graph'lari (build sirasinda kullanilir)
  if [[ -d "$PRIV/camera-graphs" ]]; then
    rm -rf "$TREE/configs/camera"
    mkdir -p "$TREE/configs"
    cp -R "$PRIV/camera-graphs" "$TREE/configs/camera"
    ok "camera-graphs -> $TREE/configs/camera"
  fi
  fi   # PRIV bos degilse
fi

# ------------------------------------------------------------------ 3) dogrulama
if (( VERIFY )); then
  log "Dogrulama"
  fail=0
  check() {
    if [[ -e "$1" ]]; then dim "  var  $2"; else err "  YOK  $2"; fail=1; fi
  }
  check "$VENDOR/Android.bp"                 "vendor/xiaomi/xuanyuan/Android.bp"
  check "$VENDOR/xuanyuan-vendor.mk"        "vendor/xiaomi/xuanyuan/xuanyuan-vendor.mk"
  check "$TREE/prebuilts/miuicamera"        "device/.../prebuilts/miuicamera"
  check "$TREE/rootdir"                     "device/.../rootdir"
  check "$TREE/neoteric_compat"             "device/.../neoteric_compat"
  (( fail )) && { err "Dogrulama basarisiz"; exit 1; }
  ok "Dogrulama gecti"
fi

ok "Vendor agaci hazir."
cat <<EOF

Sonraki adim:
  bash <device-tree>/scripts/apply_platform_patches.sh
  source build/envsetup.sh
  lunch lineage_xuanyuan-bp4a-userdebug
  m evolution -j\$(nproc)
EOF
