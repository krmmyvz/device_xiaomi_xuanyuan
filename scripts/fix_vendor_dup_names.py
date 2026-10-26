"""Ayni isimle iki kez tanimli vendor prebuilt'leri ayristirir.

SORUN
-----
Stok vendor agacinda bazi prebuilt'ler hem `vendor/lib64/` hem de
`system_ext/lib64/` altinda ayni isimle gelir:

    cc_prebuilt_library_shared { name: "vendor.xiaomi.hardware.fingerprintextension-V1-ndk_vendor" ... }
    cc_prebuilt_library_shared { name: "vendor.xiaomi.hardware.fingerprintextension-V1-ndk_vendor" ... }

Ikinci kopya `system_ext_specific: true` ve `srcs` olarak `system_ext/lib64/...`
iceren bir tanimdir. Soong "already defined" hatasi verir:

    module "prebuilt_vendor.xiaomi.hardware.fingerprintextension-V1-ndk_vendor"
    already defined

COZUM
-----
`system_ext/lib64` kaynakli kopyaya `_systemext` son eki eklenir (ad VE stem).
Boylece iki modul ayri kalir; uretilen dosya adlari da birbirinden ayrilir.
Vendor kopyasi (orijinal ad) degismez.

Idempotenttir.
"""
from __future__ import annotations

import pathlib
import re

BP = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp")
SUFFIX = "_systemext"


def main() -> int:
    if not BP.is_file():
        print(f"HATA: {BP} yok")
        return 1

    lines = BP.read_text().splitlines(True)
    # Ayni adin birden fazla tanimi olan modulleri bul.
    name_count: dict[str, list[int]] = {}
    for i, l in enumerate(lines):
        m = re.match(r'\s*name:\s*"([^"]+)",', l)
        if m and lines[i].startswith("cc_prebuilt"):
            name_count.setdefault(m.group(1), []).append(i)

    changed = 0
    for name, idxs in name_count.items():
        if len(idxs) < 2:
            continue
        for i in idxs:
            window = "".join(lines[i : i + 20])
            if "system_ext/lib64" not in window:
                continue
            new_name = name + SUFFIX
            for k in range(i, min(i + 20, len(lines))):
                if name in lines[k] and '"' in lines[k]:
                    lines[k] = lines[k].replace(name, new_name)
            print(f"satir {i+1}: {name} -> {new_name}")
            changed += 1

    if not changed:
        print("degisiklik yok: tekrarli tanim bulunamadi")
        return 0

    BP.write_text("".join(lines))
    print(f"{changed} tanim ayristirildi")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
