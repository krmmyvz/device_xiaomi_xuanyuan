# xuanyuan live-fix integration specification

Integrate the verified camera, sound, fingerprint and Wi-Fi live fixes into
the existing ROM checkout, then build an installable ROM which does not need
adb scratch OverlayFS to supply those fixes. This is preparation, not device
deployment and not a claim that Magisk is fixed.

- Work in /home/user/rom/xuanyuan and preserve existing changes.
- 303 blobを維持する。
- 参照repo xiaomi-8750/android_device_xiaomi_xuanyuan は参考専用で、絶対にコピー・cherry-pick・置換しない。
- Do not package failed Magisk marker/debug images or the reverted remounter guard.
- Classify live leftovers before using them; a live file is not automatically a verified fix.
- Preserve the user's current bootable device, data, installed apps and modules.
- No device flash, reboot, scratch deletion or automatic Magisk installation in this phase.
- Retain ext4 product/system_ext and the verified vendor_boot fstab for GApps.
- Keep /system's normal Android build configuration; do not globally disable
  OverlayFS or weaken SELinux to make Magisk appear to work.
- Before later deployment, separately approve backup/deactivation of stale adb
  scratch overlays. Flashing a new ROM alone does not guarantee they disappear.
- Minimize Codex usage: targeted inspection, existing tests, a -j2 build, no repeated
  unchanged log polling. Do not commit unrelated dirty files.
