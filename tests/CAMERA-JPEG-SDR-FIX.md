# Processed SDR JPEG capture, 2026-10-10

Superseded for format support: CAMERA-HEIF-QUALITY-FIX.md records the later
SDR JPEG/HEIF graph. This document retains the initial JPEG-only validation.

The user approved temporarily dropping UltraHDR/HEIF output in order to restore
normal processed JPEG capture. This does not establish full HDR/HEIF support.

Validated combination:

- Stock303 Camera 6.4.000430.0 and stock303 camera/algorithm binaries.
- Missing stock303 mialgoallinone dynamic plugin restored (see capture journal).
- Stock303 libui.so loaded only for the camera provider from
  /odm/lib64/camera303-compat, not substituted globally. SHA-256:
  bc026eba57d19a4300951daea9e3842acd4e9695a6765f8ba70f3f141d77009d.
- persist.vendor.camera.ultrahdr.enable=0. The graph change alone did not
  complete capture; the property alone still hit the original HeifEdit abort.
- configs/camera/satsnapshot-jpeg-only.json retains image processing and the
  offline JPEG encoder, removes HEIF/gainmap/JPEG-R auxiliary branches, and
  connects JpegInstanceFinal to the original image sink. RAW data is not
  relabeled or reinterpreted. No camera binary instructions are patched.

Host graph checks reject the original extended graph and accept the derived
graph (33 nodes, 40 links), with no dangling nodes and a Source -> MFNR -> JPEG
-> Sink path. Regeneration/check tool: scripts/camera-jpeg-graph.mjs.
The stock source JSON is retained in the vendor source/stock dump and in the
host backup; device.mk supplies the explicit compatibility config instead of
the original generated vendor copy rule. extract-files.py preserves the
camera-only LD_LIBRARY_PATH when extracting the stock init RC again.

Runtime evidence before reboot:

| Image | File size | Result |
| --- | ---: | --- |
| IMG_20261010_113137.jpg | 2286637 bytes | 3072x4550, fullImageReceived=1, preview=false |
| IMG_20261010_113233.jpg | 2350018 bytes | Capture 11:32:33.268, save 11:32:33.898 (0.63s) |
| IMG_20261010_113542.jpg | 2123599 bytes | Completed full image, preview=false |

The extra dimension includes the active Leica frame/watermark; these are not
the prior 1440x1080 preview placeholders.

After the user-authorized reboot, normal init service PID 1991 loaded the
private libui, va_aosp=1 and ultrahdr.enable=0 persisted. A fresh capture
IMG_20261010_113657.jpg was 2086703 bytes, 3072x4550, fullImageReceived=1,
preview=false, CAPTURE-END at 11:36:57.923. Thus the live correction works
without the diagnostic launcher after reboot.

Tree reflection includes the private libui prebuilt/package, camera init RC
fixup, SDR graph/copy rule, UltraHDR property, and missing plugin/module.
The previously live-only stock303 libmicamera_hal_policy restore is also now
reflected in vendor source and pinned (SHA-1 6983f90a26eba1d948ae13b78eea841cf69c73d9).
The older tree binary was retained as a host backup before replacing it.
Graph validation, extract-files.py syntax compilation, and git diff --check
passed. A full ROM build or flash was not performed; Soong integration is not
yet confirmed by a build. Telephoto/video and HDR/HEIF remain unvalidated.
The reference repository was not copied, cherry-picked or replaced.

Post-reboot front-camera check: framework connected device 1 at 11:38:16,
then IMG_20261010_113830.jpg was saved at 4602138 bytes, 4896x6528. The normal init
provider remained PID 1991 throughout, with no diagnostic launcher involved.
