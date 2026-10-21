#!/usr/bin/env python3
"""
Vendor Android.bp'sindeki tanimsiz shared_libs/static_libs referanslarini
cozer.

Iki sey yapar:
  1) MAP  : ayni kokun, agacta VAR olan bir modulune yonlendirir
            (orn. vendor.qti.hardware.display.config-V16-ndk ->
             vendor.qti.hardware.display.config-V12-ndk)
  2) DROP : cozum yoksa referansi kaldirir (prebuilt olduklari icin
            bagimlilik kurulmaz; calisma zamani etkisi olabilir ama
            derlemeyi engellemez)

Kullanim:
  scripts/fix_undefined_lib_refs.py [--apply] [--report <dosya>]

Varsayilan: yalnizca rapor yazar. --apply ile Android.bp duzenlenir.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
VENDOR = TREE / "vendor/xiaomi/xuanyuan/Android.bp"
LIB_KEYS = ("shared_libs", "static_libs", "header_libs", "whole_static_libs")


def collect_defined() -> tuple[set[str], set[str]]:
    defined: set[str] = set()
    aidl: set[str] = set()
    for bp in TREE.rglob("Android.bp"):
        p = str(bp)
        if "/.repo/" in p or "/out/" in p:
            continue
        try:
            t = bp.read_text(errors="replace")
        except OSError:
            continue
        for m in re.finditer(r'name:\s*"([^"]+)"', t):
            defined.add(m.group(1))
        for m in re.finditer(r"aidl_interface\s*\{(.*?)\n\}", t, re.S):
            nm = re.search(r'name:\s*"([^"]+)"', m.group(1))
            if not nm:
                continue
            base = nm.group(1)
            aidl.add(base)
            for v in re.findall(r'version:\s*"([0-9]+)"', m.group(1)):
                aidl.add(f"{base}-V{v}-ndk")
                aidl.add(f"{base}-V{v}-ndk-source")
    return defined, aidl


SUFFIXES = (
    "_vendor",
    "-xiaomi",
    "-platform",
    "-ndk-source",
    "-ndk",
    "-impl",
)


def stem(name: str) -> str:
    """Modul adindan surum/ek ayiklanir: kok ad.

    Ekler tekrarli olarak atilir, cunku sira onemli:
    'vendor.qti.hardware.qesdhalaidl-V2-ndk_vendor' once '_vendor'
    atilir, sonra '-V2-ndk' -> 'vendor.qti.hardware.qesdhalaidl'.
    """
    s = name
    changed = True
    while changed:
        changed = False
        for suf in SUFFIXES:
            if s.endswith(suf) and len(s) > len(suf):
                s = s[: -len(suf)]
                changed = True
                break
        if not changed:
            m = re.search(r"(-V\d+|-@?\d+\.\d+(?:\.\d+)?)$", s)
            if m:
                s = s[: m.start()]
                changed = True
    return s


def _ver(d: str) -> int:
    m = re.search(r"-V(\d+)", d)
    return int(m.group(1)) if m else -1


def candidates(lib: str, defined: set[str], aidl: set[str]) -> list[str]:
    """Ayni kok adli modullerden en uygun olani secer.

    Oncelik sirasi:
      1) X-V<n>-ndk          (platform AIDL stub'i, en yuksek surum)
      2) X-V<n>-ndk_vendor   (vendor'in kendi AIDIL stub'i)
      3) X                   (surumsuz, duz kutuphane)
    '-source' varyantlari gecerli hedef degildir (Soong ic), elenir.
    """
    base = stem(lib)
    out = {d for d in (defined | aidl) if d != lib and stem(d) == base}
    if not out:
        return []

    plain = sorted([d for d in out if re.search(r"-V\d+-ndk$", d)], key=_ver)
    vendor = sorted([d for d in out if re.search(r"-V\d+-ndk_vendor$", d)], key=_ver)
    bare = sorted(d for d in out if "-V" not in d and not d.endswith("-source"))

    if plain:
        return [plain[-1]]
    if vendor:
        return [vendor[-1]]
    if bare:
        return [bare[-1]]
    return sorted(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--report", default="/mnt/out/lib-ref-fixes.txt")
    args = ap.parse_args()

    if not VENDOR.is_file():
        print(f"vendor Android.bp yok: {VENDOR}")
        return 1

    src = VENDOR.read_text()
    print("agac taraniyor ...", flush=True)
    defined, aidl = collect_defined()

    # modul -> lib referanslari
    refs: dict[str, set[str]] = {}
    for m in re.finditer(r'name:\s*"([^"]+)"(.*?)(?=\n\})', src, re.S):
        mod, body = m.group(1), m.group(2)
        for key in LIB_KEYS:
            for lm in re.finditer(rf"{key}:\s*\[(.*?)\]", body, re.S):
                for r in re.finditer(r'"([^"]+)"', lm.group(1)):
                    refs.setdefault(r.group(1), set()).add(mod)

    # NOT: "base stem tanimli" durumu da MAP adayidir (or.
    # libprotobuf-cpp-full-6.33.5 -> libprotobuf-cpp-full), bu yuzden
    # burada elenmez.
    undefined = []
    for lib in refs:
        if lib in defined or lib in aidl:
            continue
        undefined.append(lib)

    fixes = []
    for lib in sorted(undefined):
        cands = candidates(lib, defined, aidl)
        if len(cands) == 1:
            fixes.append(("MAP", lib, cands[0]))
        elif cands:
            fixes.append(("AMBIG", lib, ", ".join(cands[:6])))
        else:
            fixes.append(("DROP", lib, ""))

    lines = [f"{kind}\t{lib}\t{to}" for kind, lib, to in fixes]
    pathlib.Path(args.report).write_text("\n".join(lines) + ("\n" if lines else ""))

    print(f"tanimsiz referans: {len(undefined)}")
    for kind, lib, to in fixes:
        print(f"  {kind:7} {lib}  ->  {to}")

    if args.apply:
        new = src
        n_map = n_drop = 0
        for kind, lib, to in fixes:
            if kind == "MAP":
                new = new.replace(f'"{lib}"', f'"{to}"')
                n_map += 1
            elif kind == "DROP":
                # yalnizca lib listeleri icindeki girisleri kaldir
                new = re.sub(rf'^[ \t]*"{re.escape(lib)}",?[ \t]*\n', "", new, flags=re.M)
                new = re.sub(rf',[ \t]*\n?[ \t]*"{re.escape(lib)}"', "", new)
                n_drop += 1
        VENDOR.write_text(new)
        print(f"uygulandi: {n_map} MAP, {n_drop} DROP")
    return 0


if __name__ == "__main__":
    sys.exit(main())
