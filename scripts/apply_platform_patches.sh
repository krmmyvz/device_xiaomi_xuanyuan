#!/usr/bin/env bash
# Platform patch'lerini uygular.
#
#   scripts/apply_platform_patches.sh [--check] [--reverse] [--force]
#
# Her patch, isledigi projeye gore adlandirilmistir:
#   device/xiaomi/xuanyuan  ->  device__xiaomi__xuanyuan.patch
# Yani '/' -> '__' donusumu yapilir.
#
# Yaninda '.base' dosyasi, patch'in HANGI upstream revizyonunda dogrulandigini
# tutar. Revizyon degistiyse patch sessizce uygulanmaz - ancak yeni base
# uretilip test edilmelidir.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ROMBASE="${ROM:-${PROJECT_ROOT}/rom}"
TREE="$ROMBASE/device_xiaomi_xuanyuan"
PATCH_DIR="$TREE/build-support/platform-patches"
AOSP="${AOSP_ROOT:-${HOME}/android/evolution}"

MODE="apply"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)  MODE="check" ;;
    --reverse) MODE="reverse" ;;
    --force)  export PATCH_FORCE=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) die "Bilinmeyen arg: $1" ;;
  esac
  shift
done

[[ -d "$PATCH_DIR" ]] || die "patch dizini yok: $PATCH_DIR"
[[ -d "$AOSP" ]] || die "AOSP kaynagi yok: $AOSP (once 'repo sync' calistir)"

APPLIED=0; SKIPPED=0; FAILED=0; MISMATCH=0

for pf in "$PATCH_DIR"/*.patch; do
  [[ -f "$pf" ]] || continue
  name=$(basename "$pf" .patch)
  proj=$(echo "$name" | sed 's/__/\//g')
  target="$AOSP/$proj"

  if [[ ! -d "$target/.git" ]]; then
    warn "$proj: proje yok (sync edilmemis?) - atlandi"
    SKIPPED=$((SKIPPED+1)); continue
  fi

  base_file="$PATCH_DIR/${name}.base"
  if [[ -f "$base_file" ]]; then
    base=$(cat "$base_file" | tr -d '[:space:]')
    cur=$(git -C "$target" rev-parse HEAD)
    if [[ "$base" != "$cur" ]]; then
      warn "$proj: base SHA uyusmuyor"
      dim "  patch icin beklenen : $base"
      dim "  repoda olan         : $cur"
      if [[ "${PATCH_FORCE:-0}" == "1" ]]; then
        dim "  --force: yine de uygulanacak"
      else
        dim "  ATLANDI. Yeni base uretmek icin:"
        dim "    git -C $target apply --check $pf  (basarisizsa elle)"
        dim "    sonra: echo $cur > $base_file"
        MISMATCH=$((MISMATCH+1)); SKIPPED=$((SKIPPED+1)); continue
      fi
    fi
  fi

  if [[ "$MODE" == "check" ]]; then
    if git -C "$target" apply --check "$pf" 2>/dev/null; then
      ok "uygulanabilir: $proj"
    else
      err "uygulanamaz   : $proj"
      FAILED=$((FAILED+1))
    fi
    continue
  fi

  if [[ "$MODE" == "reverse" ]]; then
    git -C "$target" apply --reverse "$pf" 2>/dev/null && { dim "geri alindi: $proj"; APPLIED=$((APPLIED+1)); }
    continue
  fi

  if git -C "$target" apply --check "$pf" 2>/dev/null; then
    git -C "$target" apply "$pf" && { dim "uygulandi: $proj"; APPLIED=$((APPLIED+1)); }
  elif git -C "$target" apply --check --reverse "$pf" 2>/dev/null; then
    dim "zaten uygulanmis: $proj"
    SKIPPED=$((SKIPPED+1))
  else
    err "uygulanamadi: $proj"
    git -C "$target" apply --check "$pf" 2>&1 | head -3 | sed 's/^/      /'
    FAILED=$((FAILED+1))
  fi
done

echo
log "Sonuc: $APPLIED uygulandi, $SKIPPED atlandi ($MISMATCH base uyusmazligi), $FAILED basarisiz"
(( FAILED > 0 )) && exit 1
exit 0
