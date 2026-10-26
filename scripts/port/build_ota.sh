#!/bin/bash
# Build runner: same env as the build service script, plus
# keep-going (-k) and timestamped logs. Usage: build_ota.sh [targets...]
export USE_CCACHE=1 CCACHE_DIR=/mnt/out/ccache CCACHE_EXEC=/usr/bin/ccache CCACHE_BASEDIR=/mnt/src
export GOGC=50 GOMEMLIMIT=8GiB BUILD_BROKEN_DUP_RULES=true WITH_GMS=false
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME=/mnt/out/builder-home
TS=$(date +%Y%m%d-%H%M%S)
LOG=${PORT_LOG_DIR:-/mnt/out/port-logs}/build-$TS.log
mkdir -p ${PORT_LOG_DIR:-/mnt/out/port-logs}
ln -sfn "$LOG" ${PORT_LOG_DIR:-/mnt/out/port-logs}/latest.log
cd /mnt/src || exit 90
/mnt/out/host/linux-x86/bin/bpfmt -l vendor/xiaomi/xuanyuan/Android.bp >/dev/null
[ $? -eq 2 ] && { echo "=== bpfmt PARSE HATASI ===" > "$LOG"; exit 92; }
{ echo "=== BUILD BASLADI $(date -Is) targets=${*:-default} ==="; } > "$LOG"
source build/envsetup.sh >> "$LOG" 2>&1
lunch lineage_xuanyuan-bp4a-userdebug >> "$LOG" 2>&1 || { echo "=== LUNCH BASARISIZ ===" >> "$LOG"; exit 91; }
m -j4 -k "$@" >> "$LOG" 2>&1
rc=$?
echo "=== m BITTI rc=$rc $(date -Is) ===" >> "$LOG"
cp /mnt/out/error.log ${PORT_LOG_DIR:-/mnt/out/port-logs}/error-$TS.log 2>/dev/null
cp /mnt/out/verbose.log.gz ${PORT_LOG_DIR:-/mnt/out/port-logs}/verbose-$TS.log.gz 2>/dev/null
echo "$rc" > ${PORT_LOG_DIR:-/mnt/out/port-logs}/exitcode-$TS
exit $rc
