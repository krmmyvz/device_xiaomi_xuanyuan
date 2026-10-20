# GApps / Magisk investigation, 2026-10-10

## NikGapps: build-tree repair, not yet deployed

Package inspected on host:
`G:\Storage\Downloads\NikGapps-stock-arm64-16-20260222-signed (1).zip`
(983806625 bytes).
Its installer requires writable installation targets. Current product and
system_ext images are EROFS; normal-OS adb overlay mounts do not turn those
underlying images into writable recovery installation targets.

BoardConfig now selects ext4 for product/system_ext, with 2250000000 bytes
reserved in product. system/vendor/odm and all stock303 camera/audio blobs
are unchanged by this repair.

The existing repack_vendor_boot_fstab.sh was run on the local prebuilt.
It verifies that stock platform ramdisk00, DTB and bootconfig are preserved,
and adds platform ramdisk01 with the device-tree first-stage fstab.
New vendor_boot SHA256:
`bdd08c0b18cef672c20f953d8415e23fc0f0d87237bad34bbcc3980bad949d0f`.
Pre-change backup is in the Windows task workspace:
`vendor_boot.before-gapps-fstab-20261010.img`.

test_gapps_sideload_layout.py now handles a single ramdisk or numbered
fragments, selecting the final override fragment. Both tests passed.
No new ROM build, device partition write or NikGapps installation was done.
Actual recovery installation still requires deploying the rebuilt images.
Recovery log saved as recovery-gapps-audit-20261010.log on host.

## Magisk: unresolved; no new flash attempted

Current active slot: b.
Downloaded magisk_patched-30700_ts6ry.img and active init_boot_b share SHA256
`d272084f0dd5a4b36d1e91222c037982bd1d18a51f91d06f8cd477bfd3c53e5e`.
Thus the requested image was written; this is not an ignored flash.
No Magisk daemon is running and /data/adb/magisk/magisk -v cannot connect.
Runtime mountinfo includes Magisk first-stage tmpfs at /data and a rootfs
/sdcard bind at /system/bin/init, but no working final Magisk environment.
Normal boot kernel log confirms switch-root at 1.015s and second-stage init
at 1.219s. Those facts do not establish why Magisk failed to initialize.

There are historical alternative patches/debug images on the device; do not
blindly flash them or count their mere existence as verified working fixes.
Early second-stage/hook diagnostics remain necessary. Device returned from
recovery to normal Android. No user data or existing modules were removed.

## Follow-up: OverlayFS hid the second-stage hijack

With permission, the active init_boot_b was backed up on device and host as
init_boot.before-magisk-diagnostic-20261010.img. A diagnostic image replaced
only init with official v30.7 debug magiskinit. Official app-debug.apk digest
matched the GitHub release asset SHA256
40729525e298a11dad6e13586a29efa48a48e97cbf00203798e8047d1c710cb2.
All other 31 ramdisk entries were verified unchanged.
Diagnostic image SHA256: 10f5ebd0f53e1d85c8c5defa8db2b3e3e129d989060885dcb049162361c5f33d.
It was written to init_boot_b, read-back hash verified, and booted normally.

Inside a private, newly unshared mount namespace, the hidden early /data
tmpfs contains the official debug magiskinit hash
8e26e33c3db284823f5d083588df26781d032ecd9818b8a116490d2f488f75dd.
Removing only the /system overlay in another private namespace changes the
visible /system/bin/init from the AOSP init hash ff6f1efbb3affef8bf6071c6ef10361ee16e44d220b47eb2004b2e32a39fe5dc
to that debug magiskinit hash. The live OS's mounts were not changed.
Thus the adb OverlayFS covers Magisk's bind-mounted second-stage init.

A stable v30.7 compatibility candidate is prepared, NOT YET flashed:
init_boot.magisk307-overlayfs-compat-20261010.img, SHA256
1f708e83b5c75d1e62a2acf79212af4fcdfd835a12cf9a7f8fa4af2958805c13.
It adds only an empty sdcard entry to the original pre-diagnostic ramdisk;
all 32 existing entries and stable init are preserved. This selects
Magisk's existing hexpatch fallback to /data/magiskinit and avoids the
OverlayFS-covered /system/bin/init bind. Runtime verification and separate
write/reboot approval are pending. Do not claim Magisk is fixed yet.

### Compatibility boot attempt

With the user's separate permission, the compatibility candidate was written
to init_boot_b and read-back SHA256 matched 1f708e83b5c75d1e62a2acf79212af4fcdfd835a12cf9a7f8fa4af2958805c13.
After reboot neither ADB nor fastboot enumerated during the observation
window. Runtime verification failed; this image is NOT a verified fix and
must not be promoted into ROM prebuilts. Restore the original backup
(d272084f0dd5a4b36d1e91222c037982bd1d18a51f91d06f8cd477bfd3c53e5e)
when recovery/fastboot connectivity is available. User assistance is needed
to reach recovery or fastboot. No additional partition writes were issued.

### Failed boot and completed rollback

The user confirmed a splash-screen bootloop with the compatibility candidate.
After the user entered fastboot, serial 369cd024 and current-slot b were
verified. Only init_boot_b was restored with the pre-diagnostic backup;
fastboot reported successful send/write and reboot. Android returned to ADB,
sys.boot_completed=1, slot=_b. Read-back init_boot_b SHA256 is
d272084f0dd5a4b36d1e91222c037982bd1d18a51f91d06f8cd477bfd3c53e5e,
matching the original backup. Wi-Fi boot-state regression test passed.
No data wipe or other partition flash was performed. Magisk remains unresolved.
The marker compatibility image is a FAILED experiment, not an installable fix.
Do not add it to ROM prebuilts or recommend flashing it. The preserved pstore
log is magisk-compat-bootloop-ramoops-20261010.log in the Windows workspace.

### Remounter guard experiment: failed and fully rolled back

An already-permissive + Magisk-present EBUSY guard was added temporarily to
system/core/overlay_remounter/overlay_remounter.cpp. In private mount namespace
tests, the original remounter aborted (134), the modified exec-wrapped test
reached second stage with an init.rc bind hook preserved, and no-Magisk and
enforcing-shadow control tests both rejected the bypass (134). These tests
did NOT establish that the guard's prerequisites hold during actual boot.

With user permission, the modified helper
6adff7ba9f3d699171c168c2500f075698b064ee9cb957c1a38cc8ba07bb9338 and a fresh
debug+marker init_boot image
020144f42a03112a6035e7ab9818d2e85fe67f6e1983696d9111e31ea462f759 were
deployed. The user reported the same bootloop. Do NOT promote either artifact.

Fastboot serial/current-slot b were checked, original init_boot_b restored,
then the original /system/xbin/overlay_remounter restored after normal boot.
Verified read-back hashes:
- init_boot_b: d272084f0dd5a4b36d1e91222c037982bd1d18a51f91d06f8cd477bfd3c53e5e
- overlay_remounter: 17642457854533bf7d08263e6612b794076f910e44cf8490531fe426b3ec1bb6
sys.boot_completed=1 and Wi-Fi boot-state test passed. The guard was removed
from source; git diff for overlay_remounter.cpp is empty. No data wipe occurred.
Second failure log: magisk-overlayfix-debug-bootloop-ramoops-20261010.log.
Magisk remains UNRESOLVED. Further flash trials require redesign, not another
variation of the same marker/remounter bypass.
