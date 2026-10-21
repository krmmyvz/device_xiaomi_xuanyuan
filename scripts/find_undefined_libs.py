#!/usr/bin/env python3
"""
Vendor Android.bp'sindeki shared_libs/static_libs/header_libs referanslarini
tarar ve agacda TANIMI OLMAYAN modul adlarini listeler.

Soong analizinde "depends on undefined module" hatasi uretir; build
baslamadan once tespit edebilmek icin.

Soong'un urettigi moduller hesaba katilir:
  - aidl_interface { name: "X" }  ->  X-V{n}-ndk, X-V{n}-ndk-source
  - name: "X"                    ->  X
"""
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
VENDOR = TREE / "vendor/xiaomi/xuanyuan/Android.bp"
REPORT = pathlib.Path("/mnt/out/undefined-libs.txt")
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
        # aidl_interface bloklari: Soong V{n}-ndk stub uretir
        for m in re.finditer(r"aidl_interface\s*\{(.*?)\n\}", t, re.S):
            nm = re.search(r'name:\s*"([^"]+)"', m.group(1))
            if not nm:
                continue
            base = nm.group(1)
            aidl.add(base)
            for v in re.findall(r'version:\s*"([0-9]+)"', m.group(1)):
                aidl.add(f"{base}-V{v}-ndk")
                aidl.add(f"{base}-V{v}-ndk-source")
            aidl.add(f"{base}-ndk")
            aidl.add(f"{base}-ndk-source")
    return defined, aidl


def main() -> int:
    if not VENDOR.is_file():
        print(f"vendor Android.bp yok: {VENDOR}")
        return 1

    src = VENDOR.read_text()
    print("agac taraniyor ...", flush=True)
    defined, aidl = collect_defined()
    print(f"tanimli modul : {len(defined)}")
    print(f"AIDL uretilen  : {len(aidl)}")

    refs: dict[str, set[str]] = {}
    for m in re.finditer(r'name:\s*"([^"]+)"(.*?)(?=\n\})', src, re.S):
        mod, body = m.group(1), m.group(2)
        for key in LIB_KEYS:
            for lm in re.finditer(rf"{key}:\s*\[(.*?)\]", body, re.S):
                for r in re.finditer(r'"([^"]+)"', lm.group(1)):
                    refs.setdefault(r.group(1), set()).add(mod)

    missing: dict[str, set[str]] = {}
    for lib, mods in refs.items():
        if lib in defined or lib in aidl:
            continue
        base = re.sub(r"(-ndk|-ndk-source|_vendor|-src|-static|-impl)$", "", lib)
        if base in defined or base in aidl:
            continue
        missing.setdefault(lib, set()).update(mods)

    lines = []
    for lib in sorted(missing):
        lines.append(f"{lib}\t{', '.join(sorted(missing[lib]))}")
    REPORT.write_text("\n".join(lines) + ("\n" if lines else ""))

    print()
    print(f"referans edilen lib : {len(refs)}")
    print(f"TANIMSIZ REFERANS    : {len(missing)}  -> {REPORT}")
    for lib in sorted(missing):
        print(f"  {lib}   <- {sorted(missing[lib])[0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
