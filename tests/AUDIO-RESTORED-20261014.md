# Audio fix verified 2026-10-14
User confirms audio returned with revised vendor_audio_interfaces.xml bind mounted on /vendor and vendor.audio-hal-aidl/audioserver restarted.
Keep va_aosp.support=1 to preserve camera topology.
Source: device/xiaomi/xuanyuan/configs/audio/vendor_audio_interfaces.xml; copy rules in device.mk target vendor and odm SKU paths.
Both staged output XMLs match source SHA256 f0a435bf...
Live bind mount is temporary. vendor.img from Oct 7 is stale; rebuild and verify before flashing. No reboot or flash was performed.
