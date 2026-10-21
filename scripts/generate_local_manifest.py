#!/usr/bin/env python3
"""
local_manifests.xml'i uretir: EvoX base manifestinin tum projelerinin
revision'ini pinler (extend-project) + xuanyuan projelerini ekler (project).

Neden bu yontem:
  - Pinned manifest, EvoX base manifestinin AYNI yollarla superset'i. Base
    default.xml'i elle degistirmek kalici degil: repo manifest deposunun
    git'inden geri yukleyebiliyor, birlesik manifest bayat kaliyor ve
    pinned projeler kayboluyor ("reference broken" -> 21 proje sync edilemiyor).
  - Local manifest icinde ayni PATH'i tekrar tanimlamak da yasak
    (repo: "duplicate path").
  - <extend-project> base projenin revision/remote/upstream'unu yerinde
    degistirir, path'i tekrarlamaz. Repo'nun bu isi icin vardir.

Kullanim:
  scripts/generate_local_manifest.py <aosp_root> [--out <dosya>]

<aosp_root>/.repo/manifests/default.xml ve snippets/*.xml base olarak okunur.
"""
from __future__ import annotations

import argparse
import pathlib
import sys
import xml.etree.ElementTree as ET

OURS_PREFIX = ("krmmyvz", "xiaomi-8750")


def ser(e: ET.Element, indent: str = "  ") -> list[str]:
    a = "".join(f' {k}="{v}"' for k, v in e.attrib.items())
    kids = list(e)
    if not kids:
        return [f"{indent}<{e.tag}{a}/>"]
    out = [f"{indent}<{e.tag}{a}>"]
    for k in kids:
        out += ser(k, indent + "  ")
    out.append(f"{indent}</{e.tag}>")
    return out


def load_base(manifests: pathlib.Path) -> tuple[dict[str, str], set[str]]:
    """(isim -> path, kullanilan path'ler)"""
    by_name: dict[str, str] = {}
    paths: set[str] = set()

    def walk(root: ET.Element) -> None:
        for e in root.findall("project"):
            n, p = e.get("name"), e.get("path")
            if n:
                by_name.setdefault(n, p or "")
            if p:
                paths.add(p)
        for inc in root.findall("include"):
            f = manifests / (inc.get("name") or "")
            if f.is_file():
                walk(ET.parse(f).getroot())

    # default.xml + tum snippet'lar (recursive) - snippet'lar alt dizindedir
    files = sorted(manifests.glob("*.xml")) + sorted(manifests.glob("snippets/*.xml"))
    for f in files:
        try:
            walk(ET.parse(f).getroot())
        except ET.ParseError:
            continue
    return by_name, paths


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("aosp", nargs="?", default="/mnt/src")
    ap.add_argument("--out", default="")
    ap.add_argument("--tree", default="")
    args = ap.parse_args()

    aosp = pathlib.Path(args.aosp)
    manifests = aosp / ".repo/manifests"
    tree = pathlib.Path(args.tree) if args.tree else aosp / "device/xiaomi/xuanyuan"
    out = pathlib.Path(args.out) if args.out else aosp / ".repo/local_manifests/local_manifests.xml"

    build = tree / "build-support"
    pinned = ET.parse(build / "evox-manifest-pinned.xml").getroot()
    lm = ET.parse(build / "local_manifests.xml").getroot()

    base_by_name, base_paths = load_base(manifests)
    # isim -> yol listesi (ayni isim birden fazla yolda olabilir:
    # LineageOS/android_hardware_qcom_display sm8450-6.6 ve sm8750'de)
    name_paths: dict[str, list[str]] = {}
    path_name: dict[str, str] = {}
    for f in sorted(manifests.glob("*.xml")) + sorted(manifests.glob("snippets/*.xml")):
        try:
            root = ET.parse(f).getroot()
        except ET.ParseError:
            continue
        for e in root.findall("project"):
            n, pa = e.get("name"), e.get("path")
            if not n or not pa:
                continue
            lst = name_paths.setdefault(n, [])
            if pa not in lst:
                lst.append(pa)
            path_name.setdefault(pa, n)
    print(f"base: {len(base_by_name)} proje, {len(base_paths)} path, {len(name_paths)} isim")

    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<!--",
        "  Otomatik uretilmis - scripts/generate_local_manifest.py",
        "",
        "  EvoX base manifestinin tum projelerinin revision'i <extend-project>",
        "  ile pinlenir; xuanyuan projeleri <project> ile eklenir.",
        "  Boylece base default.xml degistirilmez (repo onu geri yukleyebiliyor)",
        "  ve hicbir path tekrari olusmaz.",
        "-->",
        "<manifest>",
    ]
    for e in lm.findall("remote"):
        lines += ser(e)
    for e in lm.findall("default"):
        lines += ser(e)
    lines += ["", "  <!-- xuanyuan projeleri -->"]
    for e in lm.findall("project"):
        if e.get("name", "").startswith(OURS_PREFIX):
            lines += ser(e)

    lines += ["", "  <!-- pinned platform revision'lar (extend-project) -->"]
    ext = 0
    newp = 0
    skipped = 0
    for e in pinned.findall("project"):
        name = e.get("name")
        path = e.get("path")
        if not name or not path:
            continue
        if name in name_paths and path in name_paths[name]:
            # Ayni isim VE ayni yol: extend-project ile pinle.
            # path= ZORUNLU: ayni isim birden fazla yolda olabilir ve her
            # yolun revision'i farklidir (orn. android_hardware_qcom_display).
            x = ET.Element("extend-project", {"name": name, "path": path})
            for k in ("revision", "remote", "upstream", "dest-branch"):
                v = e.get(k)
                if v:
                    x.set(k, v)
            lines += ser(x)
            ext += 1
        elif path in path_name:
            # Ayni yolda ama FARKLI depo/isim (orn. AOSPA fork).
            # extend-project isimle calisir ve isim depoyu belirler, bu
            # yuzden AOSPA'nin SHA'si LineageOS deposunda yok. Bu proje
            # base haliyle birakilir (gelistirme araci, build icin onemsiz).
            skipped += 1
        else:
            lines += ser(e)
            newp += 1
    lines += ["</manifest>"]

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n")
    ET.parse(out)  # dogrulama
    print(f"extend-project={ext} atlanan={skipped} yeni project={newp} -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
