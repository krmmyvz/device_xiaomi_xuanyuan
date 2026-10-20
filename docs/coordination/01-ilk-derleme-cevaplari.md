# İlk derleme: cevaplar ve minimum reçete

Tarih: 2026-10-20 · taraf: build-agent

---

## 1. `lunch` hedefi ve manifest dalı

**Lunch:** `lineage_xuanyuan-bp4a-userdebug`

`evolution_xuanyuan` **yok** — öyle bir ürün kayıtlı değil. Kaynak:
`device/xiaomi/xuanyuan/AndroidProducts.mk:11-15` (COMMON_LUNCH_CHOICES) ve
`lineage_xuanyuan.mk:17` (PRODUCT_NAME := lineage_xuanyuan).

**Manifest dalı:** `bka` (Evolution-X). Kaynak:
`build-support/evox-manifest-pinned.xml` → `<remote name="evo" fetch="https://github.com/Evolution-X" revision="refs/heads/bka"/>`.

**`m evolution` hakkında:** EvoX ağacının kendi README'si `m evolution -j4` diyor
(`README.md:38`), ama `evolution` target'inin **tanımını bulamadım** (EvoX `build/make`
`target/product/` altında yok, `build/release` yalnız `release_config_map.mk` içeriyor).
→ **Emin değilim.** İlk derlemede garantili formül `m lineage_xuanyuan` (kayıtlı ürün,
her zaman çalışır). `m evolution` yama özgü ek bir şeyse `m lineage_xuanyuan` sonrası
gerekmez; çalışmazsa `m lineage_xuanyuan`'a düş.

**`bp4a` geçerli:** pinned `build/release` @ d76088e5 (lineage-23.2) içinde
`aconfig/bp4a/` ve `release/flag_values/bp4a/` mevcut. ✓

---

## 2. JDK

**JDK 17.** Ubuntu 24.04'ün varsayılanı 21 olduğu için **açıkça `openjdk-17-jdk`
kurulmalı** ve `JAVA_HOME` sabitlenmeli (AOSP 14/15/16 → 17; JDK 21 AOSP 17+ ile geliyor).

**Birincil kaynaktan doğrulayamadım** (gitiles'te `android-16.0.0_r4` etiketi 404 verdi,
AOSP docs sayfaları JS ile render ediliyor). Yüksek güven, ama kesin değil.
Ucuz doğrulama: `m nothing` yanlış JDK'da **anında** net bir hata mesajı verir.

`provision_build_host.sh` bunu zaten yapıyor (openjdk-17-jdk + `/etc/profile.d/jdk17.sh`).

---

## 3. `.base` SHA'ları

**TUTUYOR — 24/24 ESIT.** Doğrulandı ve artık betikleştirildi:

```
scripts/verify_patch_bases.py    # pinned manifest ile karşılaştırır, çıkış kodu 1 = uyuşmazlık
```

**Sessizce atlama sorunu giderildi.** `apply_platform_patches.sh` artık:
- başta `verify_patch_bases.py` çalıştırır, uyuşmazlık varsa **exit 1** verir
- base SHA HEAD ile eşleşmiyorsa: base commit repoda varsa otomatik checkout eder,
  yoksa **hata verir** (eskiden "atlandı" deyip exit 0 ile devam ediyordu)

→ **24 yama uygulanacak**, sessizce atlanma riski kalmadı.

---

## 4. patch→proje eşlemesi

**DOSYA ADINDAN TÜRETME DOĞRU.** Önceki "hatalı" iddiam yanlıştı.

Kanıt: `LineageOS/android_vendor_lineage` (pinned `vendor/lineage`, rev 4d7dcd1a) içinde
gerçekten şunlar var:
- `build/soong/Android.bp`
- `release/flag_values/bp4a/RELEASE_PLATFORM_SECURITY_PATCH.textproto`

Yani `vendor__lineage.patch` içindeki diff yolları **`vendor/lineage` proje köküne göre**
relative. `vendor/lineage` → `vendor__lineage` eşlemesi doğru.

Ek kontrol: 24 patch'in **hiçbiri** iki projeye yayılmıyor (hepsi tek proje içinde),
ve **aynı proje+dosyaya dokunan patch çakışması yok**.

---

## İlk derleme için minimum (PVE1, VM)

```bash
# 1) ortam
sudo bash scripts/provision_build_host.sh --swap-gb 16 --ccache-gb 40

# 2) kaynak
repo init -u https://github.com/Evolution-X/manifest -b bka
mkdir -p .repo/local_manifests
cp <tree>/build-support/evox-manifest-pinned.xml .repo/local_manifests/
cp <tree>/build-support/local_manifests.xml       .repo/local_manifests/
repo sync -c --depth=1 -j$(nproc)          # ~131 GB; --depth=1 .git'i kucultur

# 3) vendor blob agaci (cihazdan uretilmis, git disi)
bash <tree>/scripts/install_vendor_tree.sh

# 4) platform patch'leri  (base uyusmazliginda DURUR)
bash <tree>/scripts/apply_platform_patches.sh

# 5) derle
source build/envsetup.sh
lunch lineage_xuanyuan-bp4a-userdebug
m lineage_xuanyuan -j4      # veya: m evolution -j4
```

### Disk gerçekleri (PVE1: 180 GB boş NVMe + 1.4 TB boş USB HDD)

| Aşama | Disk |
|---|---|
| `repo sync -c --depth=1` | ~100-131 GB |
| `m vendor/xiaomi/xuanyuan` (sadece vendor) | ~+10 GB |
| `m nothing` (build grafiği) | ~+2 GB |
| **tam `m lineage_xuanyuan`** | **+138 GB → toplam ~270 GB** |

→ **180 GB'lık NVMe'de tam derleme SIĞMAZ.** İki seçenek:
- (a) `OUT_DIR` ayrı diske: `export OUT_DIR=/mnt/usb-hdd/out` (disk yavaş, USB HDD)
- (b) **1 TB SATA SSD'yi bekle** (boş 2.5" yuva doğrulandı) — önerilen
- (c) şimdilik sadece `m vendor/xiaomi/xuanyuan` + `m nothing` → **~145 GB ile sığar**,
      build grafiğini ve vendor ağacını doğrular, tam build SSD'ye kadar bekler

**(c) ilk adım için önerim** — 180 GB'de yapılabilir ve platform patch'lerinin
gerçekten uygulanıp uygulanmadığını ortaya çıkarır.

### RAM

`soong_build` tek başına 24-26 GB istiyor. PVE1'de 23.5 GB toplam, 7.4 GB servislerde
→ **VM 16 GB + 16 GB swap** (host swap'ı kullan, VM içi 32 GB gereksiz).

### Emin olmadıklarım (kırmızı bayrak)

- `m evolution` target'inin tanımı (bkz. §1) → `m lineage_xuanyuan` kullan
- JDK sürümü — birincil kaynaktan doğrulanamadı (§2) → `m nothing` ile ucuz doğrulama
- Tam derlemenin **gerçekten bitip bitmeyeceği** — bu ağaçta **hiç derleme çalıştırılmadı**
  (ne benim, ne upstream yazarın; upstream'ın kendi notu: *"A full ROM build or flash
  was not performed"*). Doğrulanan: vendor ağacı 5392/5392 blob, tüm yol referansları
  çözülüyor, 24/24 base SHA tutuyor. **İlk `m` gerçek hataları yüzeye çıkaracak** —
  en olası yer: platform patch'leri (Settings patch'i 472 satır).
