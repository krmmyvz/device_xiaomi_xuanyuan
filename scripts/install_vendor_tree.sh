#!/usr/bin/env bash
# Uretilen vendor blob agacini AOSP kaynak agacina yerlestirir.
#
#   scripts/install_vendor_tree.sh [--aosp <yol>] [--from <diz>]
#
# Neden ayri bir adim: blob agaci 6.2 GB Xiaomi proprietary binary'dir.
#  - yeniden uretilebilir (cihaz dump'indan, deterministik)
#  - en lisans-duyarli kisim -> git'e sokulmaz
#  - GitHub'a 4+ GB paket gondermek pratik degil (HTTP 500 / saatlerce upload)
# Bu yuzden gecerli agac yerelde uretilir ve build oncesi kopyalanir.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

AOSP="${AOSP_ROOT:-${HOME}/android/evolution}"
FROM="${WORK_DIR}/vendor-tree"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aosp) AOSP="$2"; shift ;;
    --from) FROM="$2"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "Bilinmeyen arg: $1" ;;
  esac
  shift
done

[[ -d "$FROM" ]] || die "Uretilen vendor agaci yok: $FROM"
[[ -d "$FROM/proprietary" ]] || die "Blob agaci bos: $FROM/proprietary"
[[ -f "$FROM/Android.bp" ]] || die "Android.bp yok: $FROM/Android.bp"

DEST="$AOSP/vendor/xiaomi/xuanyuan"

log "Vendor blob agaci yerlestiriliyor"
dim "  kaynak : $FROM"
dim "  hedef : $DEST"

if [[ -d "$DEST" ]] && [[ ! -L "$DEST" ]]; then
  # yerlesik kopya -> symlink'e cevir (disk tasarrufu + guncelleme kolayligi)
  log "  mevcut dizin symlink ile degistiriliyor"
  rm -rf "${DEST}.old"
  mv "$DEST" "${DEST}.old"
  ln -s "$FROM" "$DEST"
  rm -rf "${DEST}.old"
else
  mkdir -p "$(dirname "$DEST")"
  rm -rf "$DEST"
  ln -s "$FROM" "$DEST"
fi

N=$(find "$FROM/proprietary" -type f 2>/dev/null | wc -l | tr -d ' ')
ok "Yerlestirildi: $N blob, $(du -sh "$FROM" | cut -f1)"

# dogrulama
if [[ -f "$DEST/Android.bp" && -f "$DEST/xuanyuan-vendor.mk" ]]; then
  MODS=$(grep -c "^cc_prebuilt" "$DEST/Android.bp" 2>/dev/null || echo 0)
  ok "dogrulama: Android.bp ($MODS prebuilt modul) + xuanyuan-vendor.mk mevcut"
else
  err "dogrulama basarisiz"
  exit 1
fi
