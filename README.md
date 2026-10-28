# device_xiaomi_xuanyuan

Device tree for the **Xiaomi 15 Ultra** (`xuanyuan`), targeting Evolution X / LineageOS on Android 16.

| | |
|---|---|
| Device | Xiaomi 15 Ultra, codename `xuanyuan` |
| SoC | Snapdragon 8 Elite (SM8750-AB), Oryon V2, Adreno 830 |
| Platform | `sun` (SoC) / `pakala` (Qualcomm BSP) |
| Kernel | Linux 6.6, GKI 2.0 (`android15-6.6`), prebuilt |
| Product | `lineage_xuanyuan` |
| Base | Evolution X 11.x (`bka`), LineageOS 23.2, stock HyperOS 3 (Android 16) vendor |
| Maintainer | moonarch |

## Status

Verified on device with SELinux enforcing:

- Boot, encryption (FBE), 120 Hz display with HDR and high brightness mode
- Touch, vibrator, IR blaster, NFC
- Wi-Fi and Bluetooth (QTI audio provider)
- GPS with XTRA assistance data (fast first fix)
- Sensors, including the Xiaomi-specific ones
- Audio, hardware video encoders and decoders (AVC, HEVC, Dolby Vision)
- MIUI Camera (opens and previews; stock camx HAL)

Not tested yet:

- Mobile data, calls and VoLTE (no SIM during testing)
- Fingerprint enrollment
- Bluetooth audio with a headset
- 90 W wired charging

Known issues:

- No Dolby Atmos settings app
- StrongBox and Weaver on the embedded secure element are disabled
- MIUI Camera's `cameraopt` framework service is not available outside HyperOS

## Related repositories

| Repository | Content |
|---|---|
| `device_xiaomi_xuanyuan` (this repo) | Device tree, build rules, platform patches |
| `device_xiaomi_sm8750_common` | Shared SM8750 platform layer |
| `kernel_xiaomi_generic` | Prebuilt GKI kernel, dtb, dtbo, vendor_boot |
| `proprietary_vendor_xiaomi_xuanyuan` | Proprietary Xiaomi blobs (private) |

The proprietary blobs are extracted from the stock firmware and are not
redistributed here.

## Building

```bash
# 1) Platform source.
#    The pinned manifest does not define remotes or defaults; those live in
#    local_manifests.xml. Defining the same remote twice with different fetch
#    URLs makes repo sync stop with "remote ... already exists".
repo init -u https://github.com/Evolution-X/manifest -b bka --depth=1
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
cp build-support/evox-manifest-pinned.xml .repo/local_manifests/
cp build-support/local_manifests.xml       .repo/local_manifests/local_manifests.xml
repo sync -c -j$(nproc)

# 2) Proprietary payloads (MIUI Camera, stock init scripts, camera compat).
bash scripts/sync_proprietary.sh

# 3) Platform patches.
bash scripts/apply_platform_patches.sh

# 4) Build.
source build/envsetup.sh
lunch lineage_xuanyuan-bp4a-userdebug     # or -user for release builds
m evolution -j$(nproc)
```

`repo sync` drops the platform patches, so run `scripts/apply_platform_patches.sh`
again after every sync. Each patch records its base commit in a `.base` file;
`scripts/verify_patch_bases.py` checks that they still apply.

### Release builds

`user` builds keep Android Verified Boot enabled and leave out the diagnostic
settings used for bring-up. Pass your own AVB key, kept inside the source tree
so Soong accepts it:

```bash
XUANYUAN_AVB_KEY=path/to/avb.pem m target-files-package
```

Then sign the target files with your release keys (`sign_target_files_apks`)
and build the OTA package (`ota_from_target_files`). Moving from a build signed
with different keys requires a data wipe.

## Layout

```
build-support/     pinned Evolution X manifest, platform patches (+ .base SHAs),
                   vendor config snapshot
compat/            compatibility shims for stock blobs (display HAL, libc++)
configs/           audio, camera, Wi-Fi and display configuration
overlay/ rro_a16/  framework, SystemUI and Settings overlays
sensors/multihal/  source-built multi-HAL for the Xiaomi sensor stack
sepolicy/          device SELinux policy
udfps/             in-display fingerprint handler
scripts/           build helpers (proprietary sync, patches, vendor fixups)
vintf/             VINTF manifests and compatibility matrix
config.fs          AIDs and file capabilities for vendor and odm
```

## Notes

- **File capabilities.** `config.fs` mirrors the stock vendor and odm
  `fs_config` entries. Without them `loc_launcher` cannot assign groups (so
  `xtra-daemon` has no network access) and the IMS, `cnd` and `pm-service`
  daemons lose `NET_BIND_SERVICE`.
- **libc++ shim.** Some stock `system_ext` blobs (QCC, camera opt, WFD config)
  were built against the Android 17 libc++, which exports
  `std::__hash_memory`. `compat/hash-memory` provides it for Android 16.
- **Camera.** The stock camx stack expects the stock camera provider NDK
  libraries and `ro.product.mod_device=xuanyuan_global` for MIUI Camera.

## Credits

- [LineageOS](https://github.com/LineageOS)
- [Evolution X](https://github.com/Evolution-X)
- [xiaomi-8750](https://github.com/xiaomi-8750) for `android_hardware_xiaomi`

## License

The code in this repository is licensed under Apache-2.0. Xiaomi binaries under
`prebuilts/`, `rootdir/` and `neoteric_compat/` are proprietary and are not part
of this repository.
