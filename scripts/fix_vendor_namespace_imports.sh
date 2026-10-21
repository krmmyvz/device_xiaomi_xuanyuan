#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan namespace'inin gerekli import'lari ekler.
#
# SORUN
# -----
# vendor/xiaomi/xuanyuan/Android.bp (Xiaomi'nin public vendor reposundan)
# soong_namespace blogunda yalnizca "hardware/xiaomi" import'u var. Bu
# namespace'in okudugu modullerin bir kismi ise hardware/qcom-caf altindaki
# projelerde tanimli, ve o projeler kendi namespace'lerinde:
#
#   error: vendor/xiaomi/xuanyuan/Android.bp:3523:1: "libagmclient" depends
#          on undefined module "vendor.qti.hardware.agm-V1-ndk".
#   Module "libagmclient" is defined in namespace
#   "vendor/xiaomi/xuanyuan" which can read these 3 namespaces:
#   ["vendor/xiaomi/xuanyuan" "hardware/xiaomi" "."]
#   Module "vendor.qti.hardware.agm-V1-ndk" can be found in these namespaces:
#   ["hardware/qcom-caf/sm8450-6.6" "hardware/qcom-caf/sm8750"]
#
# Yani vendor agacinin "hardware/qcom-caf/sm8750" namespace'ini GORMESI
# gerekiyor.
#
# COZUM
# -----
# soong_namespace imports listesine "hardware/qcom-caf/sm8750" eklenir.
# Bu namespace sm8750 SoC'sunun HAL'larini toplar; vendor blob'larinin
# cogu (agm, qspmhal, adreno profiller) oradan gelir.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

if grep -q '"hardware/qcom-caf/sm8750"' "$TARGET"; then
  ok "import zaten var"
  exit 0
fi

python3 - "$TARGET" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
m = re.search(r'(soong_namespace \{\s*\n\s*imports: \[\s*\n)(.*?)(\s*\],)', s, re.S)
if not m:
    raise SystemExit("soong_namespace imports blogu bulunamadi")
body = m.group(2)
new_body = body.rstrip()
if not new_body.endswith(","):
    new_body += ","
new_body += '\n        "hardware/qcom-caf/sm8750",'
s = s[:m.start(2)] + new_body + s[m.end(2):]
open(p, "w").write(s)
print('[+] "hardware/qcom-caf/sm8750" import eklendi')
PY

if ! grep -q '"hardware/qcom-caf/sm8750"' "$TARGET"; then
  err "import eklenemedi"
  exit 1
fi
ok "dogrulama: import var"
log "tamamlandi"
