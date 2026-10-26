#!/usr/bin/env python3
"""
hardware/xiaomi/aidl/fingerprint/Android.bp icindeki platform kaynak
fingerprint servisini devre disi birakir.

SORUN
-----
Cihaz agaci (device/xiaomi/xuanyuan/neoteric_compat) stok Xiaomi
fingerprint binary'sini 'stem' ile ayni dosya adina kuruyor:

  cc_prebuilt_binary {
      name: "android.hardware.biometrics.fingerprint-service.xiaomi-neoteric",
      stem: "android.hardware.biometrics.fingerprint-service.xiaomi",
      srcs: ["vendor/bin/hw/android.hardware.biometrics.fingerprint-service.xiaomi"],
  }

Platform tarafinda ayni cikti yolunu ureten kaynak modul de var:

  cc_binary {
      name: "android.hardware.biometrics.fingerprint-service.xiaomi",
      relative_install_path: "hw",
      ...
  }

Iki modul ayni dosyayi uretir -> ninja hatasi:

  FAILED: ninja: multiple rules generate
  out/target/product/xuanyuan/symbols/vendor/bin/hw/
  android.hardware.biometrics.fingerprint-service.xiaomi [-w dupbuild=err]

COZUM
-----
Platform kaynak modulunun TUM cikti uretimini durdurulur:
  - 'enabled: false'  -> modul hic derlenmez/uretilmez
  - init_rc / vintf_fragments kaldirilir (cihaz agacindaki -neoteric
    varyanti kendi init.rc ve VINTF dosyalarini veriyor)

Stok blob kullanilir; platform kaynagi devre disi kalir.

Idempotenttir.
"""
from __future__ import annotations

import pathlib
import re

BP = pathlib.Path("/mnt/src/hardware/xiaomi/aidl/fingerprint/Android.bp")

txt = BP.read_text(errors="replace")
orig = txt

# Platform modulunun govdesini bul
m = re.search(
    r'cc_binary\s*\{\s*\n\s*name:\s*"android\.hardware\.biometrics\.fingerprint-service\.xiaomi",',
    txt)
if not m:
    print("[!] platform fingerprint modulu bulunamadi")
    raise SystemExit(0)

# Blok govdesinin sonunu bul (kapanis '}')
start = txt.rfind("{", 0, m.end())
depth = 0
i = start
while i < len(txt):
    if txt[i] == "{":
        depth += 1
    elif txt[i] == "}":
        depth -= 1
        if depth == 0:
            break
    i += 1
block = txt[start:i + 1]

new_block = block
# 1) enabled: false ekle (name'den sonra)
if "enabled:" not in new_block:
    new_block = re.sub(
        r'(name:\s*"android\.hardware\.biometrics\.fingerprint-service\.xiaomi",\n)',
        r'\1    enabled: false,\n',
        new_block,
        count=1,
    )
# 2) init_rc ve vintf_fragments satirlarini kaldir
new_block = re.sub(r"^[ \t]*init_rc:\s*\[[^\]]*\],[ \t]*\n", "", new_block, flags=re.M)
new_block = re.sub(r"^[ \t]*vintf_fragments:\s*\[[^\]]*\],[ \t]*\n", "", new_block, flags=re.M)

txt = txt[:start] + new_block + txt[i + 1:]

if txt != orig:
    BP.write_text(txt)
    print("[✓] platform fingerprint modulu devre disi birakildi (enabled: false)")
    print("    (stok blob: android.hardware.biometrics.fingerprint-service.xiaomi-neoteric)")
else:
    print("[✓] degisiklik yok")
