#!/usr/bin/env python3
"""
Platform AIDL arayuzlerinin 'vendor' varyantini kapatir, boylece vendor
prebuilt'i ayni dosya adini tek kaynak olarak kurar.

SORUN
-----
Platform AIDL'i 'vendor: true' / 'vendor_available: true' oldugunda Soong
vendor partition'da da '-ndk' modulu uretir:

  out/target/product/xuanyuan/vendor/lib64/vendor.qti.hardware.agm-V1-ndk.so

Vendor agacindaki stok prebuilt de AYNI dosya adini kuruyor (stem ile):

  name: "xiaomi.prebuilt.vendor.qti.hardware.agm-V1-ndk",
  stem: "vendor.qti.hardware.agm-V1-ndk",

Iki modul ayni ciktiyi uretir -> ninja hatasi:

  FAILED: ninja: multiple rules generate
  out/target/product/xuanyuan/vendor/lib64/vendor.qti.hardware.agm-V1-ndk.so

COZUM
-----
Platform AIDL'inden 'vendor: true' / 'vendor_available: true' kaldirilir.
Boylece platform yalnizca 'system' partition'inda uretir; vendor partition
için tek kaynak vendor prebuilt'i olur. Platform modulleri (orn.
'aidlconverter') ayni adi tasiyan vendor prebuilt'e baglanir.

Idempotenttir.
"""
from __future__ import annotations

import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")

# platform dosyasi -> AIDL adi
TARGETS = {
    "hardware/qcom-caf/sm8750/audio/agm/ipc/aidl/Android.bp": "vendor.qti.hardware.agm",
    "hardware/qcom-caf/sm8750/audio/pal/ipc/aidl/Android.bp": "vendor.qti.hardware.pal",
    "hardware/xiaomi/interfaces/xiaomi/hw/touchfeature/aidl/Android.bp":
        "vendor.xiaomi.hw.touchfeature",
    "hardware/xiaomi/interfaces/xiaomi/hardware/fingerprintextension/aidl/Android.bp":
        "vendor.xiaomi.hardware.fingerprintextension",
}


def main() -> int:
    total = 0
    for rel, aidl in TARGETS.items():
        p = TREE / rel
        if not p.is_file():
            print(f"[!] dosya yok, ATLANDI: {rel}")
            continue
        txt = p.read_text(errors="replace")
        orig = txt

        # aidl_interface blogunu bul
        m = re.search(r'aidl_interface\s*\{\s*\n\s*name:\s*"%s",' % re.escape(aidl), txt)
        if not m:
            print(f"[!] {aidl}: aidl_interface bulunamadi, ATLANDI")
            continue
        start = txt.rfind("{", 0, m.end())
        depth = 0
        i = start
        while i < len(txt):
            if txt[i] == "{":
                depth += 1
            elif txt[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        block = txt[start:i + 1]

        new_block = block
        # vendor / vendor_available satirlarini kaldir
        removed = []
        for line in ("    vendor: true,\n", "    vendor_available: true,\n"):
            if line in new_block:
                new_block = new_block.replace(line, "")
                removed.append(line.strip())

        if removed:
            txt = txt[:start] + new_block + txt[i + 1:]
            p.write_text(txt)
            print("[+] %s: %s kaldirildi" % (aidl, ", ".join(removed)))
            total += 1
        else:
            print("[=] %s: zaten vendor varyanti kapali" % aidl)

    print("[✓] %d AIDL guncellendi" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
