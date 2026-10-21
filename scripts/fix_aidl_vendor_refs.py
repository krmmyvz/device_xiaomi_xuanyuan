#!/usr/bin/env python3
"""
Vendor Android.bp'deki AIDL '_vendor' referanslarini duzeltir.

Cikartma araci, vendor/lib64 icindeki AIDL stub kutuphanelerini
'X-V<n>-ndk_vendor' adiyla tanimlar ve modullere bagimlilik olarak
yazar. Boylece bir modul hem X-V1-ndk_vendor hem X-V2-ndk_vendor
yaziyorsa Soong iki surumlu bagimlilik hatasini verir:

  depends on multiple versions of the same aidl_interface:
  android.hardware.graphics.allocator-V1-ndk-source,
  android.hardware.graphics.allocator-V2-ndk-source

Platformun AIDL arayuzleri frozen olsa da tum surumleri uretildigi
icin (allocator V1+V2, camera.device V1-V3, composer3 V1-V4) '_vendor'
varyantina gerek yok: dogrudan platformun modulune baglanilabilir.
Xiaomi'nin kendi vendor Android.bp'si de boyle yapiyor.

Kurallar:
  1) X-V<n>-ndk_vendor  ->  X-V<n>-ndk   (platformda varsa)
  2) ayni modulde ayni arayuzun birden fazla surumu kalirsa
     en yuksek surum tutulur, digerleri dusurulur.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
VENDOR = TREE / "vendor/xiaomi/xuanyuan/Android.bp"
LIB_KEYS = ("shared_libs", "static_libs", "header_libs", "whole_static_libs")
VENDOR_RE = re.compile(r"^(?P<base>.+)-V(?P<v>\d+)-ndk_vendor$")


def platform_versions() -> dict[str, set[int]]:
    """Arayuz adi -> platformda mevcut surumler."""
    out: dict[str, set[int]] = {}
    for bp in TREE.rglob("Android.bp"):
        p = str(bp)
        if "/.repo/" in p or "/out/" in p:
            continue
        try:
            t = bp.read_text(errors="replace")
        except OSError:
            continue
        for m in re.finditer(r"aidl_interface\s*\{(.*?)\n\}", t, re.S):
            nm = re.search(r'name:\s*"([^"]+)"', m.group(1))
            if not nm:
                continue
            for v in re.findall(r'version:\s*"([0-9]+)"', m.group(1)):
                out.setdefault(nm.group(1), set()).add(int(v))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    if not VENDOR.is_file():
        print(f"vendor Android.bp yok: {VENDOR}")
        return 1

    vers = platform_versions()
    src = VENDOR.read_text()

    # 1) vendor -> platform eslemesi
    mapping: dict[str, str] = {}
    for name in set(re.findall(r'"([^"]*-ndk_vendor)"', src)):
        m = VENDOR_RE.match(name)
        if not m:
            continue
        base, v = m.group("base"), int(m.group("v"))
        if v in vers.get(base, set()):
            mapping[name] = f"{base}-V{v}-ndk"
    print(f"platforma eslenen _vendor referans: {len(mapping)}")

    # 2) modul modulde ayni arayuzun coklu surumunu azalt
    # ONCE isimleri platform adina cevir, SONRA dusur: aksi halde dusurme
    # regex'i eski '_vendor' adini arar ve isabet etmez.
    out = src
    for old_name, new_name in mapping.items():
        out = out.replace(f'"{old_name}"', f'"{new_name}"')
    n_map = len(mapping)
    n_drop = 0
    for m in re.finditer(r'name:\s*"([^"]+)"(.*?)(?=\n\}\n)', out, re.S):
        mod, body = m.group(1), m.group(2)
        libs: list[str] = []
        for key in LIB_KEYS:
            for lm in re.finditer(rf"{key}\s*:\s*\[(.*?)\]", body, re.S):
                libs += re.findall(r'"([^"]+)"', lm.group(1))
        if not libs:
            continue
        resolved = [mapping.get(x, x) for x in libs]
        # arayuz bazinda en yuksek surumu tut
        best: dict[str, tuple[int, str]] = {}
        for x in resolved:
            mv = re.match(r"^(.+)-V(\d+)-ndk$", x)
            if not mv:
                continue
            base, v = mv.group(1), int(mv.group(2))
            if base not in best or v > best[base][0]:
                best[base] = (v, x)
        keep = {x for _, x in best.values()}
        drop = [x for x in resolved if x not in keep and re.match(r"^.+-V\d+-ndk$", x)]
        if not drop:
            continue
        for d in set(drop):
            out = re.sub(rf'^[ \t]*"{re.escape(d)}",?[ \t]*\n', "", out, flags=re.M)
            out = re.sub(rf',[ \t]*\n?[ \t]*"{re.escape(d)}"', "", out)
            n_drop += 1

    if args.apply:
        VENDOR.write_text(out)
        print(f"uygulandi: {n_map} esleme, {n_drop} dusurme")
    else:
        print("(rapor; uygulamak icin --apply)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
