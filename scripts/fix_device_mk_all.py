#!/usr/bin/env python3
"""
device.mk'deki tum kati/Soong uyumsuzluklarini TEK seferde duzeltir.

Uygulanan duzeltmeler:
  1) PRODUCT_PACKAGES'teki tanimsiz moduller (hicbir projede tanimli degil):
     listeden SILINIR. (Yorum satiri degil - backslash'li listede yorum
     satiri sonraki gercek uyeleri de yorumlar ve listeyi bozar.)
  2) '-xuanyuan' onekiyle yeniden adlandirilan init script'ler:
     cihaz agacinin kendi (guncellenmis) kopyasi kurulur -> duz ad.
  3) 'xiaomi.prebuilt.' onekiyle yeniden adlandirilan vendor prebuilt'ler:
     kurulum kaydi yeni adi kullanir.
  4) Yanlis yol/eksik kaynakli PRODUCT_COPY_FILES kayitlari:
     ya gercek dosyaya yonlendirilir ya listeden kaldirilir.
  5) Uyesi kalmamis (bos) backslash'li PRODUCT_PACKAGES listeleri temizlenir.

Idempotenttir.
"""
from __future__ import annotations

import os
import pathlib
import re
import sys

MK = pathlib.Path("/mnt/src/device/xiaomi/xuanyuan/device.mk")
ROOT = pathlib.Path("/mnt/src")

# --- 1) hicbir projede tanimli olmayan moduller -------------------------
REMOVE = {
    "EidService",
    "OpenEUICC",
    "libimsmedia_jni-xuanyuan",
    "uimremoteclient",
    "uimremoteclientlibrary",
    "uimremoteserver",
    "uimremoteserverlibrary",
    "xuanyuan_uimremoteclient_permission",
    "xuanyuan_uimremoteserver_permission",
    # installable:false -> kurulamaz; stok blob PRODUCT_COPY_FILES ile kopyalanir
    "libcamera2ndk_vendor_vendor",
    # uydurma ad -> hicbir yerde tanimli degil
    "libcamera2ndk_vendor-xuanyuan-runtime",
}

# --- 2) duz adi kullanilacaklar -----------------------------------------
RENAME = {
    "init.qcom.usb.sh-xuanyuan": "init.qcom.usb.sh",
    "init.qti.media.sh-xuanyuan": "init.qti.media.sh",
    "init.qti.display_boot.sh-xuanyuan": "init.qti.display_boot.sh",
}

# --- 3) xiaomi.prebuilt. adi gerekenler ---------------------------------
PREBUILT = {
    "android.media.audio.common.types-V6-ndk",
    "vendor.qti.hardware.display.aiqe-V2-ndk",
    "vendor.qti.hardware.display.color-V1-ndk",
    "vendor.qti.hardware.display.composer3-V1-ndk",
    "vendor.qti.hardware.display.composer3-V2-ndk",
    "vendor.qti.hardware.display.composer3-V3-ndk",
    "vendor.qti.hardware.display.demura-V1-ndk",
    "vendor.qti.hardware.display.postproc-V1-ndk",
}

# --- 4) PRODUCT_COPY_FILES yol duzeltmeleri ------------------------------
COPY_RENAME = {
    "vendor/xiaomi/xuanyuan/proprietary/system_ext/framework/qti-telephony-hidl-wrapper.jar":
        "device/xiaomi/xuanyuan/prebuilts/esim/framework/qti-telephony-hidl-wrapper-prd.jar",
    "vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/camera_extensions.xml":
        "device/xiaomi/xuanyuan/neoteric_compat/vendor/etc/permissions/camera_extensions.xml",
}
# kaynagi hicbir yerde olmayanlar -> kayit kaldirilir
COPY_DROP = {
    "vendor/xiaomi/xuanyuan/proprietary/system_ext/framework/qti-telephony-utils.jar",
    "vendor/xiaomi/xuanyuan/proprietary/system_ext/framework/qcrilhook.jar",
    "vendor/xiaomi/xuanyuan/proprietary/system_ext/etc/permissions/qcrilhook.xml",
}
# libcamera2ndk_vendor: installable:false -> kurulamaz; stok blob kopyalanir
COPY_ADD_ANCHOR = "# Required by mifaced/libcamera2ndk_vendor at runtime."
COPY_ADD = (
    "PRODUCT_COPY_FILES += \\\n"
    "    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/libcamera2ndk_vendor.so:"
    "$(TARGET_COPY_OUT_VENDOR)/lib64/libcamera2ndk_vendor.so"
)


def fix_lines(lines):
    out = []
    for line in lines:
        stripped = line.strip()

        # Tek satirlik yigin: 'PRODUCT_PACKAGES +=     A     B     C'
        m = re.match(r"^(PRODUCT_PACKAGES \+=\s+)(.+)$", stripped)
        if m and not m.group(2).endswith("\\"):
            names = m.group(2).split()
            kept = [n for n in names if n not in REMOVE]
            dropped = [n for n in names if n in REMOVE]
            if dropped:
                print("[~] tek satir: %s silindi" % ", ".join(dropped))
                indent = line[: len(line) - len(line.lstrip())]
                if kept:
                    out.append(indent + m.group(1) + " ".join(kept))
                continue

        # Satir basina tek modul
        m = re.match(r"^(\s*)([A-Za-z0-9_.@\-]+)(\s*\\?\s*)$", line)
        if m:
            name = m.group(2)
            if name in REMOVE:
                print("[~] %s silindi" % name)
                continue
            if name in RENAME:
                out.append(m.group(1) + RENAME[name] + m.group(3))
                print("[+] %s -> %s" % (name, RENAME[name]))
                continue
            if name in PREBUILT:
                out.append(m.group(1) + "xiaomi.prebuilt." + name + m.group(3))
                print("[+] %s -> xiaomi.prebuilt.%s" % (name, name))
                continue
            out.append(line)
            continue

        # Satir ici birden fazla ad
        new_line = line
        for name in PREBUILT:
            if re.search(r"(?<![\w.-])%s(?![\w.-])" % re.escape(name), new_line):
                new_line = re.sub(r"(?<![\w.-])%s(?![\w.-])" % re.escape(name),
                                  "xiaomi.prebuilt." + name, new_line)
                print("[+] prebuilt oneki: %s" % new_line.strip()[:60])
        for name in REMOVE:
            if re.search(r"(?<![\w.-])%s(?![\w.-])" % re.escape(name), new_line):
                print("[~] %s satirdan silindi" % name)
                new_line = re.sub(r"(?<![\w.-])%s(?![\w.-])\s*\\?\s*" % re.escape(name),
                                  "", new_line)
        out.append(new_line)
    return out


def main() -> int:
    txt = MK.read_text(errors="replace")
    orig = txt

    # 4a) COPY_RENAME / COPY_DROP
    for old, new in COPY_RENAME.items():
        if old in txt:
            txt = txt.replace(old, new)
            print("[+] copy yolu: %s -> %s" % (old.split("/")[-1], new.split("/")[-1]))
    for d in COPY_DROP:
        if d in txt:
            txt = re.sub(r"^[ \t]*%s:[^\n]*\n" % re.escape(d), "", txt, flags=re.M)
            print("[~] copy kaydi silindi: %s" % d.split("/")[-1])

    # 4b) libcamera2ndk_vendor kopyalama
    if "libcamera2ndk_vendor.so:" not in txt:
        txt = txt.replace(COPY_ADD_ANCHOR, COPY_ADD_ANCHOR + "\n" + COPY_ADD)
        print("[+] libcamera2ndk_vendor.so kopyalama eklendi")
    # libcamera2ndk_vendor_vendor listeden kaldir
    txt = re.sub(r"^[ \t]*libcamera2ndk_vendor_vendor\s*\\?\s*\n", "", txt, flags=re.M)

    # 1-3) satir bazli duzeltmeler
    txt = "\n".join(fix_lines(txt.split("\n")))

    # 5) bos backslash'li PRODUCT_PACKAGES listeleri
    lines = txt.split("\n")
    out = []
    i = 0
    removed = 0
    while i < len(lines):
        line = lines[i]
        if re.match(r"^\s*PRODUCT_PACKAGES\s*\+=\s*\\?\s*$", line) and line.rstrip().endswith("\\"):
            j = i + 1
            members = []
            while j < len(lines):
                nxt = lines[j]
                if not nxt.strip() or nxt.strip().startswith("#"):
                    break
                if re.match(r"^\s*PRODUCT_", nxt) or re.match(r"^\s*[A-Z_]{3,}", nxt):
                    break
                members.append(nxt)
                j += 1
            if not members:
                removed += 1
                i = j
                continue
            out.append(line)
            out.extend(members)
            i = j
            continue
        out.append(line)
        i += 1
    txt = "\n".join(out)
    if removed:
        print("[~] %d bos PRODUCT_PACKAGES listesi temizlendi" % removed)

    if txt != orig:
        MK.write_text(txt)
        print("[✓] device.mk guncellendi")

    # dogrulama
    txt = MK.read_text(errors="replace")
    missing = []
    for m in re.finditer(r"PRODUCT_COPY_FILES \+= \\\n((?:[^\n]*\\\n)*[^\n]*)", txt):
        for raw in m.group(1).split("\n"):
            line = raw.strip().rstrip("\\").strip()
            if not line or line.startswith("#") or ":" not in line:
                continue
            src = line.split(":")[0].strip()
            if src.startswith("$") or src.startswith("%"):
                continue
            if not (ROOT / src).exists():
                missing.append(src)
    print()
    if missing:
        print("[!] EKSIK COPY KAYNAKLARI (%d):" % len(missing))
        for s in missing:
            print("    ", s)
    else:
        print("[✓] tum PRODUCT_COPY_FILES kaynaklari mevcut")
    return 0


if __name__ == "__main__":
    sys.exit(main())
