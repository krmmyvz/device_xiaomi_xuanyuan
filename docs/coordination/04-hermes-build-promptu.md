# Hermes'e verilecek prompt — xuanyuan build

> Bu dosya `krmmyvz/device_xiaomi_xuanyuan` deposundaki `docs/coordination/`
> klasöründe durur; Hermes'e prompt olarak kopyalanır.

---

Aşağıdaki metni Hermes'e doğrudan ilet. Kutu içindeki her şey onun için
bağlam; kendi yazdığın ek notları en sona ekle.

---

## xuanyuan (Xiaomi 15 Ultra) ROM — build'i al

Ağaç derlemeye hazırlandı. Aşağıdaki düzeltmeler yapıldı, build'i sen
alacaksın. Önce doğrulama komutlarını çalıştır, sonra build.

### 1. Ortam

| | |
|---|---|
| Build VM | `aosp-build` = **192.168.1.122** (LAN) / **100.64.0.13** (tailnet) |
| Kullanıcı | `root` / parola `root` |
| Erişim | `sshpass -p root ssh -o StrictHostKeyChecking=accept-new root@192.168.1.122` |
| Kaynak | `/mnt/src` (138 GB / 295 GB dolu) |
| Çıktı | `/mnt/out` — `/mnt/src/out` symlink'i ona bakıyor |
| Donanım | 4 vCPU, 15 GB RAM + 16 GB swap |
| Ortam | `GOGC=50`, `GOMEMLIMIT=8GiB`, `USE_CCACHE=1`, `CCACHE_DIR=/mnt/out/ccache` (`/etc/profile.d/aosp-build.sh`) |

**SSH uyarısı — önemli:** sshd `MaxStartups` yüzünden hızlı arka arkaya
bağlantılarda "Permission denied" alıyorsun. Bağlantılar arası **~75 saniye
bekle**, her seferinde **tek bağlantı** aç, içine tek komut yaz. Bu bir
hata değil, limiter.

### 2. Düzeltilenler (5 kök neden)

**a) `repo sync` tamamen onarıldı — kök neden: manifest pinning**
`.repo/manifests/default.xml`'i elle değiştirmek kalıcı değildi; repo onu
manifest deposunun git'inden geri yüklüyor, birleşik manifest bayat
kalıyor ve 21 proje `reference broken` ile kilitleniyordu. Yerel manifest
aynı `path`'i de tanımlayamıyor (`duplicate path`). Çözüm: pinned
manifest `.repo/local_manifests/` içine **include** edilmiyor, onun yerine
`scripts/generate_local_manifest.py` her platform projesini
`<extend-project name=… path=… revision=…/>` ile pinliyor.
`path=` zorunlu: `LineageOS/android_hardware_qcom_display` iki yolda duruyor
(`sm8450-6.6` ve `sm8750`), revision'ları farklı. Fork değişimleri
(AOSPA) atlanıyor — `extend-project` depoyu isimle belirlediği için fork'un
SHA'sı orijinal depoda yok.

**b) Vendor ağacı değiştirildi**
`xiaomi-8750/proprietary_vendor_xiaomi_xuanyuan@beryl` **eksik**ti: kendi
AIDL mirror kütüphaneleri (`composer3-V2/V3`, `offlinecamera-V2`,
`camera.device-V2`, `camera.metadata-V2`) hiç yok, halbuki sm8750 CAF'in
`cc_defaults`'i ve kendi `Android.bp`'si onları gerektiriyor. Üstelik
kendi içinde tutarsız: composer binary'si composer3 V3 istiyor,
ürettiği `Android.bp` ise V4 yazıyor. Yerine cihazdan üretilmiş
**OS4.0.0.6** ağacı kuruldu (5478 blob, 2213 prebuilt, 5364 vendor.mk
kuralı). Bu dizin artık **repo projesi değil**, artifact yönetiminde —
`repo sync` ona dokunmuyor, **elle de dokunma**.

**c) AIDL sürüm çakışmaları kapandı**
Platform A16 tüm sürümleri üretiyor (composer3 V1–V4, camera.device
V1–V3, allocator V1–V2). Hata "sürüm eksik" değil, "bir modül iki sürümü
birden çekiyor". 33 `_vendor` AIDL referansı doğrudan platform modülüne
yönlendirildi, 4 çift sürüm referansı düşürüldü, 13 tanımsız kütüphane
referansı (Xiaomi iç kaynak modülleri — `libtinyxml2-neoteric`,
`libframemasterintf`, `vendor.xiaomi.hardware.postprocservice-*` gibi hiçbir
yerde yok) kaldırıldı/eşlendi.

**d) Tensorflow yamasi geri alındı**
`external__tensorflow.patch` `libtensorflowlite_c` modülünü **silen**
varyanttı; vendor'ın kamera AI blob'ları o modüle bağlı. XNNPACK
varyantına dönüldü (`libtensorflowlite_c` korunuyor, delegate ekleniyor).

**e) Namespace genişletmesi**
`PRODUCT_SOONG_NAMESPACES` + cihaz ağacının `Android.bp` `imports`
listesi: `hardware/qcom-caf/sm8750` ve `vendor/xiaomi/xuanyuan` eklendi.
Bunlar olmadan vendor modülleri "depends on undefined module" veriyor.

### 3. Repolar ve commit'ler

| Repo | HEAD |
|---|---|
| `krmmyvz/device_xiaomi_xuanyuan` (public) | **`50c5148`** |
| `krmmyvz/proprietary_vendor_xiaomi_xuanyuan` (private) | **`2987311`** |

VM'deki cihaz ağacı `50c5148`'de, `git status` temiz.

### 4. Build öncesi doğrulama (~2 dk, build çalıştırmaz)

```bash
cd /mnt/src
python3 device/xiaomi/xuanyuan/scripts/find_undefined_libs.py        # -> TANIMSIZ REFERANS: 0
python3 device/xiaomi/xuanyuan/scripts/find_aidl_version_conflicts.py  # -> AIDL surum cakismasi yok
```

Bunlar Soong'un vereceği iki hata sınıfını build'i çalıştırmadan yakalar.
Sıfırdan farklıysa **build'e başlama**, önce düzelt.

### 5. Build

```bash
cd /mnt/src
source build/envsetup.sh
lunch lineage_xuanyuan-bp4a-userdebug
m -j4
```

- `lunch lineage_xuanyuan-bp4a-userdebug` doğru hedef: birleşik manifest'te
  `RELEASE_PLATFORM_VERSION=BP4A`. Ürün adı `lineage_xuanyuan`'dur, sadece
  release config'i bp4a'dır.
- **`m evolution` YOK** — bu platform ağacında `evolution` hedefi tanımlı
  değil. Düz `m` kullan. (Eski ipuçlarında `m evolution` yazıyordu, hatalı.)
- `-j4` (4 vCPU). `GOMEMLIMIT=8GiB` swap'e yaslanıyor; 15 GB RAM var.
- İlk hata geldiğinde **dur ve raporla**, kendi başına yeniden deneme.

### 6. Tuzaklar

1. **`.repo/manifests/default.xml`'i elle değiştirme.** Repo onu geri
   yükler ve pinned projeler birleşik manifestten kaybolur.
2. **`repo init` çalıştıracaksan** önce
   `python3 device/xiaomi/xuanyuan/scripts/generate_local_manifest.py /mnt/src`
   ile `.repo/local_manifests/local_manifests.xml`'i üret, sonra
   `repo init -u https://github.com/Evolution-X/manifest -b bka --depth=1`.
   Aksi halde `extend-project element specifies non-existent project` hatası
   alırsın.
3. **`vendor/xiaomi/xuanyuan`'a elle dokunma** ve manifest'e geri ekleme.
   Bu dizin artifact yönetiminde; `repo sync` sildiği için yeniden
   kurman gerekirse `work/vendor-tree` artifact'inden `install_vendor_tree.sh`
   ile geri gelir.
4. **Yamaları uygulama sırası:** `repo sync` → `apply_platform_patches.sh`.
   Yamalı projelerde (`external/conscrypt`, `system/ca-certificates`)
   `repo sync` "cannot overwrite a local work tree" verir; `repo sync
   --force-sync <proje>` + yamaları yeniden uygula.
5. **SSH:** bağlantılar arası ~75 sn bekle (yukarıya bak).
6. Build logları `/mnt/out/` altında; `out/soong/` altındaki
   `*.ninja.glob_results` ve hata logları el verir.

### 7. Ne raporlayacaksın

1. İlk hatanın **tam metni** (Soong/Soong analiz hatası mı, derleme hatası
   mı).
2. `find_undefined_libs.py` ve `find_aidl_version_conflicts.py` çıktısı.
3. Hata vendor ağacındaysa: hatanın geldiği modülün `Android.bp` bloğu ve
   ilgili `shared_libs` girdileri. Çözüm `fix_undefined_lib_refs.py` /
   `fix_aidl_vendor_refs.py` ile otomatik olabilir; önce raporla.
4. Platform tarafındaysa: hangi `extend-project` revision'ının yanlış
   olduğu — pinned manifest `build-support/evox-manifest-pinned.xml` içinde.

Düzeltmeleri `krmmyvz/device_xiaomi_xuanyuan` deposuna commit + push et
(git identity: Kerem Yavuz <keremyvz58@gmail.com>). Platform yamalarını
değiştiriyorsan `.base` SHA'larını da güncelle — `verify_patch_bases.py`
24/24 tutuyor olmalı.

---
