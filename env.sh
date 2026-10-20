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

# Ust dizin: device tree bu ust dizinin icinde bekleniyor (rom/device_xiaomi_xuanyuan)
: "${PROJECT_ROOT:=$(dirname "$DEVICE_TREE_DIR")}"
: "${ROM:=${PROJECT_ROOT}/rom}"
: "${AOSP_ROOT:=${HOME}/android/evolution}"

# Python yorumlayicisi (verify_patch_bases.py vb. betikler icin)
: "${PY:=python3}"

export DEVICE_TREE_DIR PROJECT_ROOT ROM AOSP_ROOT PY

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
