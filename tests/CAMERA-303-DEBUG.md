# Stock 303 camera investigation (2026-10-09)

## Settings blob mismatch found

The tree/device com.qti.settings.sm8750.so was a different build:
SHA-256 8fed28dfa48360f23624c51b6a71ddc44334fcb01fe8c20fb9d06195ed1a06fb.
Its .text differs in content AND size from stock303, so this is not only
an ELF dependency rewrite. Other checked core camera blobs matched 303.

Restored this one library from the user's stock303 dump to device and tree:
SHA-256 07020fcbcc1807d4e6c12ed8bd8d60649c215bd7d24ecda158884f3c8dcd386b.
Pinned SHA-1 in proprietary-files.txt. Original mismatched library is backed
up in the Windows task workspace as com.qti.settings.sm8750.pre303-restore.so.

Initial preview appeared after restoration with the earlier runtime guard active.
The user reported a front/rear UI versus sensor mismatch at that point.
Follow-up verification on a later boot, provider PID 1996 (TracerPid 0), confirmed
rear preview with the rear zoom controls, front preview with the front-camera
controls, and switching back to rear. A test JPEG was saved as
/sdcard/DCIM/Camera/IMG_20261009_213409.jpg (114703 bytes).
No camera runtime guard was added to the ROM tree. This verifies basic preview,
front/rear switching and photo storage; auxiliary lenses, video and HDR modes
have not been comprehensively tested. No full ROM build/flash was performed.

The feature2=0 diagnostic did not resolve the graph failure and was removed
from the device; camxoverridesettings.txt matches stock303 again.

The reference repository remains untouched. The single mismatched settings blob
was restored from the user's stock303 dump as recorded above.

## Reproduced initialization failure

`com.qti.chi.override.so+0x559170` initializes framework stream buffer management.
The first preview stream has max_buffers=8, but YUV stream index 1 has
max_buffers=0 (1440x1080, format 0x23, usage 3, dataspace 0x08c20000).
At +0x5595b8 the selected buffer count is zero; the function returns 1.
`InitializeOverrideSession` stores this result at +0x4861e0 and leaves
override state=0 at +0x48551c. Camera HAL rejects the first request with -19.

## Runtime experiment and remaining failure

Immediately before +0x559194, replacing only zero max_buffers values with 8
on streams 1, 2 and 3 makes the buffer initialization return 0 and the
override output state become 1. This reproduces consistently.

The same session reaches camera.qcom.so+0x624338 with state=1. However,
the capture path still returns w22=1 at +0x626304. Its final indirect call
at +0x6262b0, whose result is stored at +0x6262b8, needs investigation.
The framework reports the remaining failure as -38; the vendor adapter
reports -19. Preview is NOT fixed.

Do not enable the max_buffers experiment as a production fix yet. An earlier
experiment at camera.qcom.so+0x6213e4 also failed: CHi modifies the stream
descriptors afterward. Forcing capture session state to 1 is invalid and
previously crashed on an uninitialized session member at +0xbe8.

After testing, restart the provider and cameraserver to remove ptrace
breakpoints and temporary data edits, then apply only the pre-existing guard.

## Capture failure localized (2026-10-09 follow-up)

The indirect call at camera.qcom+0x6262b0 targets CHi+0x44a230,
the OverrideProcessRequest wrapper. The failure propagates through CHi
+0x498410 -> +0x57eb30 -> +0x66ccc0 -> +0x31e9a0.
Acquire-fence waits and request metadata allocation return success.

Enabling CHi diagnostic logging revealed graph selection failure:
`SearchFeatureGraphinTable(): Not match customVendorTag:120`, then
`No feature graph to process request`. The OEM selector in
com.qti.feature2.gs.sm8750.so sets tag 120 at +0x100760.
A runtime-only test replacing this preview tag with zero still fails.
It reaches RTPostprocess/RealtimeFG candidates, but the registered graph
lookup does not match. That experiment was removed; do not ship it.

Configuration logs show only 1/4 framework streams mapped, with only
RTPostprocess inserted (cameraID 0, flags 0). Request-time lookup uses
flags 40. Investigate graph construction before adding buffer or tag fixes.
The `opsMode 0x82` log is inside a vector iteration, not sufficient evidence
that the actual framework operation_mode changed (other logs report 0).

Additional upstream inconsistency: IsAllSensorExist reports expected 5,
m_numPhysicalCameras 8. BuildCameraIdSet lists IDs 0..11 as type 0 with
one physical camera each. This does not establish physical sensor damage:
probe_messages.json records successful probes for the five actual sensors
(LYT900, OV32B40, IMX858, S5KHP9, S5KJN5). Enumeration/logical-camera
construction needs investigation. Do not change the count blindly.

Device SHA-256 matches stock303 for camera.qcom.so,
com.qti.chi.override.so and com.qti.feature2.gs.sm8750.so.
No production camera fix has been validated by these experiments.
