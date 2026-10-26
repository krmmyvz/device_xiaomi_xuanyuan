#!/usr/bin/env python3
"""
Vendor ağacındaki 'xiaomi.prebuilt.' onekiyle yeniden adlandırılan modüllerin
PRODUCT_PACKAGES kayıtlarını yeni adlarla hizalar.

NEDEN
-----
Vendor prebuilt'ler 'xiaomi.prebuilt.<ad>' olarak yeniden adlandırıldığında
(platform kaynak modülüyle isim cakismasini onlemek icin), kurulum
listelerindeki kayitlar da yeni adi kullanmali; aksi halde kati hatasi verir:

  device/xiaomi/xuanyuan/lineage_xuanyuan.mk includes non-existent modules
  in PRODUCT_PACKAGES
    vendor.qti.hardware.display.aiqe-V2-ndk

Kapsam: vendor/xiaomi/xuanyuan/xuanyuan-vendor.mk ve cihaz agacindaki .mk
dosyalari.

Idempotenttir.
"""
from __future__ import annotations

import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")

# 'xiaomi.prebuilt.' onekiyle yeniden adlandirilan moduller
RENAMED = [
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

# guncellenecek .mk dosyalari
MKS = [
    "vendor/xiaomi/xuanyuan/xuanyuan-vendor.mk",
    "device/xiaomi/xuanyuan/device.mk",
    "device/xiaomi/xuanyuan/lineage_xuanyuan.mk",
]


def main() -> int:
    total = 0
    for rel in MKS:
        p = TREE / rel
        if not p.is_file():
            print(f"[!] dosya yok, ATLANDI: {rel}")
            continue
        txt = p.read_text(errors="replace")
        orig = txt
        for m in RENAMED:
            # Sadece kurulum listesi girdilerini degistir: satirin tamami
            # 'X' veya 'X \' seklinde olmali.
            pat = re.compile(r"(?m)^(\s*)%s(\s*\\?\s*)$" % re.escape(m))
            txt, n = pat.subn(lambda mm: mm.group(1) + "xiaomi.prebuilt." + m + mm.group(2), txt)
            if n:
                print("[+] %s: %d kayit guncellendi" % (rel, n))
                total += n
        if txt != orig:
            p.write_text(txt)
    print("[✓] toplam %d kurulum kaydi hizalandi" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
