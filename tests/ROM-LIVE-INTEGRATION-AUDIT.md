# Live-fix ownership audit — 2026-10-10

Read-only device snapshot: 49 active regular files, 2 excluded leftovers.
The complete per-file hashes are in ROM-LIVE-INTEGRATION-AUDIT.json; source
snapshots and diagnostic programs are retained in the Windows task workspace.

| Class | Evidence / owner | Integration action |
|---|---|---|
| 34 byte-identical files | Existing vendor proprietary files or device-owned camera/audio/Wi-Fi configs and MiuiCamera prebuilt | Retain current install owners; no blind recopy |
| system/lib64/libprocessgroup.so | Existing source changes in system/core/libprocessgroup | Source rebuild, not opaque live prebuilt |
| system/build.prop | Device system.prop, especially ro.vendor.qti.va_aosp.support=1 | Regenerate properties; retain verified camera topology setting |
| system/xbin/overlay_remounter | Original restored binary; source diff empty | Normal source rebuild; never include failed guard |
| product/overlay/xuanyuan_a16_SystemUIRes.apk | rro_a16/SystemUIRes, pixel_pitch=48.68 | Rebuild overlay from source |
| vendor/lib64/libudfpshandler.so | udfps/UdfpsHandler.cpp and V2 BoardConfig | Rebuild source with verified extCmd offset 0xf0 |
| odm/etc/init/zz-camera-provider-compat.rc | Original provider rc has identical interfaces/caps/task profiles and private LD_LIBRARY_PATH | Do not install duplicate override; patch normal provider's ELF dependency instead |
| odm/bin/hw/provider-service_64.compat | Same .text as normal provider; only added dependency is libcamera_heap_compat.so | Add dependency to normal provider and extraction/build rules |
| odm/lib64/libcamera_heap_compat.so | Currently mapped by provider; original camera_heap_compat.c is retained; constructor calls mallopt to disable provider heap-pointer tagging | Add source-built ODM module; preserve existing behavior, not a new global malloc policy |
| Five ODM graphics libraries | mapper.qti.so, libtinyxml2.so, snapalloc-impl.so, libgralloctypes.so, libmapperutils.so all exactly match the stock303 vendor dump SHA256 | Add camera-owned stock303 ODM copies; do not replace globally used vendor variants |
| Two ODM audio interface XMLs | Differences from device config are explanatory XML comments only | Use already-owned config, retaining default-before-QTI registration |
| audio_policy_configuration.xml.debug-disabled-* | Backup, not active policy owner | Exclude |
| camera303-compat/libc++.so.not-loaded | Disabled experiment outside loader search filename | Exclude; do not replace global libc++ |

The graphics copies are verified stock303 code, not reference-repository or
Neoteric imports. The live mapper/snapalloc/mapperutils differ in code from
the existing global vendor variants; those global variants may support
display bring-up, so their unrelated behavior is deliberately preserved.

Active gaps identified before changes: no heap constructor module, no heap
DT_NEEDED on normal provider, and no ODM packaging for five camera graphics
copies. Source/config and ELF install checks must cover those gaps before
the build. Remaining source-built outputs are checked again after compilation.

No failed Magisk boot image is selected by the device build. Magisk remains
unverified until a later explicitly approved, OverlayFS-free deployment.
