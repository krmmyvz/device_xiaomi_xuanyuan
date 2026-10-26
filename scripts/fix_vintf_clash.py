#!/usr/bin/env python3
"""
Platform <-> vendor arasindaki VINTF XML modul ad cakismalarini giderir.

SORUN
-----
Cihaz agaci 'vendor/xiaomi/xuanyuan' namespace'ini import eder. Vendor agaci
ile platform qcom projeleri ayni modul adlarini tanimladiginda Soong hatasi
verir:

  error: module "X" variant "android_vendor_arm64_armv8-a": found in multiple
  namespaces(hardware/qcom-caf/sm8750 and vendor/xiaomi/xuanyuan) when
  including in vendor partition

COZUM
-----
Platform tarafindaki tanim '-xuanyuan' son ekiyle yeniden adlandirilir.
KURULAN DOSYA ADI korunur:
  - prebuilt_etc / prebuilt_etc_xml -> 'filename: "<eski ad>"'
  - filegroup                        -> dosya adi degismez (filegroup yalnizca
    bir etikettir; 'srcs' degismez)

Ayrica ayni modul adi 'vintf_fragments' / 'init_rc' gibi referanslarda
geciyorsa o referanslar da guncellenir.

Kapsam: YALNIZCA platform tarafi. Vendor agaci (artifact) ve cihaz agaci
dokunulmaz.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
SUFFIX = "-xuanyuan"

# platform dosyasi -> [(eski modul adi, blok tipi)]
TARGETS = {
    "hardware/qcom-caf/sm8750/audio/primary-hal/hal/default/Android.bp": [
        ("manifest_audiocorehal_default.xml", "prebuilt_etc"),
    ],
    "hardware/qcom-caf/bootctrl/aidl/Android.bp": [
        ("boot-service.qti.xml", "filegroup"),
    ],
}

# 'filename' destekleyen blok tipleri
FILENAME_TYPES = ("prebuilt_etc", "prebuilt_etc_xml", "sh_binary")


def rename_in_file(path: pathlib.Path, pairs, apply: bool) -> int:
    if not path.is_file():
        print(f"[!] dosya yok, ATLANDI: {path}")
        return 0
    txt = path.read_text(errors="replace")
    orig = txt
    n = 0
    for old, typ in pairs:
        if f'name: "{old}"' not in txt:
            continue
        new = old + SUFFIX
        txt = txt.replace(f'name: "{old}"', f'name: "{new}"')
        if typ in FILENAME_TYPES:
            # 'filename' ile kurulan dosya adini koru
            if not re.search(r'\bfilename:\s*"', txt):
                txt = re.sub(
                    r'(name:\s*"%s",\n)' % re.escape(new),
                    lambda m: m.group(1) + f'    filename: "{old}",\n',
                    txt,
                    count=1,
                )
        # Referanslari guncelle (":modul" bicimi ve dogrusal ad)
        txt = re.sub(r'":%s"' % re.escape(old), f'":{new}"', txt)
        txt = re.sub(r'":%s"' % re.escape(new), f'":{new}"', txt)
        print(f"[+] {old} -> {new} ({typ})  [{path.relative_to(TREE)}]")
        n += 1
    if txt != orig and apply:
        path.write_text(txt)
    return n


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    total = 0
    for rel, pairs in TARGETS.items():
        total += rename_in_file(TREE / rel, pairs, args.apply)

    if args.apply:
        print(f"[✓] {total} tanim yeniden adlandirildi")
    else:
        print(f"(rapor; uygulamak icin --apply) {total} tanim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
