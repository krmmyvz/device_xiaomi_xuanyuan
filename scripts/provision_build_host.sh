#!/usr/bin/env bash
# AOSP/EvoX derleme ortamını hazırlar - VM İÇİNDE çalıştır.
#
#   sudo scripts/provision_build_host.sh [--swap-gb 16] [--ccache-gb 40]
#
# Android 16 (bp4a) + Evolution-X bka icin gereken tüm bagimliliklar.
#
# Disk plani (olculmus):
#   repo sync -c              ~131 GB   (checkout + .git)
#   out/ (tam derleme)        ~138 GB
#   ccache (opsiyonel)         20-40 GB
#   toplam                     ~200-310 GB
#   --depth=1 ile .git belirgin sekilde kuculur; checkout tabanı degismez.
#
# Not: repo sync -c icin olculen 131 GB degerinin .git payini icerir.
#      --depth=1 ile .git kuculur ama calisma agaci (checkout) ayni kalir.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

SWAP_GB=16
CCACHE_GB=40
while [[ $# -gt 0 ]]; do
  case "$1" in
    --swap-gb) SWAP_GB="$2"; shift ;;
    --ccache-gb) CCACHE_GB="$2"; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) die "Bilinmeyen arg: $1" ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "sudo ile calistir: sudo $0" >&2
  exit 1
fi

log() { printf '\033[36m[+]\033[0m %s\n' "$*"; }
ok()  { printf '\033[32m[✓]\033[0m %s\n' "$*"; }
warn(){ printf '\033[33m[!]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[31m[x]\033[0m %s\n' "$*" >&2; }

. /etc/os-release
log "Sistem: $PRETTY_NAME ($(uname -r))"

# ------------------------------------------------------------- disk kontrolu
AVAIL_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
log "Kullanilabilir disk: ${AVAIL_GB} GB"
if (( AVAIL_GB < 320 )); then
  warn "Disk ${AVAIL_GB} GB - tam derleme icin ~310 GB gerekli (kaynak+out+ccache)"
  warn "Sirasiyla denenecek: (1) ccache'i kucult/diske yazma (2) out/ ayri diske (OUT_DIR)"
  warn "  (3) sadece vendor agacini derle (m vendor/xiaomi/xuanyuan) - ~150 GB yeter"
fi

# ------------------------------------------------------------- paketler
export DEBIAN_FRONTEND=noninteractive
log "Paket dizini guncelleniyor"
apt-get update -qq

log "AOSP/EvoX derleme bagimliliklari kuruluyor"
apt-get install -y -qq \
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git-core git-lfs gnupg htop imagemagick lib32readline-dev lib32z1-dev \
  libelf-dev libc6-dev-i386 libgmp-dev liblzo2-dev libncurses5 \
  libpng-dev libsdl1.2-dev libssl-dev libxml2-dev libxml2-utils \
  lzop m4 make pngcrush python3 python3-pip python-is-python3 \
  rsync schedtool squashfs-tools unzip zip zlib1g-dev zstd \
  openjdk-17-jdk-headless device-tree-compiler \
  ca-certificates

# ------------------------------------------------------------------- JDK 17
# Android 16 (bp4a) JDK 17 ister. Ubuntu 24.04'te varsayilan JDK 21'dir ve
# otomatik secilir - bu yuzden acikca 17 kurulup JAVA_HOME sabitleniyor.
log "JDK 17 yapilandiriliyor (Android 16 = JDK 17; Ubuntu 24.04 varsayilani 21)"
update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 2>/dev/null || true
cat > /etc/profile.d/jdk17.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
EOF
chmod 644 /etc/profile.d/jdk17.sh
grep -q "jdk17.sh" /root/.bashrc 2>/dev/null || echo '. /etc/profile.d/jdk17.sh' >> /root/.bashrc
ok "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64  ($(java -version 2>&1 | head -1))"

# --------------------------------------------------------------------- repo
log "repo kuruluyor"
if ! command -v repo >/dev/null 2>&1; then
  mkdir -p /usr/local/bin
  curl -fsSL -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
  chmod +x /usr/local/bin/repo
fi
ok "repo hazir"

# -------------------------------------------------------------------- swap
TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')
SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
TARGET_MB=$(( SWAP_GB * 1024 ))
if (( SWAP_MB < TARGET_MB )); then
  log "Swap: ${SWAP_MB} MB -> ${TARGET_MB} MB (VM ici, soong_build 24-26 GB RAM istiyor)"
  if [[ -f /swapfile ]]; then
    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile
  fi
  fallocate -l "${TARGET_MB}M" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi
ok "swap: $(free -g | awk '/^Swap:/{print $2}') GB"

# ------------------------------------------------------------------ ccache
# AOSP ccache'i sadece USE_CCACHE=1 + CCACHE_DIR ile kullanir.
# Temiz derlemede ccache kazanc saglamaz, yalnizca REBUILD'lerde ise yarar.
CCACHE_DIR="${CCACHE_DIR:-/mnt/shared/ccache}"
mkdir -p "$CCACHE_DIR"
ccache -M "${CCACHE_GB}G" >/dev/null 2>&1 || true
cat > /etc/profile.d/aosp-ccache.sh <<EOF
export USE_CCACHE=1
export CCACHE_DIR=$CCACHE_DIR
export CCACHE_EXEC=$CCACHE_DIR/ccache
export CCACHE_BASEDIR=/root
EOF
chmod 644 /etc/profile.d/aosp-ccache.sh
grep -q "aosp-ccache.sh" /root/.bashrc 2>/dev/null || echo '. /etc/profile.d/aosp-ccache.sh' >> /root/.bashrc
ok "ccache: USE_CCACHE=1, CCACHE_DIR=$CCACHE_DIR, max ${CCACHE_GB}G"

# ------------------------------------------------------------------ sysctl
# Dogrusu vm.vfs_cache_pressure (alt cizgili) - "vm.vfs.cache_pressure" YOKTUR.
log "sysctl ayarlaniyor"
cat > /etc/sysctl.d/99-aosp-build.conf <<'EOF'
# AOSP derleme ayarlari
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
if ! sysctl --system 2>&1 | grep -q "vm.vfs.cache_pressure"; then
  ok "sysctl uygulandi (vm.vfs_cache_pressure)"
else
  err "sysctl hatasi - asagidaki dosyayi kontrol et"
  cat /etc/sysctl.d/99-aosp-build.conf
  exit 1
fi

cat <<EOF

================================================================
Ortam hazir.

Disk su an: ${AVAIL_GB} GB bos

Derleme adimlari (root olmayan kullanici olarak):

  repo init -u https://github.com/Evolution-X/manifest -b bka
  mkdir -p .repo/local_manifests
  cp <device-tree>/build-support/evox-manifest-pinned.xml .repo/local_manifests/
  cp <device-tree>/build-support/local_manifests.xml       .repo/local_manifests/

  # ~131 GB (checkout+.git); --depth=1 .git'i kucultur, checkout ayni kalir
  repo sync -c --depth=1 -j\$(nproc)

  # vendor blob agacini yerlestir (cihazdan uretilmis, git disi)
  bash <device-tree>/scripts/install_vendor_tree.sh

  # platform patch'leri - base SHA tutmuyorsa HATA VERIR, sessizce atmaz
  bash <device-tree>/scripts/apply_platform_patches.sh

  source build/envsetup.sh
  lunch lineage_xuanyuan-bp4a-userdebug
  m evolution -j\$(nproc)

  # urun adi 'lineage_xuanyuan' (EvoX ağacı böyle kaydediyor),
  # build hedefi 'evolution' (EvoX'un birlesik target'i) - ikisi de dogru.

  # HIZLI DOGRULAMA (dusuk disk/yakin sure):
  #   m vendor/xiaomi/xuanyuan   # sadece vendor agaci (~150 GB yeter)
  #   m nothing                 # sadece build grafigi dogrulama

Ortam: $(java -version 2>&1 | head -1)
ccache: $CCACHE_DIR (${CCACHE_GB}G)
swap  : $(free -g | awk '/^Swap:/{print $2}') GB
================================================================
EOF
