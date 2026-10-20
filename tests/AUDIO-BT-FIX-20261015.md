# Bluetooth audio — user-confirmed live fix, 2026-10-15

User confirmed Bluetooth sound works after the reversible 303 V4 + software
A2DP trial and again after an authorized reboot. Disconnect/speaker volume
regression checks remain pending. No image was flashed.

## Required combination

- init.qcom.rc keeps persist.bluetooth.a2dp_offload.disabled=true.
- configs/audio/audio_policy_configuration.xml places all three A2DP sinks in
  the registered bluetooth software module, not primary/PAL.
- a2dp output mixPort has no static profile: AudioPolicy queries HAL for PCM.
  LDAC negotiates PCM32 / 96000; a PCM16-only mixPort causes config-change
  failure and disconnection. Device baseline rate lists must be space-delimited.
- device.mk selects android.hardware.bluetooth.audio-impl_vendor and
  libbluetooth_audio_session_aidl_vendor. Their proprietary files are stock303
  V4 implementations, NOT source-built V5 replacements.
- extract-files.py no longer marks these two modules non-installable or removes
  them from generated product packages. Corresponding generated Android.bp
  modules are enabled. Other duplicate-module decisions are unchanged.

The XML-only trial with V5 replacements crashed in the V4 ProviderFactory Binder
handler at pc 0x3f268 (tagged-union cleanup). Restoring the original 303 pair
removed V5 from the HAL maps and stopped the crash. All-zero PCM then reached
device type 8 (A2DP), playback frames advanced, and user confirmed actual audio.

303 file SHA-256, verified against the live successful trial:

- android.hardware.bluetooth.audio-impl.so:
  229b1b0edea13b79c5d0e9faa7422107dec86609af71e4dd2c34b5daa29e1522
- libbluetooth_audio_session_aidl.so:
  afe2cc1c35bcffaf9831c83d57e10ca7fae7fbabf35252c9f8b735ff8f6b516c
- ODM policy:
  cd7aea94fd030fd933713d7a0a319572b473be1ebb015f1d0b00a86fbe472528

The tree proprietary copies already had stock303 code and were not replaced.
No reference-repository files copied. NFC APEX, Wi-Fi and speaker interface XML
left unchanged; NFC mState=on checked after the trial.

## Verification and rollback

Host regression guards at C:/ChatGPT-PC-Control:
test_audio_sw_a2dp_20261015.py (3 policy tests, passing against tree),
test_bt_303_abi_20261015.py (stock code/V4 ABI guard, passing against tree).
Policy tests also check speaker, SCO, inputs and other modules against backup.
test_ldac_pcm_policy_20261015.py checks negotiated LDAC PCM acceptance and rate
list parsing. All 6 tests passed against the final tree policy/303 libraries.
User confirmed "LDACで接続・再生できた". Runtime output profile is PCM32/96000,
and the all-zero routed playback probe advanced frames on A2DP.

Live backup: C:/ChatGPT-PC-Control/bt303-v4-backup-20261015.
trial_bt_303_v4_20261015.ps1 -Mode Restore restores the previous three files.
Do not restore unless intentionally undoing this fix.

Full ROM build not run: WSL VHD host drive has critically low free space.
Device reconnected for the LDAC investigation and live recheck. Reboot
persistence is verified below. Existing unrelated mifaced linker failures are
outside this Bluetooth fix.

## Persistent live storage checked

Following user's permanent-application request, verified both mounted files and
the persistent scratch overlay upper files match the successful hashes:

- /mnt/scratch/overlay/odm/upper/etc/audio_policy_configuration.xml
- /mnt/scratch/overlay/vendor/upper/lib64/android.hardware.bluetooth.audio-impl.so
- /mnt/scratch/overlay/vendor/upper/lib64/libbluetooth_audio_session_aidl.so
- /mnt/scratch/overlay/vendor/upper/etc/init/hw/init.qcom.rc

The init RC hash is b46432dba74e08f74df6e6bbeb2f5c8f40fadb04549114b8d3e8035a72536f6b;
line 179 disables A2DP offload, also set in tree vendor.prop. No file-specific
temporary bind mount is used for these paths. vendor/odm overlays are read-only
after installation; sync completed. Existing xu_audio_engine_fix module has only
the volume-engine library and module metadata, no boot script/property that
overrides these changes; left untouched. NFC remains on.

This persists across normal boots using the current scratch overlay, but a ROM
flash/OTA or overlay removal can discard live overrides. Source-tree integration
is in place for the next image build, which remains unbuilt due to low host disk
space.

## Authorized reboot verification — passed

On 2026-10-15, reboot completed (sys.boot_completed=1). All four deployed file
hashes above survived unchanged. persist.bluetooth.a2dp_offload.disabled=true;
Bluetooth reports A2dpOffloadEnabled=false. Audio HAL PID 1905 stayed stable and
audioserver runs. Earphones automatically reconnected using LDAC 96000 Hz/32bit;
AudioFlinger shows an active A2DP output at PCM32/96000. NFC remains on; Wi-Fi
remained enabled and automatically reconnected. User then confirmed "問題ない".

Normal-reboot persistence and actual post-reboot audio are user-confirmed.
Flash/OTA survival and a newly built ROM image remain unverified.
