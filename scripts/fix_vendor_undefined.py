"""Vendor Android.bp icindeki TANIMSIZ shared_libs referanslarini duzeltir.

SORUN
-----
    error: "vendor.qti.qesdhal-impl" depends on undefined module
           "vendor.qti.qesdhalaidl-V2-ndk"

Stok vendor ağacı platform modullerini `_vendor` son ekiyle uretiyor
(orn. `vendor.qti.qesdhalaidl-V2-ndk_vendor`), ama `shared_libs` listesinde eski
platform adi (`...-V2-ndk`) yazili. Platform modulleri vendor namespace'inde
gorunmedigi icin Soong "undefined module" diyor.

COZUM
-----
1. Agacin TUM modul adlarini topla (vendor + platform + device).
2. SADECE `shared_libs` listelerindeki referanslari kontrol et.
   `srcs` girdileri ve `libc++`/`libdl` gibi sistem kutuphaneleri dokunulmaz.
3. Referans tanimsizsa aday varyantlari dene:
     - `<ad>_vendor`
     - `xiaomi.prebuilt.<ad>`
     - `xiaomi.prebuilt.<ad>_vendor`
   Bulunan ilk adla degistir.
4. Hicbiri yoksa referansi yorum satirina CEVIR (silme degil - geri alinabilir).

Idempotenttir.
"""
from __future__ import annotations

import pathlib
import re
import subprocess

BP = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp")
BLOCK_TYPES = ("cc_prebuilt_library_shared {", "cc_prebuilt_binary {")

# Bunlar hicbir zaman modul referansi degildir; dokunma.
SYSTEM_LIBS = {
    "libc", "libm", "libdl", "liblog", "libc++", "libstdc++", "libandroid",
    "libcutils", "libutils", "libhidlbase", "libbinder", "libbinder_ndk",
    "libbase", "libz", "libvndksupport", "libutilscallstack", "libsync",
    "libfmq", "libcrypto", "libssl", "libsqlite", "libexpat", "libft2",
    "libjpeg", "libpng", "libwebp", "libmedia", "libEGL", "libGLESv2",
    "libOpenSLES", "libaaudio", "libcamera_metadata", "libgui", "libui",
    "libsurfaceflinger", "libhardware", "libdrm", "libxml2", "libhidltransport",
    "libgralloctypes", "libtinyxml2", "libtinyxml2_1",
}

SCAN_DIRS = [
    "/mnt/src/vendor/xiaomi/xuanyuan", "/mnt/src/vendor/qcom", "/mnt/src/vendor/lineage",
    "/mnt/src/hardware/xiaomi", "/mnt/src/hardware/qcom-caf", "/mnt/src/hardware/interfaces",
    "/mnt/src/device/xiaomi", "/mnt/src/system", "/mnt/src/frameworks",
    "/mnt/src/external", "/mnt/src/packages",
]


def all_module_names() -> set[str]:
    names: set[str] = set()
    for d in SCAN_DIRS:
        p = pathlib.Path(d)
        if not p.is_dir():
            continue
        try:
            out = subprocess.run(
                ["grep", "-rhoE", r'name:\s*"[^"]+"', "--include=Android.bp", str(p)],
                capture_output=True, text=True, timeout=200,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        for line in out.stdout.splitlines():
            m = re.search(r'"([^"]+)"', line)
            if m:
                names.add(m.group(1))

    # `aidl_interface` tanimlarindan Soong'un OTOMATIK urettigi varyant adlari
    # `name:` alaninda gorunmez. Bunlari acikca eklemek gerekir, aksi halde
    # `android.hardware.common` -> `android.hardware.common-V2-ndk` gibi
    # gercek moduller "undefined module" sanilir.
    # Surumler iki yerden gelir: `versions: { ... }` listesi ya da
    # `aidl_api/<base>/<N>/` dizinleri.
    for d in SCAN_DIRS:
        p = pathlib.Path(d)
        if not p.is_dir():
            continue
        try:
            out = subprocess.run(
                ["grep", "-rl", "aidl_interface", "--include=Android.bp", str(p)],
                capture_output=True, text=True, timeout=180,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        for fp in out.stdout.splitlines():
            try:
                t = pathlib.Path(fp).read_text(errors="ignore")
            except OSError:
                continue
            for m in re.finditer(r"aidl_interface\s*\{(.*?)\n\}", t, re.S):
                body = m.group(1)
                nm = re.search(r'name:\s*"([^"]+)"', body)
                if not nm:
                    continue
                base = nm.group(1)
                names.add(base)
                vers: set[str] = set()
                for v in re.findall(r"versions:\s*\{(.*?)\}", body, re.S):
                    vers.update(re.findall(r'"(\d+)"', v))
                # aidl_api/<base>/<N>/ dizinlerinden surumleri oku.
                for ap in pathlib.Path(fp).parent.rglob("aidl_api"):
                    for sub in ap.iterdir():
                        if not sub.is_dir():
                            continue
                        # aidl_api altindaki klasor adi arayuz adi olabilir
                        # (orn. aidl_api/android.hardware.common/1/).
                        if sub.name == base or base.startswith(sub.name + "."):
                            for vdir in sub.iterdir():
                                if vdir.is_dir() and vdir.name.isdigit():
                                    vers.add(vdir.name)
                for num in vers:
                    names.add(f"{base}-V{num}-ndk")
                    names.add(f"{base}-V{num}-ndk-source")
                    names.add(f"{base}-V{num}-vendor")
                    names.add(f"{base}-V{num}-vendor_source")
                    names.add(f"{base}-V{num}")
    return names


def main() -> int:
    if not BP.is_file():
        print(f"HATA: {BP} yok")
        return 1

    known = all_module_names()
    print(f"agactaki modul sayisi: {len(known)}")

    lines = BP.read_text().splitlines(True)
    renamed: list[str] = []
    disabled: list[str] = []
    i = 0

    while i < len(lines):
        if not any(lines[i].startswith(t) for t in BLOCK_TYPES):
            i += 1
            continue

        j = i + 1
        depth = 1
        while j < len(lines) and depth > 0:
            depth += lines[j].count("{") - lines[j].count("}")
            if depth <= 0:
                break
            j += 1
        body = "".join(lines[i : j + 1])
        nm = re.search(r'name:\s*"([^"]+)"', body)
        mod_name = nm.group(1) if nm else "?"

        # shared_libs VE export_shared_lib_headers listelerinin SATIR araligini bul.
        # Ikisi de modul referansi icerir; ikisinde de ayni duzeltme yapilir.
        list_specs = []
        for list_name in ("shared_libs", "export_shared_lib_headers"):
            sm = re.search(rf"{list_name}:\s*\[(.*?)\]", body, re.S)
            if not sm:
                continue
            ls_start = i + body[: sm.start(1)].count("\n")
            ls_end = ls_start + sm.group(1).count("\n")
            list_specs.append((ls_start, min(ls_end + 1, len(lines))))

        for ls_start, ls_end in list_specs:
            for k in range(ls_start, ls_end):
                # Satir icinde TEK basina "..." ya da virgulle biten bir referans ara.
                mm = re.search(r'"([^"]+)"', lines[k])
                if not mm:
                    continue
                ref = mm.group(1)
                if ref in known or ref in SYSTEM_LIBS:
                    continue
                # Yorum satirina daha once cevirdiysek atla.
                if "TANIMSIZ" in lines[k]:
                    continue
                cands = [f"{ref}_vendor", f"xiaomi.prebuilt.{ref}",
                         f"xiaomi.prebuilt.{ref}_vendor"]
                hit = next((c for c in cands if c in known), None)
                if hit:
                    lines[k] = lines[k].replace(f'"{ref}"', f'"{hit}"')
                    renamed.append(f"{mod_name}: {ref} -> {hit}")
                else:
                    # Tek basina duran referansi yorum satirina cevir.
                    # Virgulle biten/tek satirlik listelerde ise yalnizca eleman
                    # metni silinir (listenin geri kalani korunur).
                    stripped = lines[k].rstrip()
                    if re.fullmatch(r'\s*"[^"]+",?\s*', stripped):
                        indent = re.match(r"\s*", lines[k]).group(0)
                        trailing = "," if stripped.endswith(",") else ""
                        lines[k] = (f'{indent}// TANIMSIZ (agacta yok): "{ref}"{trailing}\n')
                        disabled.append(f"{mod_name}: {ref}")
                    else:
                        # Satirda birden fazla referans var: sadece tanimsiz olan
                        # elemani cikar, listeyi bozma.
                        parts = re.findall(r'"([^"]+)"', lines[k])
                        keep = [q for q in parts if q in known or q in SYSTEM_LIBS]
                        if not keep:
                            indent = re.match(r"\s*", lines[k]).group(0)
                            lines[k] = (f'{indent}// TANIMSIZ referanslar: {parts}\n')
                            disabled.append(f"{mod_name}: {', '.join(parts)}")
                        else:
                            indent = re.match(r"\s*", lines[k]).group(0)
                            trailing = "," if stripped.endswith(",") else ""
                            lines[k] = (indent
                                        + ", ".join(f'"{q}"' for q in keep)
                                        + trailing + "\n")
                            disabled.append(f"{mod_name}: {ref}")

        i = j + 1

    if not renamed and not disabled:
        print("degisiklik yok: tanimsiz referans bulunamadi")
        return 0

    BP.write_text("".join(lines))
    print(f"{len(renamed)} referans yeniden adlandirildi, {len(disabled)} referans yorumlandi")
    for r in renamed:
        print(f"  [ad] {r}")
    for r in disabled[:20]:
        print(f"  [yorum] {r}")
    if len(disabled) > 20:
        print(f"  ... ve {len(disabled)-20} yorum daha")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
