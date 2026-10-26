# Port tooling

Helpers used to bring the stock vendor/odm blobs in line with the AOSP 16 tree.

| Tool | Purpose |
|---|---|
| `elf_needed_fix.py` | Reconciles prebuilt `shared_libs` with each blob's `DT_NEEDED` (adds the matching platform or vendor module, drops other versions of the same AIDL interface, disables the ELF check only when the blob is missing from the dump). Idempotent; run until it reports no changes. `EXCLUDE_PLATFORM` lists platform modules that must not be picked (unfrozen AIDL versions). |
| `soname_scan.py` | Lists prebuilt libraries whose output name differs from the blob's `DT_SONAME`. |
| `add_blobs_list.py` | Adds prebuilt libraries from a device dump, listed in a TSV file. |
| `stock_sepolicy.py` | Installs the device's stock vendor/odm SELinux policy instead of the AOSP-built one (see `build-support/platform-patches/system__sepolicy.patch`). |
| `fc_compare.py` | Compares on-device SELinux labels of vendor/odm executables with the build's `file_contexts`. |
| `build_ota.sh` | Build wrapper (keep-going, timestamped logs), e.g. `build_ota.sh evolution`. |

Typical loop after changing blobs:

    export EXCLUDE_PLATFORM=vendor.qti.hardware.display.config-V16-ndk,android.hardware.biometrics.fingerprint-V5-ndk
    VROOT=vendor/xiaomi/xuanyuan python3 scripts/port/elf_needed_fix.py vendor/xiaomi/xuanyuan/Android.bp so_targets.txt <llvm-readobj> --apply
    python3 scripts/port/soname_scan.py vendor/xiaomi/xuanyuan/Android.bp vendor/xiaomi/xuanyuan <llvm-readobj>
    out/host/linux-x86/bin/bpfmt -l vendor/xiaomi/xuanyuan/Android.bp

`so_targets.txt` is the list of `*.so` ninja targets:
`ninja -f out/combined-<product>.ninja -t targets all | cut -d: -f1 | grep -E '/android(_vendor|_product)?_arm64_armv8-a_shared/[^/]+\.so$'`.
