#!/usr/bin/env bash
# AOSP derleme ortamını hazırlar - UYGULANACAK MAKİNEDE (Ubuntu/Debian) çalıştır.
#
#   sudo scripts/provision_build_host.sh
#
# AOSP 16 (Android 16) + Evolution-X bka için gereken tüm bagimliliklar.
# Diger paketler: git, repo, python3, openjdk-17, ccache, rsync, zstd, vb.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "sudo ile calistir: sudo $0" >&2
  exit 1
fi

log() { printf '\033[36m[+]\033[0m %s\n' "$*"; }
ok()  { printf '\033[32m[✓]\033[0m %s\n' "$*"; }

log "Sistem bilgisi"
. /etc/os-release
echo "  $PRETTY_NAME  ($(uname -r))"

log "Paket dizini guncelleniyor"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -yqq

log "AOSP derleme bagimliliklari kuruluyor"
apt-get install -y -qq \
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git-core gnupg htop imagemagick lib32readline-dev lib32z1-dev \
  libelf-dev libc6-dev-i386 libgmp-dev liblzo2-dev libncurses5 \
  libpng-dev libsdl1.2-dev libssl-dev libxml2-dev libxml2-utils \
  lzop m4 make pngcrush python3 python3-pip python-is-python3 \
  rsync schedtool squashfs-tools unzip zip zlib1g-dev zstd \
  openjdk-17-jdk-headless device-tree-compiler \
  ca-certificates curl git-lfs

# Android 16 icin JDK 17 (AOSP 11'den beri 11, AOSP 14+ icin 17)
if ! update-alternatives --query java 2>/dev/null | grep -q "17"; then
  log "JDK 17 varsayilan yapiliyor"
  update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
fi

log "repo kuruluyor"
if ! command -v repo >/dev/null 2>&1; then
  mkdir -p /usr/local/bin
  curl -fsSL -o /usr/local/bin/repo \
    https://storage.googleapis.com/git-repo-downloads/repo
  chmod +x /usr/local/bin/repo
fi
ok "repo: $(repo --version 2>/dev/null | head -2 | tail -1)"

log "Swap yapilandiriliyor (derleme icin kritik)"
TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')
SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
if (( SWAP_MB < 32768 )); then
  TARGET=$(( TOTAL_MB < 32768 ? 32768 : TOTAL_MB ))
  log "  mevcut swap: ${SWAP_MB} MB -> ${TARGET} MB ekleniyor"
  if [[ -f /swapfile ]]; then
    swapon /swapfile 2>/dev/null || true
  else
    fallocate -l "${TARGET}M" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -q '/swapfile' /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
  fi
fi
ok "swap: $(free -g | awk '/^Swap:/{print $2}') GB"

log "Derleme icin ince ayarlar"
cat > /etc/sysctl.d/99-aosp-build.conf <<'EOF'
# AOSP derleme icin
vm.swappiness=10
vm.vfs.cache_pressure=50
EOF
sysctl --system >/dev/null 2>&1 || true
ok "sysctl ayarlandi"

log "Kullanici yapilandirmasi"
TARGET_USER="${SUDO_USER:-$(id -un)}"
if [[ "$TARGET_USER" != "root" ]]; then
  usermod -aG sudo "$TARGET_USER" 2>/dev/null || true
fi
ok "sudo grubu: $TARGET_USER"

cat <<EOF

================================================================
Ortam hazir. Son adimlar (root olmayan kullanici olarak):

  repo init -u https://github.com/Evolution-X/manifest -b bka
  mkdir -p .repo/local_manifests
  cp <device-tree>/build-support/evox-manifest-pinned.xml .repo/local_manifests/
  cp <device-tree>/build-support/local_manifests.xml       .repo/local_manifests/
  repo sync -c

  bash <device-tree>/scripts/sync_proprietary.sh
  bash <device-tree>/scripts/apply_platform_patches.sh

  source build/envsetup.sh
  lunch lineage_xuanyuan-bp4a-userdebug
  m evolution -j\$(nproc)

Notlar:
  - 'm' calisirken GOGC=50 GOMEMLIMIT=8GiB ayarla (dusuk bellekli host)
  - surum: $(java -version 2>&1 | head -1)
  - ccache etkin: $(command -v ccache >/dev/null && echo "evet" || echo "yok")
================================================================
EOF
