# Stock 303 sound fix, 2026-10-09

The original service registration order was QTI core followed by AOSP default.
With the xuanyuan top-level primary policy, both registered IModule/default;
the AOSP module replaced the PAL-backed QTI output. Ringtone playback used
AHAL_StreamPrimary/alsa_device_proxy instead of the speaker DSP path.

The device-specific interface list registers AOSP before QTI. USB and remote
submix remain registered by AOSP; QTI owns IModule/default. Install the list at
odm/etc/audio/sku_sun/vendor_audio_interfaces.xml and select the device SKU with
ro.vendor.qti.va_aosp.support=0.

Validated live with the stock Andromeda.ogg ringtone in Twelve:

- Audio service selected the ODM sku_sun interface list.
- QTI registered IModule/default last.
- PAL_STREAM_DEEP_BUFFER and speaker-protection PCM started with status 0.
- AudioFlinger recorded increasing written-frame counts.
- User confirmed the ringtone was audible from the speaker.

Removing the primary policy alone is insufficient: playback then has no output.
Using the unmodified SKU policy instead also waits for an unregistered
IModule/bluetooth_qti. Retain the existing xuanyuan top-level policy.

Stock303 shared libraries and the reference repository were not changed.
The first live property-only change was lost at reboot because the installed
ROM still had value 1. Live /system/build.prop was subsequently corrected to 0,
with a backup retained in the Windows task workspace. After the authorized
reboot, value 0 persisted and PAL media playback was exercised again.
The tree's system.prop and SKU interface-order changes are both present.
No full ROM build was performed.
Bluetooth, USB and calls were not exercised in this verification.

## Superseding camera compatibility correction, 2026-10-10

The global va_aosp=0 workaround also selects a generic camera topology,
swapping the expected front/ultrawide roles. Runtime va_aosp=1 restored correct
roles and the user confirmed both cameras. Keep va_aosp=1 in system.prop.
The audio HAL then selects /vendor/etc/audio/vendor_audio_interfaces.xml;
install the same default-before-QTI compatibility list there, not only at the
ODM SKU path. The extracted XML copy rule is removed in favor of device.mk.
No stock303 audio shared libraries were modified.

Live HAL restart confirmed the reordered registration. AudioFlinger recorded
an active output and written frames, but primary output handle was 0 and an
audible playback check is pending. Do not count this as a new sound success
until the user confirms playback. Further reboot validation is also pending.
