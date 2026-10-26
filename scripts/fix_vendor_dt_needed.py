"""Vendor prebuilt modullerine eksik DT_NEEDED bagimliliklarini ekler.

SORUN
-----
Stok Xiaomi blob'lari DT_NEEDED olarak bir AIDL/HIDL kutuphanesine bagli oluyor,
ama uretilmis `vendor/xiaomi/xuanyuan/Android.bp` bu bagimliliklari `shared_libs`
listesine yazmiyor. Android 16'nin `check_elf_file` kontrolu bunu yakalip build'i
durduruyor:

    vendor/.../displayfeature.default.so: error: DT_NEEDED
    "android.hardware.sensors-V3-ndk.so" is not specified in shared_libs.

COZUM
-----
1. `readelf -d` ile her prebuilt'in gercek DT_NEEDED listesini oku.
2. Bunlari mevcut `shared_libs` ile karsilastir; eksik olanlari ekle.
3. Sadece build sisteminde gercekten var olan modulleri ekle (isim cikarimi yap:
   `libfoo.so` -> `libfoo`, `android.hardware.sensors-V3-ndk.so` -> ayni isim).

Modul adlari Android.bp icinde `cc_prebuilt_library_shared` bloklarinda ve
`shared_libs` listelerinde geciyor; her blok kendi `srcs` dosyasina sahip.

Idempotenttir: eksik bagimlilik yoksa hicbir sey degistirmez.
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

BP = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp")
READELF = "/mnt/src/prebuilts/binary-tools/linux-x86/aarch64-linux-android-readelf"
FALLBACK_READELF = "readelf"

# Soong'da zaten var olan, DT_NEEDED listesinde gorunmesi beklenmeyen sistem kutuphaneleri.
SKIP_PREFIXES = (
    "libc.so", "libm.so", "libdl.so", "liblog.so", "libc++", "libstdc++",
    "libandroid.so", "libcutils.so", "libutils.so", "libhidlbase.so",
    "libbinder.so", "libbinder_ndk.so", "libbase.so", "libz.so",
    "libvndksupport.so", "libutilscallstack.so", "libsync.so", "libfmq.so",
    "libcrypto.so", "libssl.so", "libsqlite.so", "libexpat.so", "libft2.so",
    "libjpeg.so", "libpng.so", "libwebp.so", "libmedia.so", "libEGL.so",
    "libGLESv2.so", "libOpenSLES.so", "libaaudio.so", "libcamera_metadata.so",
    "libgui.so", "libui.so", "libsurfaceflinger.so", "libhardware.so",
)


def dt_needed(path: pathlib.Path) -> list[str]:
    """Bir .so dosyasinin DT_NEEDED girdilerini dondurur (son .so isimleri)."""
    for tool in (READELF, FALLBACK_READELF):
        try:
            r = subprocess.run(
                [tool, "-d", str(path)],
                capture_output=True, text=True, timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        if r.returncode != 0:
            continue
        out = []
        for line in r.stdout.splitlines():
            m = re.search(r"\(NEEDED\)\s+Shared library:\s+\[([^\]]+)\]", line)
            if m:
                out.append(m.group(1))
        if out:
            return out
    return []


def to_module_name(so_name: str) -> str | None:
    """libfoo.so -> libfoo ; android.hardware.sensors-V3-ndk.so -> ayni isim."""
    if so_name.endswith(".so"):
        return so_name[:-3]
    return None


def main() -> int:
    if not BP.is_file():
        print(f"HATA: {BP} yok")
        return 1

    text = BP.read_text()
    lines = text.splitlines(True)

    # Modul bloklarini ve icindeki shared_libs listelerini bul.
    # Her blok: (start, end, name, srcs, shared_libs_baslangic_satir, shared_libs_son_satir)
    blocks = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("cc_prebuilt_library_shared {"):
            j = i + 1
            while j < len(lines) and lines[j].rstrip("\n") != "}":
                j += 1
            block = lines[i : j + 1]
            body = "".join(block)
            name = re.search(r'name:\s*"([^"]+)"', body)
            srcs = re.findall(r'"([^"]+\.so)"', body)
            # shared_libs listesi: icindeki tum "..." degerleri
            m = re.search(r"shared_libs:\s*\[(.*?)\]", body, re.S)
            libs = re.findall(r'"([^"]+)"', m.group(1)) if m else []
            blocks.append((i, j, name.group(1) if name else "?", srcs, libs))
            i = j + 1
        else:
            i += 1

    # Butun modullerde kullanilan tum shared_libs isimleri (var olan modul havuzu).
    known: set[str] = set()
    for _, _, _, _, libs in blocks:
        known.update(libs)

    changed_blocks = 0
    added_total = 0
    report: list[str] = []

    for start, end, name, srcs, libs in blocks:
        if not srcs:
            continue
        root = BP.parent
        needed: set[str] = set()
        for s in srcs:
            p = root / s
            if p.is_file():
                needed.update(dt_needed(p))
        if not needed:
            continue

        existing = set(libs)
        missing = []
        for so in sorted(needed):
            if any(so.startswith(sk) for sk in SKIP_PREFIXES):
                continue
            mod = to_module_name(so)
            if not mod or mod in existing:
                continue
            # Sadece Soong tarafinda gercekten var olan modulleri ekle.
            if mod in known:
                missing.append(mod)
        if not missing:
            continue

        # shared_libs listesini gercek yeriyle bul ve ekle.
        body = "".join(lines[start : end + 1])
        m = re.search(r"shared_libs:\s*\[(.*?)\]", body, re.S)
        if not m:
            continue
        abs_start = start + body[: m.start(1)].count("\n")
        abs_end = abs_start + m.group(1).count("\n")
        target = lines[abs_start]
        indent = re.match(r"\s*", target).group(0)
        addition = "".join(f'{indent}"{mod}",\n' for mod in missing)
        lines[abs_start] = target + addition
        shift = len(missing)
        changed_blocks += 1
        added_total += len(missing)
        report.append(f"{name}: +{', '.join(missing)}")

    if not changed_blocks:
        print("degisiklik yok: eksik DT_NEEDED bulunamadi")
        return 0

    BP.write_text("".join(lines))
    print(f"{changed_blocks} modul guncellendi, {added_total} bagimlilik eklendi")
    for r in report:
        print(f"  {r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
