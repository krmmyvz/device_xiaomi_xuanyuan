# Capture/save investigation, 2026-10-09

**Later resolution:** processed SDR JPEG capture now works, including after
reboot. See CAMERA-JPEG-SDR-FIX.md for the validated combination and limitations.
The historical failed experiments below are not the current shipping fix.
SDR HEIF was subsequently restored; see CAMERA-HEIF-QUALITY-FIX.md.

Earlier photo-storage verification only established that a JPEG existed, not
that the full-resolution capture completed. Actual files measured 1590x1080
and 1440x1080, roughly 115KB/185KB.

Fresh capture IMG_20261009_215204 reproduced PreviewSaveRequest, preview=true,
fullImageReceived=0 and capture timeout. This is a placeholder preview image
that is never replaced by the full capture; do not count it as photo success.

Another build mismatch was found in Camera itself:

- Installed/preloaded: 6.4.000450.1, versionCode 640004501, target SDK 36.
- User stock303 dump: 6.4.000430.0, versionCode 640004300, target SDK 35.

Tree MiuiCamera.apk now matches the stock303 dump (SHA-256
74b45af146e809c807497aa62a599a5955fc27e89244c934ccd7c8b7400de2e6).
This alignment is NOT validated as a capture fix. The stock303 APK was tested
by replacing the system APK and rebooting. It failed during stream
configuration: CameraManager::getCameraDevice() raised map::at for physical
camera ID 252706817 (0x0f100001). A read-only runtime trace confirmed the key.
The device APK was subsequently restored to 6.4.000450.1; on 2026-10-10 both
the system APK and PackageManager reported that version. The tree still holds
the stock303 APK above; do not treat that unvalidated tree change as a fix.
Current preloaded APK is backed up in the Windows task workspace as
MiuiCamera.pre303-app-restore.apk; a different tree APK, if any, is separately
saved as MiuiCamera.tree-before303.apk. Do not clear Camera user data.

Sound recurrence was caused by the reboot resetting the running property to 1.
The tree already had 0 but that ROM was not installed. Live /system/build.prop
was corrected to ro.vendor.qti.va_aosp.support=0, retaining a host-side original
as sound-system-build.before-0.prop. The overlay was returned to read-only.
Running property is 0; audio service selects the ODM sku_sun interface list and
QTI registers IModule/default last. Persistence was verified after reboot,
with a successful PAL deep-buffer start (see AUDIO-303-FIX.md).

## Enumeration checkpoint, 2026-10-10

Framework exposes four devices: 0/1 report Back, 2/3 report Front. The legacy
adapter enumerates ordinal IDs while logical metadata includes encoded
physical IDs such as 252706817. Do not remap these blindly to ordinal 1:
that has not been proven to identify the correct sensor.

ro.vendor.qti.va_aosp.support=0 also makes the vendor framework detector
report a non-enhanced framework. Any camera effect remains an untested
hypothesis, not a reason to change this global property. A test must preserve
the audio registration ordering for the selected SKU and verify regressions.

## Camera-role cause confirmed, 2026-10-10

A reversible property test changed ro.vendor.qti.va_aosp.support from 0 to 1
and restarted only the camera services first. The exposed device count changed
from 4 to 10; ordinal ID 1 now reports Front instead of Back. CHi registered
front_main and back_ultra roles correctly. The user confirmed that both the
0.6x rear ultrawide and front-camera selection now show the correct sensors.

CHi GetDevicesSettings calls isRunningWithVendorEnhancedFramework and selects
pakala_gsi.xml when vendor-enhanced framework detection is disabled. Thus the
global property used for the earlier audio workaround changes camera topology.
Keep this property at 1; fix audio registration ordering in the XML actually
selected with that value: /vendor/etc/audio/vendor_audio_interfaces.xml.

Tree system.prop and live /system/build.prop now use 1. Device makefiles supply
the reordered compatibility XML at the vendor path as well as the earlier ODM
SKU path, replacing the extracted vendor XML copy rule (no shared-library
replacement). The restarted audio HAL logged default registration before QTI.
AudioFlinger has an active output with increasing written frames, but audible
playback confirmation and persistence across a further reboot remain pending.
Primary output handle was 0 after restart; do not claim full audio validation.

Full-resolution capture/save latency still requires a separate retest. No
runtime camera binary guard, reference-repository content, or new blob build
was used for this camera-role fix.

## Save retest after role correction, 2026-10-10 10:13

With va_aosp=1 and the restored camera topology, version 6.4.000450.1 still
failed to deliver a full-resolution image. IMG_20261010_101306 produced a
PreviewSaveRequest (1440x1080 input / 1590x1080 watermarked preview), with
fullImageReceived=0. Capture started at 10:13:06.423 and timed out at
10:13:18.411. The eventual DCIM file was only 115068 bytes. Thus fixing the
role mapping alone does not resolve the capture/save problem.

Next controlled comparison: test the stock303 Camera APK again with the
correct topology. The previous APK test used va_aosp=0 and failed on missing
encoded physical camera IDs; it does not establish failure with the corrected
topology. Stock APK staging hash is 74b45af146e809c807497aa62a599a5955fc27e89244c934ccd7c8b7400de2e6.
Current device APK hash equals the retained pre303-app-restore backup.
System APK replacement and reboot were subsequently authorized by the user.
No Camera data, photos, or capture queue databases have been cleared.

## Stock APK redeployed with corrected topology

Live /product/priv-app/MiuiCamera/MiuiCamera.apk now has the stock303 hash above.
The first reboot retained the cached 450 package metadata because the parent
directory mtime was older than the PackageCacher entry. PackageCacher compares
the package directory st_mtime against the cache st_mtime. Touching only
/product/priv-app/MiuiCamera and rebooting invalidated that stale metadata
without deleting app data or package caches. PackageManager now reports
versionCode=640004300, versionName=6.4.000430.0, targetSdk=35.

va_aosp=1 persisted and the framework still exposes 10 cameras. The device is
RUNNING_LOCKED after reboot; user PIN unlock is required before launching the
stock Camera activity and performing the capture comparison. No successful
full-resolution capture has yet been established with this deployment.

## Correct-topology stock APK test failed after user unlock

On 2026-10-10 10:22:44, stock303 Camera opened device 6 with va_aosp=1.
The provider crashed at libSNPE.so+0x68fc44 (write into a read-only libui.so
mapping). libSNPE.so SHA-256 c8b7bf64ac72119ea7bdf49712226334b693fd472a3fdfd9f164bfb27ea5eaf4
exactly matches the user's stock303 dump. Retained host tombstone:
camera303-stock-crash37.txt. This is not the previous missing-ID exception.

A second launch at 10:23:20 crashed at libmicamera_hal_core.so+0x3b21f4,
VendorCameraSession::requestStreamBuffers+2732. The instruction dereferences
a shared-pointer control object's vtable; x19 points to memory containing
ffffffffffffffff as its first word. Call chain: AdapterDeviceSession ->
CamX HALDevice::RequestStreamBuffers -> CHXStreamBufferManager working thread.
Retained host tombstone: camera303-stock-crash38.txt. This does not establish
which earlier operation corrupted/freed the object. Do not patch out release
operations or assume the fault itself is the origin of the bad pointer.

The stock APK cannot currently complete even preview initialization reliably.
It remains deployed, and Camera was force-stopped after collecting evidence.
No new HAL runtime patch or crashing binary workaround was promoted to tree.
Investigate the camera compatibility boundary before further APK-only trials.

## Camera-only library / pipeline investigation, 2026-10-10 11:00–11:22

A diagnostic launcher loaded the user's stock303 libui.so only for the camera
process via LD_LIBRARY_PATH=/odm/lib64/camera303-compat. Multiple stock430 Camera
launches reached preview and capture without the earlier SNPE/shared-pointer
initialization crashes. This is provisional evidence, NOT a validated complete
camera fix. The launcher is not installed in the ROM tree. Initial launcher
tests lost service capabilities across exec; the later launcher sets ambient
capabilities and verifies CapEff=0000001000804008, matching init. Do not equate
the initial credential-mismatched tests with normal service behavior.

Adding private stock303 libc++ did not fix capture and was withdrawn from the
search directory (retained as libc++.so.not-loaded). Do not replace the global
vendor C++ runtime. Normal init camera service is running again; no private
library environment was added to its init RC.

New concrete defect: SatSnapshot_AllinOneInstance0 could not be initialized,
because com.xiaomi.plugin.mialgoallinone was missing. The stock303 dynamic plugin
exists in the user's dump but was absent from both device and proprietary list.
Restored it unchanged to the device and vendor tree, added its shared-library
module/package, and pinned SHA-1 e388f3059e378d528da76c9691b006bff1a92365.
SHA-256 02d612ef221b922fb4dae868f7d24152018e8198e704ba17a29c344b1d6d82eb.
The missing-plugin/init-node error disappeared, but capture still fails.

Remaining capture failures:
- Default logging: getOutputLinks cannot find SatSnapshot_HeifEditInstance,
  aborts, and leaves a preview-sized JPEG.
- Verbose diagnostic capture: GainmapAnchor receives RAW10 (37), expects
  RAW16 (32), returns GetInputError; BGService sends onCaptureFailed within
  about 100ms. The stock graph contains the RAW16 expectation. Do not reinterpret
  packed RAW10 as RAW16 or skip the error as a production solution.

Changing the gainmap anchor edge to RAW10 did NOT fix capture and was reverted.
Enabling JpegPruneNeeded in mivisettings was consumed by the engine but did NOT
fix the missing-HeifEdit abort; it too was reverted. Both live JSON files again
match stock303 (satsnapshot SHA-256 57d08f68feaf75266dd189aabab972190a21e2aa62a3c2a91e4529c137b12cd3,
mivisettings 4b80914518e6b1b8015f8d3eb7f7e38b47c89a974d654b9c75b54731c9dda0e5).
Diagnostic mivi loglevel and pipelineprunerdump properties were restored to
empty, and logcat buffer size restored to 256K. Native/app diagnostic log files
camera303-compat-capture.log and camera303-compat-app.log are retained on host.

libcom.xiaomi.debug, metadatautils, signaltrigger, and libofflinedebugdata differ
in whole-file hash from stock but their .text sections match exactly; these are
dependency/ELF fixups, not evidence of wrong-generation code. Do not replace them
solely on file hash. ro.camera.disableHeicUltraHDR only gates framework-derived
HEIC UltraHDR tags; its involvement in OEM JPEG failure is not established.

No full-resolution saved JPEG or full ROM build has passed this investigation.
