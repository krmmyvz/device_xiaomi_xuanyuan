#!/usr/bin/env python3
"""
Vendor Android.bp'deki AIDL prebuilt adlandirmasini ve duplicate'larini duzeltir.

SORUN SINIFLARI
----------------
1) ISIM CAKISMASI (duplicate module)
   Ayni modul adi vendor agacinda iki partition'da (vendor + system_ext)
   tanimli. Platform, system_ext kopyasinin karsiligini URETMIYORSA o kopya
   SILINIR.

2) PARTITION MISMATCH
   Soong, prebuilt modulun adini 'prebuilt_' + name olarak kaydeder ve bu ad
   ayni adi tasiyan KAYNAK modulun yerini alir. Kaynak modul platformda
   'system' partition'inda uretiliyorsa (vendor_available:false) prebuilt
   'vendor' partition'inda oldugu icin Soong partition kontrolunden gecer:

     error: module "X" ...: partition is different:
     system(X) != vendor(prebuilt_X)

   Cozum: vendor prebuilt'i '_vendor' adiyla ayirilir (upstream'in kullandigi
   adlandirma).

3) '_vendor' -> plain yeniden adlandirmadan dogan ikincil hatalar
   fix_aidl_vendor_refs.py, '_vendor' eklerini kaldirip platform adiyla
   degistirir. Bu, yukaridaki iki sinifi uretir. Bu script vendor agacini
   upstream adlandirmasina geri dondurur.

Idempotenttir.
"""
from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys

TREE = pathlib.Path("/mnt/src")
VENDOR = TREE / "vendor/xiaomi/xuanyuan/Android.bp"

BLOCK_START = re.compile(r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*\{", re.M)


def parse_blocks(txt: str):
    """(name, body, body_start, body_end, block_start, block_end)

    block_start/block_end: blok BASLIGININ basindan kapanis '}' + satir sonuna
    kadar olan tam aralik (silme icin).
    """
    out = []
    for m in BLOCK_START.finditer(txt):
        body_start = m.end()
        depth = 1
        i = body_start
        while i < len(txt) and depth > 0:
            if txt[i] == "{":
                depth += 1
            elif txt[i] == "}":
                depth -= 1
            i += 1
        body_end = i            # kapanis '}' sonrasi
        body = txt[body_start:body_end]
        nm = re.search(r'name:\s*"([^"]+)"', body)
        if nm:
            # blok basligi: satir basindan '{' one kadar; kapanis: '}' + satir sonu
            line_start = txt.rfind("\n", 0, m.start()) + 1
            close = txt.find("\n", body_end)
            block_end = close + 1 if close != -1 else body_end
            out.append((nm.group(1), body, body_start, body_end, line_start, block_end))
    return out


def partition_of(body: str) -> str:
    for p, flag in (
        ("vendor", "soc_specific"),
        ("system_ext", "system_ext_specific"),
        ("device", "device_specific"),
        ("product", "product_specific"),
    ):
        if re.search(rf"\b{flag}:\s*true", body):
            return p
    return "system"


def platform_aidl() -> dict:
    """kok ad -> (platformun urettigi partition listesi, dosya)"""
    out = {}
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
            base = nm.group(1)
            parts = []
            for p2, flag in (("system_ext", "system_ext_specific"), ("device", "device_specific"),
                             ("product", "product_specific")):
                if re.search(rf"\b{flag}:\s*true", m.group(1)):
                    parts.append(p2)
            if not parts:
                vendor_avail = bool(re.search(r"\bvendor_available:\s*true", m.group(1)))
                parts = ["system", "vendor"] if vendor_avail else ["system"]
            out[base] = (parts, p.replace("/mnt/src/", ""))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    if not VENDOR.is_file():
        print(f"vendor Android.bp yok: {VENDOR}")
        return 1

    src = VENDOR.read_text(errors="replace")
    plat = platform_aidl()

    blocks = parse_blocks(src)
    counts = collections.Counter(n for n, _, _, _, _, _ in blocks)
    dupes = {n for n, k in counts.items() if k > 1}

    edits = []   # (start, end, yeni govde)
    renames = {}

    def queue_rename(name, body, bstart, bend, new_name, why):
        new_body = re.sub(
            r'(name:\s*)"[^"]+"',
            lambda m: m.group(1) + f'"{new_name}"',
            body,
            count=1,
        )
        # stem yoksa dosya adi modul adindan turetilir ("lib<ad>.so"); yeniden
        # adlandirmada bu degisir -> ELF/DT_SONAME kontrolu kacar. Eski adi
        # stem olarak sabitle.
        if not re.search(r'\bstem:\s*"', new_body):
            new_body = re.sub(
                r'(name:\s*"[^"]+",\n)',
                lambda m: m.group(1) + f'    stem: "{name}",\n',
                new_body,
                count=1,
            )
        edits.append((bstart, bend, new_body))
        renames[name] = new_name
        print(f"[+] {name} -> {new_name}  ({why})")

    # --- Sinif 1: isim cakismasi (duplicate module) ------------------------
    for name in sorted(dupes):
        same = [b for b in blocks if b[0] == name]
        parts = {}
        for b in same:
            parts.setdefault(partition_of(b[1]), b)
        if len(parts) < 2:
            continue
        base = re.sub(r"-V\d+-ndk(_vendor)?$", "", name)
        if base not in plat:
            print(f"[!] {name}: platform karsiligi yok, ATLANDI")
            continue
        plat_parts, _ = plat[base]
        # Platform system_ext uretmiyorsa, vendor agacindaki system_ext
        # kopyasi gereksiz -> TAM BLOK SILINIR.
        if "system_ext" in parts and "system_ext" not in plat_parts and "vendor" in parts:
            b = parts["system_ext"]
            edits.append((b[4], b[5], ""))
            print(f"[~] {name}: system_ext kopyasi SILINDI (platform system_ext uretmiyor)")
            continue
        if "vendor" not in parts:
            print(f"[!] {name}: vendor kopyasi yok, ATLANDI")
            continue
        b = parts["vendor"]
        queue_rename(name, b[1], b[2], b[3], f"{name}_vendor", "duplicate module")

    # --- Sinif 2: partition mismatch --------------------------------------
    # Platform arayuzu vendor partition'inda da uretiliyorsa ('vendor' in
    # plat_parts) prebuilt gölgelemesi ayni partition'da -> sorun yok.
    for name, body, bstart, bend, bline, bend2 in blocks:
        if name in renames or name.startswith("xiaomi.prebuilt."):
            continue
        if not re.search(r"-V\d+-ndk$", name):
            continue
        base = re.sub(r"-V\d+-ndk$", "", name)
        if base not in plat:
            continue
        plat_parts, _ = plat[base]
        if partition_of(body) in plat_parts:
            continue
        if "vendor" in plat_parts:
            continue
        queue_rename(name, body, bstart, bend, f"{name}_vendor", "partition mismatch")

    if not edits:
        print("[✓] duzeltilecek adlandirma yok")
        return 0

    out = src
    for start, end, new_body in sorted(edits, key=lambda e: -e[0]):
        out = out[:start] + new_body + out[end:]

    # Referanslari yeni adlara cevir. 'stem:' alanini DEGISTIRME: stem dosya
    # adini belirler (ELF/DT_SONAME kontrolu).
    for old, new in renames.items():
        out = re.sub(rf'(name:\s*)"{re.escape(old)}"', rf'\1"{new}"', out)
        out = re.sub(rf'(stem:\s*)"{re.escape(old)}"', rf'\1"{old}"', out)
        out = re.sub(rf'"{re.escape(old)}"', rf'"{new}"', out)

    if args.apply:
        VENDOR.write_text(out)
        print(f"[✓] {len(edits)} blok duzeltildi, {len(renames)} referans guncellendi")
    else:
        print(f"(rapor; uygulamak icin --apply) {len(edits)} blok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
