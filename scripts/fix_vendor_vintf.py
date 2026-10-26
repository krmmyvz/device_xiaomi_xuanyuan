"""Vendor VINTF fragment'larindaki cakisan HAL bildirimlerini duzeltir.

SORUN
-----
Cihaz agaci, `vibratorfeature-wrapper-neoteric` ile AIDL vibrator V2 sunuyor
(neoteric_compat/odm/etc/vintf/manifest/android.hardware.vibrator.xml ->
IVibrator/default, version 2).

Stok vendor fragment'i ise ayni instance'i V1 olarak iddia ediyor:

    vendor/xiaomi/xuanyuan/proprietary/odm/etc/vintf/manifest/
        vendor.xiaomi.hardware.vibratorfeature.service.xml
        <fqname>IVibrator/default</fqname>        <- CAKISAN
        <fqname>IVibrator/vibratorfeature</fqname>

checkvintf build'i bununla durur:

    HAL "android.hardware.vibrator" has a conflict:
    Conflicting FqInstance: IVibrator/default (@2) vs IVibrator/default (@1)

COZUM
-----
Stok fragment'ten yalnizca `IVibrator/default` satiri kaldirilir.
`IVibrator/vibratorfeature` korunur: o farkli bir instance adi, cakismiyor ve
Xiaomi'ye ozel titresim ozellikleri icin gerekli.

Vendor agaci bir artifact oldugu icin (repo sync/install_vendor_tree sonrasi
sifirlanir) bu duzeltme script olarak tutulur. Idempotenttir.
"""
from __future__ import annotations

import pathlib
import sys

VENDOR = pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/proprietary/odm/etc/vintf/manifest")
FRAGMENT = VENDOR / "vendor.xiaomi.hardware.vibratorfeature.service.xml"
CONFLICTING = "<fqname>IVibrator/default</fqname>"


def main() -> int:
    if not FRAGMENT.is_file():
        print(f"ATLANDI: {FRAGMENT} yok (vendor agaci kurulu degil olabilir)")
        return 0

    text = FRAGMENT.read_text()
    if CONFLICTING not in text:
        print("degisiklik yok: cakisan satir zaten kaldirilmis")
        return 0

    kept = [ln for ln in text.splitlines(True) if CONFLICTING not in ln]
    if not any("IVibrator/vibratorfeature" in ln for ln in kept):
        print("HATA: vibratorfeature satiri da kayboldu, islem iptal", file=sys.stderr)
        return 1

    FRAGMENT.write_text("".join(kept))
    print(f"duzeltildi: {FRAGMENT.relative_to('/mnt/src')}")
    print(f"  kaldirildi: {CONFLICTING}")
    print("  korundu   : <fqname>IVibrator/vibratorfeature</fqname>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
