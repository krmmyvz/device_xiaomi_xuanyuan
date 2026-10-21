#!/usr/bin/env bash
set -e -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROM_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BUILD_LOG="/tmp/xuanyuan-live-integrated-$(date +%Y%m%d-%H%M%S).log"
cd "$ROM_ROOT"
printf 'Build log: %s\n' "$BUILD_LOG"
source build/envsetup.sh
lunch lineage_xuanyuan-bp4a-userdebug
m bacon -j2 2>&1 | tee "$BUILD_LOG"
printf 'BUILD_SUCCESS log=%s\n' "$BUILD_LOG"
