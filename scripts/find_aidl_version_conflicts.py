#!/usr/bin/env python3
"""
AIDL surum cakismasi denetleyicisi.

Soong kurali: bir modulun bir varyantinda iki farkli aidl_interface surumu
bagimlilik kapali (closure) icinde bulunamaz. Aksi halde:

  error: module "X" depends on multiple versions of the same
         aidl_interface: android.hardware.camera.device-V2-ndk-source,
         android.hardware.camera.device-V3-ndk-source

Varyant kapsami dikkate alinir:
  - target: { android_arm64: { ... } }  -> her hedef kendi kapsaminda
    (ust seviye lib'ler hedefe miras alinir)
  - soong_config_variables: { a: {...}, b: {...} } -> degerler MUTLAK
    EXCLUSIVE'dir; ayni anda yalnizca biri secilir. Bu yuzden farkli
    degerlerdeki surumler cakisma sayilmaz.

Transitif kapali tam hesaplanmaz (Soong'un isidir); dogrudan referanslar
hatanin kaynagini gosterir.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOTS = [
    pathlib.Path("/mnt/src/vendor/xiaomi/xuanyuan/Android.bp"),
    pathlib.Path("/mnt/src/hardware/qcom-caf/sm8750/display/hal/composer/Android.bp"),
]
LIB_KEYS = ("shared_libs", "static_libs", "header_libs", "whole_static_libs")
VER = re.compile(r"^(?P<base>.+)-V(?P<v>\d+)-ndk(?:_vendor|-source)?$")


def iface_version(lib: str) -> tuple[str, int] | None:
    m = VER.match(lib)
    return (m.group("base"), int(m.group("v"))) if m else None


def block_at(text: str, open_idx: int) -> tuple[str, int]:
    """{ ... } govdesini ve kapanis konumunu dondurur."""
    depth, k = 0, open_idx
    while k < len(text):
        if text[k] == "{":
            depth += 1
        elif text[k] == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1 : k], k
        k += 1
    return text[open_idx + 1 :], len(text)


def strip_named(body: str, names: tuple[str, ...]) -> str:
    """Verilen blok etiketlerinin govdesini (ic ice dahil) cikarir."""
    out = body
    for name in names:
        while True:
            m = re.search(rf"\b{name}\s*:\s*\{{", out)
            if not m:
                break
            j = out.find("{", m.start())
            inner, end = block_at(out, j)
            out = out[: m.start()] + out[end + 1 :]
    return out


def leaves(inner: str) -> list[tuple[str, str]]:
    """ic ice blok icermeyen (yaprak) deger bloklari: (ad, govde)."""
    out = []
    for m in re.finditer(r"([A-Za-z0-9_]+)\s*:\s*\{", inner):
        j = inner.find("{", m.start())
        val, _ = block_at(inner, j)
        if not re.search(r"[A-Za-z0-9_]+\s*:\s*\{", val):
            out.append((m.group(1), val))
    return out


def refs_in(body: str) -> list[str]:
    out = []
    for key in LIB_KEYS:
        for lm in re.finditer(rf"{key}\s*:\s*\[(.*?)\]", body, re.S):
            out += re.findall(r'"([^"]+)"', lm.group(1))
    return out


def scopes(body: str) -> list[tuple[str, list[str]]]:
    """(kapsam adi, o kapsamdaki lib referanslari) listesi."""
    result: list[tuple[str, list[str]]] = []
    top = strip_named(body, ("soong_config_variables", "target"))
    result.append(("default", refs_in(top)))

    # soong_config_variables: degerler mutually exclusive
    m = re.search(r"\bsoong_config_variables\s*:\s*\{", body)
    if m:
        j = body.find("{", m.start())
        inner, _ = block_at(body, j)
        for name, val in leaves(inner):
            result.append((f"config:{name}", refs_in(top) + refs_in(val)))

    # target: her hedef kendi kapsaminda, ust seviye lib'leri miras alir
    m = re.search(r"\btarget\s*:\s*\{", body)
    if m:
        j = body.find("{", m.start())
        inner, _ = block_at(body, j)
        for name, val in leaves(inner):
            result.append((f"target:{name}", refs_in(top) + refs_in(val)))
    return result


def main() -> int:
    conflicts = 0
    for path in ROOTS:
        if not path.is_file():
            continue
        src = path.read_text(errors="replace")
        print(f"--- {path.relative_to(pathlib.Path('/mnt/src'))}")
        for m in re.finditer(r'name:\s*"([^"]+)"(.*?)(?=\n\}\n)', src, re.S):
            mod, body = m.group(1), m.group(2)
            for scope, libs in scopes(body):
                seen: dict[str, set[int]] = {}
                for lib in libs:
                    iv = iface_version(lib)
                    if iv:
                        seen.setdefault(iv[0], set()).add(iv[1])
                for iface, vers in seen.items():
                    if len(vers) > 1:
                        conflicts += 1
                        print(f"  CAKISMA: {mod}  [{scope}]")
                        print(f"      {iface}: {sorted(vers)}")
    print()
    print(f"TOPLAM CAKISMA: {conflicts}" if conflicts else "AIDL surum cakismasi yok")
    return 1 if conflicts else 0


if __name__ == "__main__":
    sys.exit(main())
