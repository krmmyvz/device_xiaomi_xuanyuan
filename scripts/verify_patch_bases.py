#!/usr/bin/env python3
"""
platform-patches/*.base SHA'larini pinlenmis manifestle karsilastirir.

Cikti:
  - ESIT    : base, manifestteki revision ile ayni -> patch uygulanabilir
  - FARKLI  : manifestteki revision degismis -> patch UYGULANAMAZ
  - PROJE_YOK: base dosyasi olan proje manifestte yok

Cikis kodu: fark varsa 1 (build oncesi durdurmak icin).

Kullanim:
  scripts/verify_patch_bases.py [--tree <device-tree>] [--manifest <pinned.xml>]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def load_manifest(path: Path) -> dict[str, str]:
    text = path.read_text(errors="replace")
    out: dict[str, str] = {}
    for m in re.finditer(r"<project\b[^>]*>", text):
        tag = m.group(0)
        p = re.search(r'path="([^"]+)"', tag)
        r = re.search(r'\brevision="([^"]+)"', tag)
        if p and r:
            out[p.group(1)] = r.group(1)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", default="", help="device tree dizini (bos = burasi)")
    ap.add_argument("--manifest", default="", help="pinned manifest (bos = tree/build-support)")
    args = ap.parse_args()

    tree = Path(args.tree) if args.tree else Path(__file__).resolve().parents[1]
    pdir = tree / "build-support" / "platform-patches"
    manifest_path = (
        Path(args.manifest)
        if args.manifest
        else tree / "build-support" / "evox-manifest-pinned.xml"
    )

    if not pdir.is_dir():
        print(f"patch dizini yok: {pdir}", file=sys.stderr)
        return 2
    if not manifest_path.is_file():
        print(f"manifest yok: {manifest_path}", file=sys.stderr)
        return 2

    proj = load_manifest(manifest_path)
    print(f"manifest : {manifest_path}")
    print(f"patchler : {pdir}")
    print(f"proje    : {len(proj)}\n")

    equal, differ, missing = [], [], []
    width = max((len(p.stem) for p in pdir.glob("*.base")), default=20)

    for base in sorted(pdir.glob("*.base")):
        name = base.stem
        sha = base.read_text().strip()
        proj_path = name.replace("__", "/")
        rev = proj.get(proj_path)
        if rev is None:
            missing.append((name, sha, proj_path, None))
        elif rev.startswith(sha):
            equal.append((name, sha, proj_path, rev))
        else:
            differ.append((name, sha, proj_path, rev))

    for name, sha, pp, rev in equal:
        print(f"  ESIT     {name:<{width}}  {sha[:10]}  {pp}")
    for name, sha, pp, rev in differ:
        print(f"  FARKLI   {name:<{width}}  base={sha[:10]}  manifest={rev[:10]}  {pp}")
    for name, sha, pp, rev in missing:
        print(f"  PROJE_YOK {name:<{width}}  {sha[:10]}  {pp}")

    print(f"\nESIT={len(equal)}  FARKLI={len(differ)}  PROJE_YOK={len(missing)}")

    if differ or missing:
        print(
            "\nHATA: base SHA'lari manifestle tutmuyor. Bu patch'ler UYGULANAMAZ.\n"
            "      Yeni base uretmek icin: manifestteki revision'a checkout yap,\n"
            "      patch'i uygula, sonra .base dosyasini yeni SHA ile guncelle.",
            file=sys.stderr,
        )
        return 1
    print("OK: tum base SHA'lari manifestle tutuyor, patch'ler uygulanabilir.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
