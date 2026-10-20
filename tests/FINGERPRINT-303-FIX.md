# QCOM ultrasonic fingerprint repair, 2026-10-09

Past debugging had already isolated a failed TA load for fp_qfs4008_r.
The current device reproduced that failure: libqc_hal.so was a different
build from the stock303 dump and requested a TA absent from the firmware.
Stock303 libqc_hal.so requests fingerpr_xuan, which is present. Restoring
that one library made the TA initialize, sensor open and HAL open succeed.
The stock fingerprint.qcom_us.so itself was already correct and was preserved.

Stock303 libqc_hal.so SHA-256:
1dfbf74a99c8004d35b7cc46eff0c9aeabdbad99d43885ca37138cac125c788e.
It is restored in the vendor tree and pinned by SHA-1 in proprietary-files.txt.
The former blob is backed up in the Windows task workspace as
libqc_hal.pre303-restore.so. Firmware/TEE files were not renamed or modified.

The shipped custom libudfpshandler.so used the legacy fingerprint_device
layout: extCmd at 0xd0. The QCOM module and prebuilt AIDL wrapper use V2,
where extCmd is at 0xf0. Under V2, the old 0xd0 slot is authenticate.
The mock HAL probe demonstrated six unintended authenticate calls and no
extension commands. BoardConfig now selects IMPL_VER=V2; the handler asserts
the correct offset to prevent a silent rebuild with the wrong layout.

After that correction, enrollment progressed to 40% but was cancelled.
Vendor acquired callback 202 caused the handler to send another pointer-up
back into the notifying QCOM HAL. Removed that callback-to-command feedback;
pointer-up is idempotent and cancellation releases any outstanding touch.
The mock probe went from 12 commands (failure) to the six intended commands
(pass) with acquired callback and duplicate pointer-up included.

Live verification after deploying the rebuilt source handler:

- User confirmed enrollment completed.
- Framework fingerprint dump reported count=2, accept=3, reject=0.
- HAL emitted three onAuthenticated callbacks.
- Final service PID 16836; manual restart history accounts for prior HAL deaths.

Live handler SHA-256:
8a6137adefbd4261864b87c31818106657e86dff3d55438a3024bea0556f86dd.
The old handler is saved as libudfpshandler.live.so in the Windows task folder.
The live library was compiled with NDK/platform libc++ bridging for this test;
the ROM uses the normal Soong build from udfps/UdfpsHandler.cpp and BoardConfig.
No full ROM build or post-fingerprint-fix reboot was performed.
No PIN, biometric template, or enrollment database was extracted or cleared.
The reference repository was not copied, cherry-picked or substituted.

## AOD and lockscreen icon

SystemUI's pixel_pitch resource was unset (-1). UdfpsOverlayInteractor divides
the 6000-micron icon width by that value, producing an invalid negative size.
The native panel reports approximately 521.77 dpi; 25400/521.77 = 48.68 microns
per pixel. Added pixel_pitch=48.68 to both the A16 SystemUI RRO and the legacy
SystemUI overlay dimensions. The resulting icon width is approximately 123 px.

The matching signed static RRO was rebuilt and deployed live. The idmap was
regenerated and SystemUI restarted. AOD at fullyDozed=true displayed the
fingerprint icon; the user confirmed the AOD/lockscreen icon issue was fixed.
These overlay changes are in the tree, not just the runtime cache.
