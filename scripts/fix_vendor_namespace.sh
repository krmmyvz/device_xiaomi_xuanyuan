#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan namespace duzeltmesi.
#
# SORUN
# -----
# vendor/xiaomi/xuanyuan/Android.bp (Xiaomi'nin public vendor reposundan,
# "Automatically generated") soong_namespace imports listesinde
# "vendor/qcom/common/vendor/perf" adini kullaniyor:
#
#     soong_namespace {
#         imports: [
#             "hardware/xiaomi",
#             "vendor/qcom/common/vendor/perf",
#         ],
#     }
#
# Bu namespace hicbir yerde tanimli degil - ne Evolution-X "bka"
# manifestinde ne de vendor payload'inda o dizin yok. Soong analizi
# duruyor:
#
#   error: vendor/xiaomi/xuanyuan/Android.bp:5:1: module "soong_namespace":
#          namespace vendor/qcom/common/vendor/perf does not exist
#
# COZUM
# -----
# Import'un kaldirilmasi guvenli: "libqti-perfd-client" modulu
# hardware/qcom-caf/common/libqti-perfd-client altinda zaten mevcut ve
# build oradan cozulur. Import yalnizca namespace cozumlemesi icin
# gerekiyordu ve cozulemiyor.
#
# Bu bir build-time duzeltmedir: repodaki dosyayi degistirmez, yalnizca
# checkout sonrasi uygulanir. Uygulama idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

if ! grep -q '"vendor/qcom/common/vendor/perf"' "$TARGET" 2>/dev/null; then
  ok "import zaten yok"
  exit 0
fi

python3 - "$TARGET" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
# Yalnizca soong_namespace imports listesindeki satiri kaldir.
s = re.sub(r'^[ \t]*"vendor/qcom/common/vendor/perf",[ \t]*\n', '', s, count=1, flags=re.M)
open(p, 'w').write(s)
PY

if grep -q '"vendor/qcom/common/vendor/perf"' "$TARGET" 2>/dev/null; then
  err "import kaldirilamadi"
  exit 1
fi
ok "import 'vendor/qcom/common/vendor/perf' kaldirildi"
log "tamamlandi"
