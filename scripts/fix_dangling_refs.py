#!/usr/bin/env python3
"""
Vendor Android.bp'deki, '_vendor' TANIMI olan modullere PLAIN adla verilen
referanslari '_vendor' adina cevirir.

SORUN
-----
fix_aidl_vendor_refs.py, '_vendor' tanimlarini platform adiyla degistirirken
referanslari da degistirir; ancak bazi referanslar plain kalir. Sonuc:

  error: module "libcolortempmode" ...: depends on multiple versions of the
  same aidl_interface: android.hardware.sensors-V2-ndk-source,
  android.hardware.sensors-V3-ndk-source

Bir modul hem 'X' (tanimsiz, platformdan gelen) hem 'X_vendor' (tanimli
prebuilt) cekerse Soong iki surumlu bagimlilik hatasini verir.

COZUM
-----
Vendor agacinda 'X_vendor' adiyla TANIMLI bir modul varsa, 'X' adiyla
verilen tum referanslar 'X_vendor' olur. Boylece:
  - referans tanimsiz kalmaz
  - tek surumlu bagimlilik zinciri korunur

Idempotenttir.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

VENDOR = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp")
NAME_RE = re.compile(r'name:\s*"([^"]+)"')
BLOCK = re.compile(r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*\{", re.M)
LIB_KEYS = ("shared_libs", "static_libs", "header_libs", "whole_static_libs",
            "libs", "optional_libs", "runtime_libs")


def blocks(txt):
    out = []
    for mm in BLOCK.finditer(txt):
        s = mm.end()
        d = 1
        i = s
        while i < len(txt) and d > 0:
            if txt[i] == "{":
                d += 1
            elif txt[i] == "}":
                d -= 1
            i += 1
        body = txt[s:i]
        nm = NAME_RE.search(body)
        out.append((nm.group(1) if nm else None, mm.group(1), body, s, i))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    if not VENDOR.is_file():
        print(f"vendor Android.bp yok: {VENDOR}")
        return 1

    txt = VENDOR.read_text(errors="replace")
    bl = blocks(txt)

    defined_vendor = {n for n, _, _, _, _ in bl if n and n.endswith("_vendor")}
    plain_needed = {n[:-len("_vendor")] for n in defined_vendor}

    # Platformda AYNI adi tasiyan bir modul varsa plain referans dogrudur
    # (ornegin 'vendor.display.config@1.0' -> platform HIDL'i). Yalnizca
    # platformda HIC tanimli olmayan adlar '_vendor' olmalidir.
    plat_defined = set()
    for bp in pathlib.Path("/mnt/src").rglob("Android.bp"):
        p = str(bp)
        if "/.repo/" in p or "/out/" in p or p == str(VENDOR):
            continue
        try:
            t = bp.read_text(errors="replace")
        except OSError:
            continue
        for m in NAME_RE.finditer(t):
            plat_defined.add(m.group(1))

    to_vendor = sorted(plain_needed - plat_defined)
    print("PLATFORMDA KARSILIGI OLMAYAN (->_vendor): %d" % len(to_vendor))
    for x in to_vendor:
        print("   ", x)

    # Her modulun govdesindeki referanslari topla (govde araliklariyla)
    edits = []  # (start, end, yeni_govde)
    total_refs = 0
    for n, typ, body, s, e in bl:
        new_body = body
        changed = False
        for key in LIB_KEYS:
            def fix_list(m):
                nonlocal changed
                inner = m.group(1)
                def repl(rm):
                    nonlocal changed
                    ref = rm.group(1)
                    if ref in to_vendor:
                        changed = True
                        return '"%s_vendor"' % ref
                    return rm.group(0)
                return "%s: [%s]" % (key, re.sub(r'"([^"]+)"', repl, inner))
            new_body = re.sub(rf"{key}\s*:\s*\[(.*?)\]", fix_list, new_body, flags=re.S)
        if changed:
            edits.append((s, e, new_body))
            total_refs += 1

    print("DUZELTILECEK MODUL: %d" % total_refs)

    if not args.apply:
        print("(rapor; uygulamak icin --apply)")
        return 0

    out = txt
    for s, e, new_body in sorted(edits, key=lambda x: -x[0]):
        out = out[:s] + new_body + out[e:]
    VENDOR.write_text(out)
    print("[✓] %d modulun referanslari '_vendor' adiyla hizalandi" % total_refs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
