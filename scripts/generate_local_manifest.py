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


def load_base(manifests: pathlib.Path) -> tuple[dict[str, list[str]], dict[str, str]]:
    """(isim -> path listesi, path -> isim)

    ONEMLI: sadece default.xml'in kendi <include> zinciri izlenir.
    snippets/ dizinindeki dosyalarin hepsi base manifestin parcasi DEGIL -
    cihaz manifesti onlari include eder. Heppsini saymak, include
    edilmemis bir proje icin extend-project uretir ve repo
    "extend-project element specifies non-existent project" ile durur.
    """
    name_paths: dict[str, list[str]] = {}
    path_name: dict[str, str] = {}

    def walk(root: ET.Element, seen: set[pathlib.Path]) -> None:
        for e in root.findall("project"):
            n, p = e.get("name"), e.get("path")
            if not n:
                continue
            lst = name_paths.setdefault(n, [])
            if p and p not in lst:
                lst.append(p)
            if p and p not in path_name:
                path_name[p] = n
        for inc in root.findall("include"):
            f = (manifests / (inc.get("name") or "")).resolve()
            if f.is_file() and f not in seen:
                seen.add(f)
                try:
                    walk(ET.parse(f).getroot(), seen)
                except ET.ParseError:
                    continue

    default = manifests / "default.xml"
    if default.is_file():
        walk(ET.parse(default).getroot(), {default.resolve()})
    return name_paths, path_name


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

    # isim -> yol listesi (ayni isim birden fazla yolda olabilir:
    # LineageOS/android_hardware_qcom_display sm8450-6.6 ve sm8750'de)
    name_paths, path_name = load_base(manifests)
    print(f"base: {len(name_paths)} isim, {len(path_name)} path")

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
            #
            # extend-project isimle calisir ve isim depoyu belirler: base'deki
            # LineageOS projesini fork'un remote/dest-branch'i ile extend
            # edersek fetch "couldn't find remote ref" ile patlar (LineageOS
            # deposunda 'beryl' dali yok). Fork'un SHA'si da orijinal depoda
            # bulunmaz. Bu yuzden proje pinlenmez, base haliyle birakilir.
            skipped += 1
        else:
            # Yeni proje: base'de hic yok, path da cakismiyor.
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
