# device_xiaomi_xuanyuan

**Xiaomi 15 Ultra** (`xuanyuan`) cihaz ağacı — Evolution X / LineageOS (Android 16).

| | |
|---|---|
| Cihaz | Xiaomi 15 Ultra, codename `xuanyuan` |
| SoC | Snapdragon 8 Elite (SM8750-AB), Oryon V2, Adreno 830 |
| Platform | `sun` (SoC) / `pakala` (Qualcomm BSP) |
| Kernel | Linux 6.6, GKI 2.0 (`android15-6.6`), **prebuilt** |
| Ürün | `lineage_xuanyuan` → `lineage_xuanyuan-bp4a-userdebug` |
| Build | `m evolution` |

## İlgili repolar

| Repo | Gizlilik | İçerik |
|---|---|---|
| `device_xiaomi_xuanyuan` (bu repo) | public | cihaz ağacı, build kuralları, testler |
| `proprietary_vendor_xiaomi_xuanyuan` | **private** | Xiaomi blob'ları + proprietary prebuilt'ler |
| `kernel_xiaomi_generic` | public | prebuilt GKI kernel, dtb, dtbo, vendor_boot |
| `device_xiaomi_sm8750_common` | public | SM8750 platform ortak katmanı |

## Derleme

```bash
# 1) platform kaynagi
#    Pinned manifest REMOTE/DEFAULT tanimlamaz - onlar local_manifests.xml'de.
#    Ayni remote iki manifest icinde farkli fetch ile tanimlanirsa repo sync
#    "remote ... already exists with different attributes" ile durur.
repo init -u https://github.com/Evolution-X/manifest -b bka --depth=1
cp build-support/evox-manifest-pinned.xml .repo/manifests/default.xml
rm -f .repo/local_manifests
mkdir -p .repo/local_manifests
cp build-support/local_manifests.xml .repo/local_manifests/local_manifests.xml
repo sync -c -j$(nproc)

# 2) proprietary payload'lari tasi (MiuiCamera APK, stok init scriptleri, kamera compat)
bash scripts/sync_proprietary.sh

# 3) platform patch'lerini uygula
bash scripts/apply_platform_patches.sh

# 4) derle
source build/envsetup.sh
lunch lineage_xuanyuan-bp4a-userdebug
m evolution -j$(nproc)
```

## Dizin yapısı

```
build-support/     pinned EvoX manifest + 24 platform patch (+ .base SHA) + vendor config snapshot
configs/           ses, kamera, wifi, display yapılandırmaları
compat/            eski/yeni display HAL arasında köprü
overlay/ rro_a16/  sistem overlay'leri
sensors/multihal/  Xiaomi sensör HAL'i için kaynak tabanlı çoklu-HAL
sepolicy/          vendor SELinux politikaları
udfps/             ekran içi parmak izi UDFPS handler (kaynak tabanlı)
scripts/           build yardımcıları (sync_proprietary, apply_platform_patches)
tests/             bring-up kanıtları ve teşhis günlükleri
vintf/             VINTF manifest'leri ve uyumluluk matrisi
```

## Kamera notu

`prebuilts/miuicamera` ve `prebuilts/camera` dizinleri Xiaomi'nin **orijinal**
binary'leridir (MiuiCamera APK, `libcameraopt.so`, özel `libui.so`…). Bu yüzden
**private repoda** durur ve `scripts/sync_proprietary.sh` ile build-time'da
kopyalanır. Ayrıntı: `tests/CAMERA-*.md`.

## Lisans

Bu repodaki kod Apache-2.0. `prebuilts/`, `rootdir/` ve `neoteric_compat/`
içindeki Xiaomi binary'leri **proprietary**'dir ve bu repoda tutulmaz.
