"""Vendor prebuilt'lerde eksik DT_NEEDED bagimliliklarini toplu coz.

Bu, ELF hata sinifinin KAPANICI script'idir. Onceki turlarda her hatayi tek
tek takip ettik; son burada butun kalan eksikler TEK seferde cozulur.

IKI BAGIMLILIK KATEGORISI
-------------------------
1) `xiaomi.prebuilt.*` modulleri
   Platform AIDL/HIDL modullerinin vendor varyantlari, Soong'un `prebuilt_`
   golgelemesinden kacinmak icin bu onekle yeniden adlandirildi (bkz.
   `fix_prebuilt_name_shadow.py`). Stok blob'lar ORIJINAL adi ister
   (orn. `vendor.qti.hardware.display.demura-V1-ndk.so`), agactaki modul ise
   `xiaomi.prebuilt.vendor.qti.hardware.display.demura-V1-ndk` adini tasir.
   Cozum: shared_libs'e `xiaomi.prebuilt.<ad>` yazilir (stem ayni oldugu icin
   uretilen dosya adi degismez).

2) Diger kutuphaneler
   Agacda gercekten tanimli moduller -> shared_libs'e eklenir.
   Agacda HIC tanimli olmayanlar (orn. `libtinyxml2-neoteric`,
   `vendor.xiaomi.hardware.framemaster-V1-ndk`) -> `check_elf_files: false`
   ile ELF kontrolu kapatilir (agacin diger blob'larindaki yaklasim).

Idempotenttir.
"""
from __future__ import annotations

import pathlib
import re
import subprocess

BP = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp")
BLOCK_TYPES = ("cc_prebuilt_library_shared {", "cc_prebuilt_binary {")
PREFIXES = ("android.hardware", "android.frameworks", "vendor.", "android.media",
            "com.qualcomm", "framework-permission", "lib")

# DT_NEEDED adi -> agactaki gercek modul adi
ALIASES: dict[str, str] = {"libtinyxml2": "libtinyxml2"}

# DT_NEEDED'da cok gorulen ama Soong modulu olarak ayri tanimlanmayan sistem kutuphaneleri.
SKIP = {
    "libc", "libm", "libdl", "liblog", "libc++", "libstdc++", "libandroid",
    "libcutils", "libutils", "libhidlbase", "libbinder", "libbinder_ndk",
    "libbase", "libz", "libvndksupport", "libutilscallstack", "libsync",
    "libfmq", "libcrypto", "libssl", "libsqlite", "libexpat", "libft2",
    "libjpeg", "libpng", "libwebp", "libmedia", "libEGL", "libGLESv2",
    "libOpenSLES", "libaaudio", "libcamera_metadata", "libgui", "libui",
    "libsurfaceflinger", "libhardware", "libdrm", "libxml2", "libhidltransport",
    "libgralloctypes",
}

# Agacin tamamindaki modul adlarini topla (hizli: sadece ilgili dizinler).
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
                capture_output=True, text=True, timeout=180,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        for line in out.stdout.splitlines():
            m = re.search(r'"([^"]+)"', line)
            if m:
                names.add(m.group(1))
    return names


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
            m = re.search(r"Shared library: \[([^\]]+)\]", line)
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

    known = all_module_names()
    print(f"agactaki modul sayisi: {len(known)}")

    lines = BP.read_text().splitlines(True)
    out: list[str] = []
    fixed: list[str] = []
    i = 0

    while i < len(lines):
        if not any(lines[i].startswith(t) for t in BLOCK_TYPES):
            out.append(lines[i])
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
        name = nm.group(1) if nm else "?"
        m = re.search(r"shared_libs:\s*\[(.*?)\]", body, re.S)
        libs = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()

        missing: set[str] = set()
        for s in re.findall(r'"([^"]+)"', body):
            f = BP.parent / s
            if not f.is_file():
                continue
            try:
                if f.read_bytes()[:4] != b"\x7fELF":
                    continue
            except OSError:
                continue
            for mod in dt_needed(f):
                if mod in libs:
                    continue
                if mod in SKIP:
                    continue
                if mod.startswith(PREFIXES):
                    missing.add(mod)

        # Gercek modul karsiligi olanlar -> shared_libs'e ekle.
        # Oncelik: ayni adin `xiaomi.prebuilt.` onekli kopyasi (platform
        # AIDL/HIDL modullerinin vendor varyantlari). Soong'un prebuilt_
        # golgelemesinden kacinmak icin yeniden adlandirilmis olduklari icin
        # BU ad kullanilmalidir; aksi halde namespace duvarina takilip
        # "depends on undefined module" hatasi verir.
        resolvable: list[str] = []
        for m_ in sorted(missing):
            pre = f"xiaomi.prebuilt.{m_}"
            # Varyantlar: platform adi, xiaomi.prebuilt onekli karsi,
            # ya da vendor varyanti (`-V<n>-ndk_vendor`).
            cands = [m_, pre, f"{m_}_vendor", f"xiaomi.prebuilt.{m_}_vendor"]
            hit = next((c for c in cands if c in known), None)
            if hit:
                resolvable.append(hit)
            elif ALIASES.get(m_, m_) in known:
                resolvable.append(ALIASES.get(m_, m_))
        # Karsiligi OLMAYANlar -> ELF kontrolunu kapat
        unresolvable = sorted(m_ for m_ in missing if m_ not in resolvable
                              and ALIASES.get(m_, m_) not in known)

        if resolvable:
            mm = re.search(r"shared_libs:\s*\[(.*?)\]", body, re.S)
            if mm:
                abs_start = i + body[: mm.start(1)].count("\n")
                indent = re.match(r"\s*", lines[abs_start]).group(0)
                # Guvenlik: eklenen her ad, DT_NEEDED'da GERCEKTEN gecen bir adin
                # (veya o adin xiaomi.prebuilt karsiliginin) olmali. Aksi halde
                # ayni AIDL arayuzunun iki surumu ayni modulde karisir ve
                # "depends on multiple versions of the same aidl_interface" olur.
                safe = []
                for r_ in resolvable:
                    base = r_[len("xiaomi.prebuilt."):] if r_.startswith("xiaomi.prebuilt.") else r_
                    base = base[:-len("_vendor")] if base.endswith("_vendor") else base
                    if base in missing or base in ALIASES or ALIASES.get(base, base) in missing:
                        safe.append(r_)
                if safe:
                    lines[abs_start] = lines[abs_start] + "".join(
                        f'{indent}"{a}",\n' for a in safe
                    )
                    fixed.append(f"{name} (+shared_libs: {', '.join(safe)})")

        if unresolvable and "check_elf_files" not in body:
            add = ["    // Stok blob, agacta karsiligi olmayan kutuphanelere bagli:\n"]
            add += [f"    //   {mod}\n" for mod in unresolvable]
            add.append("    // Agacin diger prebuilt blob'larinda oldugu gibi ELF kontrolu kapatildi.\n")
            add.append("    check_elf_files: false,\n")
            lines[j:j] = add
            j += len(add)
            fixed.append(f"{name} (+check_elf_files: {', '.join(unresolvable)})")

        out.extend(lines[i : j + 1])
        i = j + 1

    if not fixed:
        print("degisiklik yok: eksik DT_NEEDED bulunamadi")
        return 0

    BP.write_text("".join(out))
    print(f"{len(fixed)} modul duzeltildi")
    for f in fixed:
        print(f"  {f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
