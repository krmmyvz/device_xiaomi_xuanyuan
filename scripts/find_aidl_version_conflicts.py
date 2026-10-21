#!/usr/bin/env python3
"""
AIDL surum cakismasi denetleyicisi.

Soong kurali: bir modulun bagimlilik kapali (closure) tek bir
aidl_interface'in iki farkli surumunu iceremez. Aksi halde:

  error: module "X" depends on multiple versions of the same
         aidl_interface: android.hardware.camera.device-V2-ndk-source,
         android.hardware.camera.device-V3-ndk-source

Bu betik, vendor Android.bp'sindeki ve sm8750 CAF asagacindaki her
modulun dogrudan kutuphane referanslarini tarar ve ayni arayuzun
iki surumunu birden gosteren modulleri raporlar.

Transitif kapali tam olarak hesaplanmaz (Soong'un isidir), ama dogrudan
referanslar hatanin kaynagini gosterir.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOTS = [
    pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp"),
    pathlib.Path("/mnt/src/hardware/qcom-caf/sm8750/display/hal/composer/Android.bp"),
    pathlib.Path("/mnt/src/hardware/qcom-caf/sm8750/audio/primary-hal/Android.bp"),
]
LIB_KEYS = ("shared_libs", "static_libs", "header_libs", "whole_static_libs")
VER = re.compile(r"^(?P<base>.+)-V(?P<v>\d+)-ndk(?:_vendor|-source)?$")


def iface_version(lib: str) -> tuple[str, int] | None:
    m = VER.match(lib)
    if not m:
        return None
    return m.group("base"), int(m.group("v"))


def main() -> int:
    conflicts = 0
    for path in ROOTS:
        if not path.is_file():
            continue
        src = path.read_text(errors="replace")
        rel = path.relative_to(pathlib.Path("/mnt/src"))
        print(f"--- {rel}")
        for m in re.finditer(r'name:\s*"([^"]+)"(.*?)(?=\n\})', src, re.S):
            mod, body = m.group(1), m.group(2)
            seen: dict[str, set[int]] = {}
            for key in LIB_KEYS:
                for lm in re.finditer(rf"{key}:\s*\[(.*?)\]", body, re.S):
                    for r in re.finditer(r'"([^"]+)"', lm.group(1)):
                        iv = iface_version(r.group(1))
                        if iv:
                            seen.setdefault(iv[0], set()).add(iv[1])
            for iface, vers in seen.items():
                if len(vers) > 1:
                    conflicts += 1
                    print(f"  CAKISMA: {mod}")
                    print(f"      {iface}: {sorted(vers)}")
    print()
    if conflicts:
        print(f"TOPLAM CAKISMA: {conflicts}")
        return 1
    print("AIDL surum cakismasi yok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
