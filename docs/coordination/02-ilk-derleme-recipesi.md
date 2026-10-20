# İlk derleme — cevaplar ve reçete

Taraf: build-agent · Tarih: 2026-10-20

---

## 1. `lunch` hedefi

**`lineage_xuanyuan-bp4a-userdebug`** — `evolution_xuanyuan-*` diye bir lunch **yok**.

Kanıt:
- `AndroidProducts.mk:8-11` → `COMMON_LUNCH_CHOICES := lineage_xuanyuan-{user,userdebug,eng}`
- `lineage_xuanyuan.mk:19` → `PRODUCT_NAME := lineage_xuanyuan`

**Manifest dalı: `bka`** (Evolution-X). Pinned manifest'te `build/make` ve `build/soong`
için `remote="evo" upstream="refs/heads/bka"`.

**`m evolution` build hedefidir** (lunch değil) — `README.md:38`.
⚠️ **Emin değilim** tanımını pinned ağaçta bulamadım (`build/make/target/product/`'da
`evolution.mk` yok, `build/release` yalnız `release_config_map.mk` içeriyor).
→ İlk denemede `m evolution` "target not found" derse **fallback: `m lineage_xuanyuan`**
(kayıtlı ürün olduğu için her zaman çalışır).

## 2. JDK

**JDK 17.** Ubuntu 24.04'ün varsayılanı **21** olduğu için `openjdk-17-jdk` açıkça
kurulmalı, `JAVA_HOME` sabitlenmeli.

⚠️ **Emin değilim** bunu pinned kaynakta doğruladığıma dair (gitiles'te
`android-16.0.0_r4` etiketi 404 verdi, soong/make içinde JDK sabitini bulamadım).
Yüksek güven (AOSP 14/15/16 = JDK 17; 21 ancak AOSP 17+ ile).
**Ucuz doğrulama:** `m nothing` yanlış JDK'da anında net hata verir.

## 3. `.base` SHA'ları

**24/24 pinlenmiş manifestle birebir tutuyor** → 24 yamanın hepsi uygulanacak.

Doğrulama betiği eklendi: `scripts/verify_patch_bases.py` (pinned manifestle karşılaştırır).

**Sessizce atlama riski giderildi:** `apply_platform_patches.sh` artık önce base
doğrulaması çalıştırıyor ve uyuşmazlıkta **exit 1** veriyor. (Eskiden "atlandı" deyip
exit 0 ile devam ediyordu.) Eski base commit repoda varsa otomatik checkout deniyor.

## 4. patch→proje eşlemesi

**Dosya adından türetme DOĞRU — değişiklik gerekmiyor.**
(Önceki "hatalı" iddiam yanlıştı; hata kendi analizimdeydi.)

Kanıt: pinned `LineageOS/android_vendor_lineage` içinde gerçekten
`build/soong/Android.bp` ve `release/flag_values/bp4a/RELEASE_PLATFORM_SECURITY_PATCH.textproto`
var. Patch'lerin `diff --git` yolları **proje köküne göre** relative.
`vendor__lineage.patch` iki projeye değil, tek projeye (`vendor/lineage`) dokunuyor.
Ayrıca: 24 patch'in hiçbiri iki projeye yayılmıyor, aynı proje+dosya çakışması yok.

---

## İlk derleme reçetesi

```bash
# 1) ortam
sudo bash scripts/provision_build_host.sh --swap-gb 16 --ccache-gb 40

# 2) kaynak (~131 GB)
repo init -u https://github.com/Evolution-X/manifest -b bka
mkdir -p .repo/local_manifests
cp <tree>/build-support/evox-manifest-pinned.xml .repo/local_manifests/
cp <tree>/build-support/local_manifests.xml       .repo/local_manifests/
repo sync -c --depth=1 -j$(nproc)

# 3) vendor blob agaci (cihazdan uretilmis, git disi)
bash <tree>/scripts/install_vendor_tree.sh

# 4) platform patch'leri (base uyusmazliginda DURUR)
bash <tree>/scripts/apply_platform_patches.sh

# 5) derle
source build/envsetup.sh
lunch lineage_xuanyuan-bp4a-userdebug
m lineage_xuanyuan -j4        # veya: m evolution -j4
```

### Disk (PVE1: 180 GB boş NVMe + 1.4 TB boş USB HDD)

| Aşama | Disk |
|---|---|
| `repo sync -c --depth=1` | ~100-131 GB |
| `m vendor/xiaomi_xuanyuan` | ~+10 GB |
| `m nothing` (build grafiği) | ~+2 GB |
| tam `m lineage_xuanyuan` | +138 GB → **toplam ~270 GB** |

→ **180 GB'a tam derleme SIĞMAZ.** Önerilen sıra:
1. **şimdi:** `m vendor/xiaomi/xuanyuan` + `m nothing` → ~145 GB'de sığar, vendor ağacını
   ve build grafiğini doğrular, **24 yamanın gerçekten uygulanıp uygulanmadığını** gösterir
2. **sonra (1 TB SATA SSD gelince):** tam build

Alternatif: `export OUT_DIR=/mnt/usb-hdd/out` (yavaş ama çalışır).

### RAM

`soong_build` tek başına 24-26 GB istiyor. PVE1'de 23.5 GB toplam, 7.4 GB servislerde
→ **VM 16 GB + 16 GB swap** (host swap'ı kullan; VM içi 32 GB gereksiz).

### Kırmızı bayraklar

- **`m evolution` tanımı bulunamadı** (§1) → `m lineage_xuanyuan` fallback'i
- **JDK sürümü birincil kaynaktan doğrulanamadı** (§2) → `m nothing` ile ucuz doğrulama
- **Bu ağaçta hiç derleme çalıştırılmadı** (ne benim, ne upstream yazarın; upstream'ın
  kendi notu: *"A full ROM build or flash was not performed"*).
  Doğrulanan: vendor ağacı 5392/5392 blob, tüm yol referansları çözülüyor, 24/24 base tutuyor.
  İlk `m` gerçek hataları yüzeye çıkaracak — en olası yer platform patch'leri
  (`packages__apps__Settings` patch'i 472 satır, en büyüğü).
