"""Vendor prebuilt'lerde eksik DT_NEEDED bagimliliklarini toplu olarak kapatir.

SORUN
-----
Stok Xiaomi blob'lari DT_NEEDED olarak bir AIDL/HIDL kutuphanesine bagli oluyor,
ama uretilmis `vendor/xiaomi/xuanyuan/Android.bp` bu bagimliliklari `shared_libs`
listesine yazmiyor. Android 16'nin `check_elf_file` kontrolu her birini tek tek
yakalip build'i durduruyor:

    vendor/.../displayfeature.default.so: error: DT_NEEDED
    "android.hardware.sensors-V3-ndk.so" is not specified in shared_libs.

Bagimliligi `shared_libs`'e eklemek cogu zaman daha derin bir sorun yaratiyor:
platform AIDL surum zincirini (V5 -> V7-source) tetikliyor ve vendor'da o
moduller yok. Bu yuzden agacin kendi yaklasimi kullanilir: `check_elf_files: false`.

COZUM
-----
1. Her `cc_prebuilt_library_shared` VE `cc_prebuilt_binary` blogunun `srcs`
   dosyalarini `readelf -d` ile oku.
2. DT_NEEDED icindeki kutuphaneleri `shared_libs` ile karsilastir.
3. Eksik olan bloga `check_elf_files: false` ekle.

KAPSAM NOTLARI
---------------
- `cc_prebuilt_binary` bloklari da ELF kontrolunden gecer; ilk surum yalnizca
  `cc_prebuilt_library_shared` kapsiyordu ve audiohalservice.qti'de takildi.
- DT_NEEDED -> `shared_libs` eslesmesinde ISIM UYUMSUZLUGU normaldir: dosya adi
  `libtinyxml2.so` iken modul adi `libtinyxml2_1` olabilir. Boyle bir durumda
  karsilik gelen modul bulunmuyorsa kontrol kapatilir.

Idempotenttir. Ciktisi: duzeltilen modul listesi.
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

BP = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp")
BLOCK_TYPES = ("cc_prebuilt_library_shared {", "cc_prebuilt_binary {")
PREFIXES = ("android.hardware", "android.frameworks", "vendor.")

# Platform tarafinda zaten var olan, DT_NEEDED'da cok gorulen sistem kutuphaneleri.
SKIP = {
    "libc", "libm", "libdl", "liblog", "libc++", "libstdc++", "libandroid",
    "libcutils", "libutils", "libhidlbase", "libbinder", "libbinder_ndk",
    "libbase", "libz", "libvndksupport", "libutilscallstack", "libsync",
    "libfmq", "libcrypto", "libssl", "libsqlite", "libexpat", "libft2",
    "libjpeg", "libpng", "libwebp", "libmedia", "libEGL", "libGLESv2",
    "libOpenSLES", "libaaudio", "libcamera_metadata", "libgui", "libui",
    "libsurfaceflinger", "libhardware",
    "libgralloctypes", "libdrm", "libxml2", "libhidltransport",
}

# DT_NEEDED adı ile modül adı farklı olabilir. libtinyxml2.so DT_NEEDED'ı için
# dogru hedef platformun vendor_available modulu olan `libtinyxml2`
# (external/tinyxml2) — o zaten vendor partition'a libtinyxml2.so kuruyor.
# Vendor'daki `libtinyxml2_1` FARKLI bir kutuphanedir (cameraya ait degil).
NAME_ALIASES = {
    "libtinyxml2": "libtinyxml2",
}


def dt_needed(path: pathlib.Path) -> set[str]:
    for tool in ("readelf", "/mnt/src/prebuilts/binary-tools/linux-x86/aarch64-linux-android-readelf"):
        try:
            r = subprocess.run([tool, "-d", str(path)], capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if r.returncode != 0:
            continue
        found = set()
        for line in r.stdout.splitlines():
            m = re.search(r"\(NEEDED\)\s+Shared library:\s+\[([^\]]+)\]", line)
            if m:
                so = m.group(1)
                found.add(so[:-3] if so.endswith(".so") else so)
        if found:
            return found
    return set()


def main() -> int:
    if not BP.is_file():
        print(f"HATA: {BP} yok")
        return 1

    lines = BP.read_text().splitlines(True)
    out: list[str] = []
    fixed: list[str] = []
    i = 0

    while i < len(lines):
        if not any(lines[i].startswith(t) for t in BLOCK_TYPES):
            out.append(lines[i])
            i += 1
            continue

        # Blogun sonunu suslu blok sayaciyla bul.
        j = i + 1
        depth = 1
        while j < len(lines) and depth > 0:
            depth += lines[j].count("{") - lines[j].count("}")
            if depth <= 0:
                break
            j += 1
        block = lines[i : j + 1]
        body = "".join(block)

        nm = re.search(r'name:\s*"([^"]+)"', body)
        name = nm.group(1) if nm else "?"
        m = re.search(r"shared_libs:\s*\[(.*?)\]", body, re.S)
        libs = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()
        srcs = re.findall(r'"([^"]+\.(?:so|\w+))"', body)

        missing: set[str] = set()
        for s in srcs:
            p = BP.parent / s
            if not p.is_file():
                continue
            # DT_NEEDED yalnızca ELF dosyalarda var; uzantısı .so olmayan
            # executable'lar (.qti vb.) de ELF'tir ama glob onları kaçırıyordu.
            for mod in dt_needed(p):
                if mod in libs:
                    # Alias tanimliysa DT_NEEDED adinin KENDISI de shared_libs'te
                    # olmali. "libtinyxml2_1" yaziliyken "libtinyxml2.so" isteniyorsa
                    # bu eksik bagimliliktir; alias'i "zaten var" sayip atlamak
                    # hatayi gizler ve build check_elf_file'da yine duser.
                    if mod not in NAME_ALIASES:
                        continue
                # DT_NEEDED adı ile modül adı farklı olabilir (libtinyxml2.so ->
                # libtinyxml2_1 gibi). Bu durumda alias'ı shared_libs'e EKLEMEK
                # dogru cözümdür: platformun vendor_available modülü
                # (external/tinyxml2 -> libtinyxml2) zaten dogru dosya adini uretir.
                # Alias'i "zaten var" sayip atlamak hatayi gizler ve build'i yine
                # check_elf_file'da durdurur.
                if mod in SKIP:
                    continue
                if mod.startswith(PREFIXES) or mod.startswith("lib"):
                    missing.add(mod)

        # check_elf_files daha once kapatilmis olsa bile, DT_NEEDED'daki
        # platformun vendor_available modullerini (libtinyxml2 gibi) shared_libs'e
        # Eklemek dogru ve kalicidir; kontrol kapali kalmaya devam eder ama
        # bagimlilik dogru sekilde bildirilmis olur.
        alias_missing = sorted(m_ for m_ in missing if m_ in NAME_ALIASES)

        if alias_missing:
            mm = re.search(r"shared_libs:\s*\[(.*?)\]", body, re.S)
            if mm:
                abs_start = i + body[: mm.start(1)].count("\n")
                indent = re.match(r"\s*", lines[abs_start]).group(0)
                # Eski alias'i ("libtinyxml2_1") kaldir, dogru olani ekle.
                tgt = lines[abs_start]
                for wrong in ("libtinyxml2_1",):
                    if wrong in libs:
                        for k in range(abs_start, min(abs_start + 40, len(lines))):
                            if f'"{wrong}"' in lines[k]:
                                lines[k] = lines[k].replace(f'"{wrong}",\n', "")
                                libs.discard(wrong)
                                break
                lines[abs_start] = lines[abs_start] + "".join(
                    f'{indent}"{a}",\n' for a in alias_missing
                )
                fixed.append(f"{name} (+shared_libs: {', '.join(alias_missing)})")

        hard_add = sorted(m_ for m_ in missing if m_ not in NAME_ALIASES)

        if hard_add and "check_elf_files" not in body:
            add = ["    // Stok blob DT_NEEDED olarak eksik kutuphanelere bagli:\n"]
            add += [f"    //   {mod}\n" for mod in hard_add]
            add.append("    // Agacin diger prebuilt blob'larinda oldugu gibi ELF kontrolu kapatildi.\n")
            add.append("    check_elf_files: false,\n")
            lines[j:j] = add
            j += len(add)
            fixed.append(f"{name} (+check_elf_files: {', '.join(hard_add)})")

        out.extend(lines[i : j + 1])
        i = j + 1

    if not fixed:
        print("degisiklik yok: eksik DT_NEEDED bulunamadi")
        return 0

    BP.write_text("".join(out))
    print(f"{len(fixed)} modul duzeltildi:")
    for f in fixed:
        print(f"  {f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
