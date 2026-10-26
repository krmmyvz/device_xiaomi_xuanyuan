#!/usr/bin/env python3
"""
Eksik `out/` klasörlerini (cargo_embargo / crate build.rs ciktilari) yeniden uretir.

Sorun: AOSP'de `external/rust/android-crates-io/crates/<crate>/out/` klasoru
`repo sync` ile gelmiyor (git'e eklenmemis). Soong'daki
`copy_<crate>_build_out` genrule'u `cmd: "cp $(in) $(genDir)"` ile bu klasoru
kopyalamaya calisiyor; klasor yoksa `cp: Needs 2 arguments` ile build duster.

Bu script her crate icin build.rs'i OUT_DIR=<crate>/out ile derleyip
calistirir, boylece `out/` altindaki dosyalar (version.rs, bindings.rs, ...)
uretilir.

Idempotenttir: `out/` zaten dogruysa dokunmaz.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

CRATES_ROOT = Path("/mnt/src/external/rust/android-crates-io/crates")
RUST_BIN = Path("/mnt/src/prebuilts/rust/linux-x86/1.88.0/bin")


def crate_needs_out(crate_dir: Path) -> list[str]:
    """Android.bp'deki copy_*_build_out genrule'undan beklenen out dosyalarini dondurur."""
    bp = crate_dir / "Android.bp"
    if not bp.exists():
        return []
    txt = bp.read_text()
    m = re.search(
        r'genrule\s*\{[^}]*?name:\s*"copy_[^"]*_build_out".*?out:\s*\[(.*?)\]',
        txt,
        re.S,
    )
    if not m:
        return []
    return re.findall(r'"([^"]+)"', m.group(1))


def run_build_rs(crate_dir: Path) -> tuple[bool, str]:
    """build.rs'i OUT_DIR=crate/out ile derleyip calistirir."""
    build_rs = crate_dir / "build.rs"
    if not build_rs.exists():
        return False, "build.rs yok"

    out_dir = crate_dir / "out"
    out_dir.mkdir(parents=True, exist_ok=True)

    rustc = RUST_BIN / "rustc"
    if not rustc.exists():
        return False, "rustc bulunamadi: %s" % rustc

    # build.rs genellikle dis crate'lere bagimli (orn. gl_generator, bindgen).
    # AOSP crate'leri ayni agacin altinda; rustc --extern ile baglamak gerekir.
    cmd = [
        str(rustc),
        "--edition=2021",
        "-O",
        "--out-dir",
        str(crate_dir / ".build_rs_bin"),
        str(build_rs),
    ]

    env = dict(os.environ)
    env["OUT_DIR"] = str(out_dir)
    env["CARGO_PKG_VERSION"] = crate_version(crate_dir)
    env["PATH"] = str(RUST_BIN) + ":" + env.get("PATH", "")

    # once derle
    p = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=str(crate_dir))
    if p.returncode != 0:
        return False, (p.stderr or p.stdout)[-600:]

    exe = crate_dir / ".build_rs_bin" / "build_rs"
    if not exe.exists():
        return False, "calistirilabilir uretilmedi"

    p2 = subprocess.run([str(exe)], capture_output=True, text=True, env=env, cwd=str(crate_dir))
    return p2.returncode == 0, (p2.stderr or p2.stdout)[-600:]


def crate_version(crate_dir: Path) -> str:
    toml = crate_dir / "Cargo.toml"
    if toml.exists():
        m = re.search(r'^version\s*=\s*"([^"]+)"', toml.read_text(), re.M)
        if m:
            return m.group(1)
    return "0.0.0"


def main() -> int:
    if not CRATES_ROOT.is_dir():
        print("crates root yok: %s" % CRATES_ROOT, file=sys.stderr)
        return 1

    fixed, skipped, failed = [], [], []

    for bp in sorted(CRATES_ROOT.glob("*/Android.bp")):
        crate_dir = bp.parent
        expected = crate_needs_out(crate_dir)
        if not expected:
            continue

        out_dir = crate_dir / "out"
        missing = [f for f in expected if not (out_dir / f).exists()]
        if not missing:
            skipped.append(crate_dir.name)
            continue

        ok, msg = run_build_rs(crate_dir)
        if ok:
            still = [f for f in expected if not (out_dir / f).exists()]
            if still:
                failed.append((crate_dir.name, "uretildi ama eksik: %s" % still))
            else:
                fixed.append(crate_dir.name)
        else:
            failed.append((crate_dir.name, msg.strip()[:300]))

    print("DUZELTILEN: %s" % (", ".join(fixed) or "-"))
    print("GEREKSIZ (zaten tam): %s" % (", ".join(skipped) or "-"))
    if failed:
        print("BASARISIZ:")
        for name, msg in failed:
            print("  - %s: %s" % (name, msg))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
