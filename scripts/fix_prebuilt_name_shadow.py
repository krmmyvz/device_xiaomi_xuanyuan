#!/usr/bin/env python3
"""
Vendor ağacındaki, platform kaynak modülüyle aynı adı taşıyan prebuilt'leri
'xiaomi.prebuilt.' onekiyle yeniden adlandırır.

SORUN (Soong katalog 4b - partition mismatch)
----------------------------------------------
Soong, 'prebuilt_' oneki tasiyan bir modulun ayni adi tasiyan KAYNAK modulun
yerini aldigini varsayar ve ikisinin AYNI partition'da olmasini ister:

  error: module "vendor.qti.hardware.display.aiqe-V2-ndk" variant
  "android_vendor_arm64_armv8-a" (created by module
  "vendor.qti.hardware.display.aiqe_interface"): partition is different:
  system(vendor.qti.hardware.display.aiqe-V2-ndk) !=
  vendor(prebuilt_vendor.qti.hardware.display.aiqe-V2-ndk)

Kaynak modul platformda 'system' partition'inda uretilir; vendor prebuilt ise
'vendor' partition'inda.

COZUM
-----
Vendor prebuilt'in adi 'xiaomi.prebuilt.<ad>' olur. 'prebuilt_' oneki KALIR
(Soong onu otomatik ekler) ama modul adi artik kaynak modulun adiyla
eslesmez -> gölgeleme olusmaz, partition kontrolune girmez.

Dosya adi 'stem' ile sabitlenir: kurulan .so adı degismez.

Idempotenttir.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
VENDOR = TREE / "vendor/xiaomi/xuanyuan/Android.bp"
PREFIX = "xiaomi.prebuilt."

# Platformda KAYNAK olarak uretilen (vendor_available:false veya baska) ve
# vendor ağacinda prebuilt'i bulunan AIDL kok adlari.
TARGETS = [
    "android.media.audio.common.types-V6-ndk",
    "vendor.qti.hardware.agm-V1-ndk",
    "vendor.qti.hardware.display.aiqe-V2-ndk",
    "vendor.qti.hardware.display.color-V1-ndk",
    "vendor.qti.hardware.display.composer3-V1-ndk",
    "vendor.qti.hardware.display.composer3-V2-ndk",
    "vendor.qti.hardware.display.composer3-V3-ndk",
    "vendor.qti.hardware.display.demura-V1-ndk",
    "vendor.qti.hardware.display.postproc-V1-ndk",
    "vendor.qti.hardware.pal-V1-ndk",
    "vendor.xiaomi.hw.touchfeature-V1-ndk",
]

NAME_RE = re.compile(r'name:\s*"([^"]+)"')
BLOCK = re.compile(r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*\{", re.M)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    if not VENDOR.is_file():
        print(f"vendor Android.bp yok: {VENDOR}")
        return 1

    src = VENDOR.read_text(errors="replace")
    out = src
    n = 0
    for base in TARGETS:
        old_name = f'name: "{base}"'
        if old_name not in out:
            continue
        new_name = f'name: "{PREFIX}{base}"'
        # 1) Once tum referanslari yeni adi cevir (stem dahil - stem'i
        #    sonra ekleyecegiz)
        out = re.sub(r'"%s"' % re.escape(base), '"%s%s"' % (PREFIX, base), out)
        # 2) name alanini yeni adi yap
        out = out.replace(f'name: "{PREFIX}{base}"', new_name)
        # 3) stem yoksa dosya adini sabitle (modul adindan turetilmesin)
        m = re.search(r'name:\s*"%s%s",\n' % (re.escape(PREFIX), re.escape(base)), out)
        if m:
            window = out[m.start(): m.start() + 800]
            block = window.split("},", 1)[0]
            if not re.search(r'\bstem:\s*"', block):
                out = out[:m.end()] + f'    stem: "{base}",\n' + out[m.end():]
        print(f"[+] {base} -> {PREFIX}{base}")
        n += 1

    if args.apply:
        VENDOR.write_text(out)
        print(f"[✓] {n} prebuilt yeniden adlandirildi")
    else:
        print(f"(rapor; uygulamak icin --apply) {n} prebuilt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
