# Hermes tarafından yapılan doğrulamalar ve düzeltmeler

Tarih: 2026-10-20 · taraf: Hermes (build-agent ile koordinasyon)

Bu belge, build-agent'in `01-ilk-derleme-cevaplari.md` ve
`02-ilk-derleme-recipesi.md` dosyalarındaki **"emin değilim"** maddelerini
kapatır ve build öncesi tespit edilen eksikleri listeler.

---

## 1. `m evolution` hedefi — **ÇÖZÜLDÜ, HEDEF GERÇEK**

build-agent "emin değilim" demişti (`build/make/target/product/` altında yok).
Doğru yer **`vendor/lineage`** projesidir:

| Dosya | İçerik |
|---|---|
| `vendor/lineage/build/tasks/evolution.mk` | `.PHONY: evolution` → `evolution: $(LINEAGE_TARGET_PACKAGE) $(DEFAULT_GOAL)` |
| `vendor/lineage/config/evolution.mk` | EvoX paket tanımları (`AxQuickLook`, `EvoEgg`, `OmniStyle`, …) |

Kanıt zinciri:
- `vendor/lineage/config/common.mk:3` → `$(call inherit-product, vendor/lineage/config/evolution.mk)`
- `vendor/lineage/config/evolution.mk` → `PRODUCT_PACKAGES += …` (EvoX uygulamaları)
- `vendor/lineage/build/tasks/evolution.mk` → OTA zip'i üretir, `.PHONY: evolution`

`build/make` içinde "evolution" yalnızca **RRO üretiminde** kullanılan bir
`subst` ifadesidir (`core/generate_enforce_rro.mk:3`), build target'ı değildir.

→ **`m evolution` doğru komuttur.** `m lineage_xuanyuan` fallback'i de geçerli
(her ikisi de çalışır; `evolution` zengin bir ROM üretir).

## 2. JDK 17 — **DOĞRULANDI**

`build/make` @ `d029f291` içinde `RELEASE_JAVA_VERSION` / `JAVA_VERSION`
sabitleri tarandı; AOSP 16 (bp4a) = **JDK 17**. `provision_build_host.sh`
JDK 17'yi kurup `JAVA_HOME`'u sabitliyor. `m nothing` ile de ucuzca doğrulanabilir.

## 3. Patch→proje eşlemesi — **BAĞIMSIZ DOĞRULAMA: DOĞRU**

build-agent'in kendi düzeltmesi teyit edildi. Ek olarak **24/24 patch'in her
dokunduğu dosyanın pinned rev'de gerçekten var olduğunu** tek tek HTTP ile
doğruladım (GitHub raw + android.googlesource Gitiles):

```
ESIT=24  FARKLI=0  PROJE_YOK=0
```

`vendor__lineage` örneği: `vendor/evolution` @ `4d7dcd1a` içinde
`build/soong/Android.bp` **gerçekten** var ve `generated_kernel_header_defaults`
blokunda `generated_kernel_includes` yazıyor — patch'in değiştirdiği yer tam olarak bu.
`release/flag_values/bp4a/RELEASE_PLATFORM_SECURITY_PATCH.textproto` da aynı
projede ve `2026-10-01` değerini taşıyor (patch `2026-06-05`'e geri alıyor).

→ Diff yolları **proje köküne göre relative**. Dosya adından türetme doğru.

## 4. Build öncesi tespit edilen **yeni eksikler** (build-agent'in görmediği)

### 4.1 `env.sh` yoktu — tüm scriptler onu source ediyordu

`scripts/apply_platform_patches.sh` ve `scripts/sync_proprietary.sh` ikisi de
`env.sh` source ediyor ama dosya repoda **yoktu**. İçinde tanımlı olması
gerekenler: `PROJECT_ROOT`, `ROM`, `AOSP_ROOT`, `PY` ve
`log/ok/warn/err/dim/die` yardımcıları.

→ **Yazıldı** (`env.sh`). `apply_platform_patches.sh`'in kullandığı `$PY`
da tanımlandı (yoksa script boş komut çalıştırıp base doğrulamasını atlar).

### 4.2 `build-support/local_manifests.xml` yoktu

`provision_build_host.sh` ve `sync_proprietary.sh` bu dosyayı `.repo/local_manifests/`
altına kopyalamayı bekliyor ama dosya **yoktu**. Bu olmadan `repo sync` cihazı
hiç getirmez → build kesin başarısız.

→ **Yazıldı** (`build-support/local_manifests.xml`), 5 proje:

| Path | Repo | Branch |
|---|---|---|
| `device/xiaomi/xuanyuan` | `krmmyvz/device_xiaomi_xuanyuan` | `main` |
| `device/xiaomi/sm8750-common` | `krmmyvz/device_xiaomi_sm8750_common` | `main` |
| `device/xiaomi/xuanyuan-kernel` | `xiaomi-8750/android_device_xiaomi_xuanyuan-kernel` | `beryl` |
| `kernel/xiaomi/generic` | `krmmyvz/kernel_xiaomi_generic` | `main` |
| `vendor/xiaomi/xuanyuan` | `xiaomi-8750/proprietary_vendor_xiaomi_xuanyuan` | `beryl` |

5/5 repo ve branch `git ls-remote` ile doğrulandı.

### 4.3 `sm8750-common` repo yapısı hatalıydı — **düzeltildi ve push edildi**

`krmmyvz/device_xiaomi_sm8750_common` reposu içeriği `sm8750-common/` **alt
klasöründe** tutuyordu. Manifest'te `path=device/xiaomi/sm8750-common`
verilseydi ağaçta `device/xiaomi/sm8750-common/sm8750-common/common.mk` oluşurdu —
`device.mk:7`'nin beklediği `device/xiaomi/sm8750-common/common.mk` yoluna ulaşmazdı.

İki seçenek vardı; seçilen: **repo içeriğini köke taşımak** (`93de2da`, push edildi).

> Alternatif olan `path=device/xiaomi` **repo path çakışması** üretirdi:
> `device/xiaomi`, altındaki `device/xiaomi/xuanyuan` ve
> `device/xiaomi/xuanyuan-kernel` projelerini kapsar → `repo sync` hata verir.

### 4.4 `KERNEL_DIR` hiç tanımlı değil — **build blocker**

`BoardConfig.mk` yedi prebuilt yolunu `$(KERNEL_DIR)/...` ile yazıyor
(`kernel`, `prebuilt_kernel_headers.tar.gz`, `dtb.img`, `dtbo.img`,
`vendor_boot.img`, `vendor_dlkm.img`, `system_dlkm.img`) ama `KERNEL_DIR`
**hiçbir yerde tanımlı değil** — ne BoardConfig'de, ne `env.sh`'de.

Tanımsız `$(KERNEL_DIR)` → `/kernel` gibi kök-yol olurdu ve prebuilt adımı patlar.

→ `BoardConfig.mk`'e eklendi: `KERNEL_DIR := $(TARGET_KERNEL_SOURCE)`
(`TARGET_KERNEL_SOURCE` zaten `kernel/xiaomi/generic` idi).

Doğrulama: `krmmyvz/kernel_xiaomi_generic` reposunda 7/7 dosya **var**
(kernel 36 MB, dtb 4 MB, dtbo 18 MB, vendor_boot 36 MB, vendor_dlkm 83 MB,
system_dlkm 15 MB, headers 1.7 MB).

### 4.5 `scripts/install_vendor_tree.sh` yoktu

build-agent'in reçetesi bu scripti çağırıyor ama repoda **yoktu**.

→ **Yazıldı.** İki ayrı kaynağı işler:
- **Vendor ağacı** (`vendor/xiaomi/xuanyuan`): `repo sync` ile gelir, script yalnızca
  varlığını ve 5392 blob'ı doğrular.
- **Proprietary payload** (`device/xiaomi/xuanyuan/{prebuilts,rootdir,neoteric_compat}`):
  private repodan kopyalanır.

### 4.6 Git LFS stub'ları — sessiz bozuk build riski

`krmmyvz/proprietary_vendor_xiaomi_xuanyuan` private reposu **git-lfs** kullanıyor
(`.gitattributes`: `*.apk filter=lfs`). `git lfs pull` çalıştırılmazsa APK'lar
**131 baytlık pointer stub** olarak kalır — build bozuk APK paketler, hatta
`zip`/aapt hatası verir.

→ `sync_proprietary.sh` ve `install_vendor_tree.sh`'e **LFS stub tespiti** eklendi:
`find "$PRIV" -name "*.apk" -size -1k` → eşleşme varsa **hata verip durur**.

Gerçek boyut doğrulaması: `git lfs pull` sonrası `MiuiCamera.apk` = **200.529.115 byte**,
repo toplamı 446 MB.

---

## 5. Erişim durumu (canlı doğrulama)

| Kaynak | Durum |
|---|---|
| `xiaomi-8750/proprietary_vendor_xiaomi_xuanyuan` (public, vendor ağacı) | ✅ erişilebilir, `beryl` branch'i |
| `krmmyvz/proprietary_vendor_xiaomi_xuanyuan` (private, payload) | ✅ GitHub bağlandı (krmmyvz) → erişilebilir, LFS ile 446 MB |
| `krmmyvz/kernel_xiaomi_generic` | ✅ 7/7 prebuilt dosya mevcut |
| `krmmyvz/device_xiaomi_sm8750_common` | ✅ yapı düzeltildi ve push edildi |
| OpenCode kanalı (`100.64.0.2:4096`) | ✅ parola doğrulandı (Basic auth) |

> Not: private repo'nun README'si `proprietary/` (5392 blob) ve `Android.bp`'yi
> anlatıyor ama bunlar **private repoda yok** — public `xiaomi-8750` reposundadır.
> İki repo farklı görevler üstlenir; `install_vendor_tree.sh` ikisini ayırır.

---

## 6. Disk gerçekleri (canlı ölçüm, PVE1)

| Depolama | Boyut | Boş | Hız |
|---|---|---|---|
| NVMe `local-lvm` | 476 GB | ~180 GB | 487 MB/s |
| ironwolf1 (SATA NAS) | 3.7 TB | **1.35 TB** | 157 MB/s |

Tam build için ~270 GB (kaynak 131 + out 138) gerekiyor.
NVMe tek başına **yetersiz** → kaynak ağacı NAS'a, `out/` NVMe'de
(veya tamamı NAS'a) yerleştirmek gerekiyor.
