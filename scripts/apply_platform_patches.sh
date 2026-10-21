#!/usr/bin/env bash
# Platform patch'lerini uygular.
#
#   scripts/apply_platform_patches.sh [--check] [--reverse] [--force] [--verify-only]
#
# Yama adlandirmasi: dosya adi -> proje yolu ('/' -> '__' donusumu).
#   vendor__lineage.patch  ->  vendor/lineage
# Bu esleme dogrudur: patch icindeki 'diff --git' yollari PROJE KOKUNE gore
# relative'dir (orn. vendor/lineage icindeki build/soong/Android.bp ve
# release/flag_values/bp4a/... gercekten vendor/lineage projesindedir).
#
# ONEMLI: base SHA tutmuyorsa patch sessizce ATLANMAZ - hata verilir.
# Aksi halde yamasiz build sessizce devam eder.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

# DOGRULAMA: 'source .../env.sh' ifadesi, ust dizine cd basarisiz olursa
# BOZUK BIR YOL uretir ("/env.sh") ve env.sh hic yuklenmez; sonraki
# degiskenler de yanlis degerlerle dolar. NAS uzerindeki bir agac
# ara sira erisilemez oldugu icin bu gercekten olur. Yukleme sonrasi
# env.sh'in gercekten yuklendigini ve yollarin dogru oldugunu dogrula.
[[ -n "${DEVICE_TREE_DIR:-}" ]] || die "env.sh yuklenemedi (beklenen: $0 ust dizinindeki env.sh)"

ROMBASE="${ROM:-${PROJECT_ROOT}/rom}"
# Platform agacindaki cihaz agacinin YOLU: <AOSP>/device/xiaomi/xuanyuan
# (onceki hata: "device/xiaomi_xuanyuan" - "xiaomi/" segmenti atlanmis,
#  boylece PATCH_DIR her zaman "yok" gorunuyordu).
TREE="$ROMBASE/device/xiaomi/xuanyuan"
PATCH_DIR="$TREE/build-support/platform-patches"
AOSP="${AOSP_ROOT:-${HOME}/android/evolution}"

MODE="apply"
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check" ;;
    --reverse) MODE="reverse" ;;
    --verify-only) MODE="verify" ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) die "Bilinmeyen arg: $1" ;;
  esac
  shift
done

[[ -d "$PATCH_DIR" ]] || die "patch dizini yok: $PATCH_DIR"

# ------------------------------------------------ 0) once base SHA'lari dogrula
log "Base SHA dogrulamasi (pinned manifest ile)"
if ! "$PY" "$TREE/scripts/verify_patch_bases.py" --tree "$TREE"; then
  err "Base SHA tutmuyor - patch'ler uygulanamaz."
  err "Cikis: --force ile zorla dene (guvenli DEGILDIR, yamanin kaybolma riski var)"
  [[ $FORCE -eq 1 ]] || exit 1
  warn "--force: base uyusmazligina rağmen devam ediliyor"
fi

[[ -d "$AOSP" ]] || die "AOSP kaynagi yok: $AOSP (once 'repo sync' calistir)"

# --------------------------------------------------- 1) patch'leri uygula
APPLIED=0; SKIPPED=0; FAILED=0; MISMATCH=0
BASENAME=0

for pf in "$PATCH_DIR"/*.patch; do
  [[ -f "$pf" ]] || continue
  name=$(basename "$pf" .patch)
  proj=$(echo "$name" | sed 's/__/\//g')
  target="$AOSP/$proj"

  if [[ ! -d "$target/.git" ]]; then
    warn "$proj: proje yok (sync edilmemis?) - ATLANDI"
    SKIPPED=$((SKIPPED+1)); BASENAME=$((BASENAME+1)); continue
  fi

  base_file="$PATCH_DIR/${name}.base"
  if [[ -f "$base_file" ]]; then
    base=$(cat "$base_file" | tr -d '[:space:]')
    cur=$(git -C "$target" rev-parse HEAD)
    if [[ "$base" != "$cur" ]]; then
      # once base'in commit'i var mi diye bak (eski base, yeni checkout)
      if git -C "$target" cat-file -e "${base}^{commit}" 2>/dev/null; then
        warn "$proj: HEAD degismis ama base commit'i repoda var - checkout edip deniyorum"
        git -C "$target" checkout -q "$base" 2>/dev/null \
          && dim "  checkout $base" || { warn "  checkout basarisiz"; MISMATCH=$((MISMATCH+1)); SKIPPED=$((SKIPPED+1)); continue; }
      else
        err "$proj: base SHA ($base) repoda YOK ve HEAD farkli"
        dim "  beklenen base : $base"
        dim "  mevcut HEAD   : $cur"
        dim "  Bu patch UYGULANAMAZ. Yeni base uretmek icin:"
        dim "    git -C $target checkout $cur && git apply $pf"
        dim "    sonra: echo $cur > $base_file"
        MISMATCH=$((MISMATCH+1)); SKIPPED=$((SKIPPED+1)); continue
      fi
    fi
  fi

  if [[ "$MODE" == "verify" || "$MODE" == "check" ]]; then
    if git -C "$target" apply --check "$pf" 2>/dev/null; then
      ok "uygulanabilir: $proj"
    else
      err "uygulanamaz   : $proj"
      git -C "$target" apply --check "$pf" 2>&1 | head -3 | sed 's/^/      /'
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
log "Sonuc: $APPLIED uygulandi, $SKIPPED atlandi, $FAILED basarisiz"
if (( MISMATCH > 0 )); then
  err "$MISMATCH patch base SHA uyusmazligi nedeniyle UYGULANMADI"
  exit 1
fi
(( FAILED > 0 )) && exit 1
exit 0
