#!/usr/bin/env bash
# Ortak ortam: yol varsayılanlari + log yardimcilari.
#
# Bu dosya device tree kokunde durur ve scripts/*.sh tarafindan source edilir.
# Asagidaki degiskenler ortamdan gelirse onlar kullanilir, gelmezse varsayilan:
#
#   PROJECT_ROOT   Device tree'nin bulundugu ust dizin.
#                  Beklenen yapi: $PROJECT_ROOT/device_xiaomi_xuanyuan (device tree)
#                  ve             $PROJECT_ROOT/rom                   (platform kaynagi)
#   ROM            Platform kaynaginin (AOSP) bulundugu dizin
#   AOSP_ROOT      'repo sync' yapilan platform agacinin kok dizini
#   PY             Python yorumlayicisi (verify_patch_bases.py gibi betikler icin)
#
# Ornek:
#   export PROJECT_ROOT=/home/user/rom
#   export ROM=/home/user/android/evolution
#   export AOSP_ROOT=/home/user/android/evolution

# Device tree'nin bulundugu dizin (env.sh'in kendi yolu)
DEVICE_TREE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ust dizin: device tree bu ust dizinin icinde bekleniyor (rom/device/xiaomi_xuanyuan)
#
# DOGRULAMA: bu dosya bir alt kabukta source edildiginde (script'ler
# "source .../env.sh" yapar) ortam degiskenleri KORUNMALIDIR.
# ':=' ile atama, degisken export EDILMEMISSE her source'da yeniden
# hesaplanir. Boylece "ROM=/mnt/src" disaridan verilse bile
# PROJECT_ROOT/rom'a (orn. /home/builder/rom/rom) ezilir ve scriptler
# yanlis dizini arar. Asagida her iki deger de export edilerek sabitlenir.
export PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$DEVICE_TREE_DIR")}"

# AOSP kok dizini: otomatik tespit.
#
# env.sh iki farkli yerde yasar:
#   1) Build agacinda: <AOSP>/device/xiaomi/xuanyuan/env.sh  -> kok 3 seviye
#      yukarida (xuanyuan -> xiaomi -> device -> AOSP).
#   2) Ayri klon: ~/rom/device_xiaomi_xuanyuan/env.sh -> kok buradan
#      TESPIT EDILEMEZ, ortam degiskeni (ROM/AOSP_ROOT) gerekir.
#
# Otomatik tespit, script'lerin "bash scripts/..." ile (login shell
# olmadan) calistirilmasini da guvenli kilar: AOSP_ROOT profile.d'den
# gelmezse burada dogru yol bulunur.
_aosp_auto=""
case "$DEVICE_TREE_DIR" in
  */device/xiaomi/xuanyuan) _aosp_auto="$(cd "$DEVICE_TREE_DIR/../../.." && pwd)" ;;
esac

export AOSP_ROOT="${AOSP_ROOT:-${_aosp_auto:-${HOME}/android/evolution}}"

# ROM (platform agacinin kok dizini) AOSP_ROOT ile ayni yerdir. Oncelik
# sirasi ROM -> AOSP_ROOT -> PROJECT_ROOT/rom. Boylece script
# "bash scripts/..." ile (login shell olmadan) calistiginda da AOSP_ROOT
# uzerinden dogru yolu bulur; login shell'de verilen ROM de korunur.
export ROM="${ROM:-${AOSP_ROOT}}"

# Python yorumlayicisi (verify_patch_bases.py vb. betikler icin)
export PY="${PY:-python3}"

export DEVICE_TREE_DIR

# --- log yardimcilari -------------------------------------------------------
# Renkler, terminal destekliyse aktif olur.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    _C_RESET=$'\033[0m'; _C_RED=$'\033[31m'; _C_GREEN=$'\033[32m'
    _C_YELLOW=$'\033[33m'; _C_BLUE=$'\033[36m'; _C_DIM=$'\033[2m'
else
    _C_RESET=""; _C_RED=""; _C_GREEN=""; _C_YELLOW=""; _C_BLUE=""; _C_DIM=""
fi

log()  { printf '%s[+]%s %s\n'   "$_C_BLUE"   "$_C_RESET" "$*"; }
ok()   { printf '%s[✓]%s %s\n'   "$_C_GREEN"  "$_C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n'   "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
err()  { printf '%s[✗]%s %s\n'   "$_C_RED"    "$_C_RESET" "$*" >&2; }
dim()  { printf '%s    %s%s\n'    "$_C_DIM"    "$*" "$_C_RESET"; }
die()  { err "$*"; exit 1; }
