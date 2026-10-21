#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan namespace'inin gerekli import'lari ekler.
#
# SORUN
# -----
# vendor/xiaomi/xuanyuan/Android.bp (Xiaomi'nin public vendor reposundan)
# soong_namespace blogunda yalnizca "hardware/xiaomi" import'u var. Bu
# namespace'in okudugu modullerin bir kismi ise baska projelerde
# tanimli ve o projeler kendi namespace'lerinde:
#
#   error: "libagmclient" depends on undefined module
#          "vendor.qti.hardware.agm-V1-ndk".
#   Module "libagmclient" is defined in namespace
#   "vendor/xiaomi/xuanyuan" which can read these 3 namespaces:
#   ["vendor/xiaomi/xuanyuan" "hardware/xiaomi" "."]
#   Module "vendor.qti.hardware.agm-V1-ndk" can be found in these
#   namespaces: ["hardware/qcom-caf/sm8450-6.6" "hardware/qcom-caf/sm8750"]
#
# Ayni sekilde display ve WLAN arayuzleri de gorunmez:
#
#   error: "ppd" depends on undefined module
#          "vendor.qti.hardware.display.color-V1-ndk".
#   Module "vendor.qti.hardware.display.color-V1-ndk" can be found in
#   these namespaces: ["vendor/qcom/opensource/commonsys-intf/display"]
#
#   error: "lowi-server" depends on undefined module "libcld80211".
#   Module "libcld80211" can be found in these namespaces:
#   ["hardware/qcom-caf/wlan" "hardware/qcom/wlan/legacy" ...]
#
#   error: "qti" depends on undefined module "librmnetctl".
#   Module "librmnetctl" can be found in these namespaces:
#   ["vendor/qcom/opensource/dataservices"]
#
# COZUM
# -----
# soong_namespace imports listesine gereken namespace'ler eklenir:
#   - hardware/qcom-caf/sm8750 : sm8750 SoC'sunun HAL'lari (agm, qspmhal,
#     adreno profiller gibi blob'larin cogu buradan gelir)
#   - vendor/qcom/opensource/commonsys-intf/display : Qualcomm display
#     arayuzleri (color, postproc)
#   - hardware/qcom-caf/wlan : Qualcomm WLAN/CLD80211 kutuphaneleri
#   - vendor/qcom/opensource/dataservices : rmnet data servisi
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

IMPORTS=(
  "hardware/qcom-caf/sm8750"
  "vendor/qcom/opensource/commonsys-intf/display"
  "hardware/qcom-caf/wlan"
  "vendor/qcom/opensource/dataservices"
)

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

python3 - "$TARGET" "${IMPORTS[@]}" <<'PY'
import re, sys
p = sys.argv[1]
imports = sys.argv[2:]
s = open(p).read()

m = re.search(r'(soong_namespace \{\s*\n\s*imports: \[\s*\n)(.*?)(\s*\],)', s, re.S)
if not m:
    raise SystemExit("soong_namespace imports blogu bulunamadi")

body = m.group(2).rstrip()
existing = set(re.findall(r'"([^"]+)"', body))
added = []
for name in imports:
    if name in existing:
        continue
    if body and not body.endswith(","):
        body += ","
    body += '\n        "%s",' % name
    added.append(name)

if added:
    s = s[:m.start(2)] + body + s[m.end(2):]
    open(p, "w").write(s)
    for a in added:
        print('[+] import eklendi: ' + a)
else:
    print("[✓] eklenecek import yok")
PY

for name in "${IMPORTS[@]}"; do
  if ! grep -q "\"$name\"" "$TARGET"; then
    err "import eksik: $name"
    exit 1
  fi
done
ok "dogrulama: tum import'lar mevcut"
log "tamamlandi"
