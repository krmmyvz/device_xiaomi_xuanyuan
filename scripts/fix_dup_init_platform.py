#!/usr/bin/env python3
"""
Platform qcom projelerindeki init SCRIPT tanimlarini yeniden adlandirir.

SORUN
-----
device/xiaomi/xuanyuan/rootdir/Android.bp, platform qcom projelerinden
kopyalanmis init script tanimlarini icerir. Ayni modul adi iki namespace'te
tanimlanir ve Soong hatasi verir:

  error: module "init.qti.display_boot.sh" variant
  "android_vendor_arm64_armv8-a": found in multiple namespaces
  (hardware/qcom-caf/sm8750 and device/xiaomi/xuanyuan) when including in
  vendor partition

COZUM
-----
Yalnizca CIHAZ AGACINDA KARSILIGI OLAN moduller yeniden adlandirilir
(şu an: init.qti.display_boot.sh, init.qti.media.sh, init.qcom.usb.sh).
'filename' alani ile KURULAN DOSYA ADI korunur:

  name: "init.qti.display_boot.sh"
  -> name: "init.qti.display_boot.sh-xuanyuan"
     filename: "init.qti.display_boot.sh"

Boylece:
  - Soong modul adi benzersiz olur, namespace cakismasi biter
  - kurulan dosya adi degismez -> init.rc referanslari bozulmaz
  - cihaz agacindaki GUNCELENMIS kopya kurulmaya devam eder

'.rc' dosyalarina dokunulmaz: cihaz agacinda karsiliklari YOK, dolayisiyla
cakisma yaratmazlar ve platformdan kurulmalarilardir.

Kurulum listeleri (.mk) de yeni adi kullanacak sekilde guncellenir: aksi
halde yeniden adlandirilan modul kurulmaz.

Kapsam: platform tarafi. Cihaz agacindaki kopyalar dokunulmaz.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
SUFFIX = "-xuanyuan"

# platform projesi yolu -> [(eski modul adi, blok tipi)]
TARGETS = {
    "hardware/qcom-caf/sm8750/display/hal/init/Android.bp": [
        ("init.qti.display_boot.sh", "sh_binary"),
    ],
    "hardware/qcom/sm7250/display/init/Android.bp": [
        ("init.qti.display_boot.sh", "sh_binary"),
    ],
    "hardware/qcom-caf/sm8250/media/media-prop/Android.bp": [
        ("init.qti.media.sh", "sh_binary"),
    ],
    "vendor/qcom/opensource/usb/etc/Android.bp": [
        ("init.qcom.usb.sh", "sh_binary"),
    ],
}

# Kurulum listesi (.mk) dosyalari: yeni adla degistirilecek modul adlari
MK_FILES = [
    "hardware/qcom-caf/sm8750/display/hal/config/display-modules.mk",
    "hardware/qcom-caf/sm8250/media/product.mk",
    "vendor/qcom/opensource/usb/vendor_product.mk",
    "device/xiaomi/xuanyuan/device.mk",
]


def _block_of(txt: str, name: str) -> str:
    i = txt.find(f'name: "{name}"')
    if i == -1:
        return ""
    depth = 0
    j = i
    while j < len(txt):
        if txt[j] == "{":
            depth += 1
        elif txt[j] == "}":
            depth -= 1
            if depth == 0:
                return txt[i:j]
        j += 1
    return txt[i:]


def rename_in_file(path: pathlib.Path, pairs, apply: bool) -> int:
    if not path.is_file():
        print(f"[!] dosya yok, ATLANDI: {path}")
        return 0
    txt = path.read_text(errors="replace")
    orig = txt
    n = 0
    for old, kind in pairs:
        if f'name: "{old}"' not in txt:
            continue
        new = old + SUFFIX
        txt = txt.replace(f'name: "{old}"', f'name: "{new}"')
        prop = "filename"  # sh_binary de 'filename' kullanir ('stem' yok)
        block = _block_of(txt, new)
        if block and not re.search(r'\b%s:\s*"' % prop, block):
            txt = re.sub(
                r'(name:\s*"%s",\n)' % re.escape(new),
                lambda m: m.group(1) + f'    {prop}: "{old}",\n',
                txt,
                count=1,
            )
        print(f"[+] {old} -> {new} ({prop})  [{path.relative_to(TREE)}]")
        n += 1
    if txt != orig and apply:
        path.write_text(txt)
    return n


def update_mk(path: pathlib.Path, names, apply: bool) -> int:
    """Kurulum listesindeki modul adini yeni adi kullanacak sekilde degistir."""
    if not path.is_file():
        return 0
    txt = path.read_text(errors="replace")
    orig = txt
    n = 0
    for old in names:
        new = old + SUFFIX
        # 'init.qti.display_boot.sh' -> 'init.qti.display_boot.sh-xuanyuan'
        # Sondaki nokta/eski sonu DEGISTIRILMEZ: 'init.x.sh' regex'i
        # 'init.x.sh-extra' ile eslesmemeli.
        txt = re.sub(
            r'(?<![\w.-])%s(?![\w.-])' % re.escape(old),
            new,
            txt,
        )
        n += 1
    if txt != orig and apply:
        path.write_text(txt)
        print(f"[+] mk guncellendi: {path.relative_to(TREE)}")
    return n


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    total = 0
    all_names = set()
    for rel, pairs in TARGETS.items():
        total += rename_in_file(TREE / rel, pairs, args.apply)
        for old, _ in pairs:
            all_names.add(old)

    for rel in MK_FILES:
        total += update_mk(TREE / rel, all_names, args.apply)

    if args.apply:
        print(f"[✓] {total} degisiklik uygulandi")
    else:
        print(f"(rapor; uygulamak icin --apply) {total} degisiklik")
    return 0


if __name__ == "__main__":
    sys.exit(main())
