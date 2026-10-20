# Wi-Fi boot restore (2026-10-10)

## Reproduction and root cause

With persisted `wifi_on=1`, boot at 13:10 failed at 13:10:27.771:
`wificond: Can't get wlan0 index: No such device`, followed by
`CMD_STA_START_FAILURE`. The framework remained disabled despite preserving
the on preference. CNSS calibration finished later, at 13:10:29.550.

The stock Wi-Fi HAL was wrongly classified as a non-installable source
duplicate by extract-files.py. The AOSP service was also non-installable.
Neither the HAL executable nor its init/VINTF declarations was installed.
Without a vendor HAL the framework used its unmanaged-interface fallback,
which raced CNSS initialization. Do not work around this by forcing Wi-Fi on
at boot or rewriting the user's preference.

## Fix

- Remove android.hardware.wifi-service_vendor from non_installable_modules.
- Select that stock prebuilt in device.mk; install its init and VINTF v2 config.
- Restore and SHA1-pin stock303 HAL and libwifi-system-iface; select the stock
  vendor library through the generated HAL shared_libs dependency.
- Preserve the AOSP service's existing non-installable status to avoid duplicates.
- No reference-repository files or commits were used.

HAL SHA256: 5176539b2d475c1113ade5c8604321876bb1a672f6b26d625ad2550aac98d3b7.

## Verification

The PowerShell runtime regression test failed before the fix:
`expected=enabled actual=Wi-Fi is disabled persisted=1`.
After installing the same 303 artifacts on the device and rebooting, it passed:
`PASS: Wi-Fi is enabled persisted=1`. vendor.wifi_hal_legacy is running;
HAL/wificond/supplicant interface-setup failure counters are all zero.
No manual Wi-Fi enable command was issued between those boots.

Run from a Windows ADB host: `./wifi-boot-state-test.ps1`.
This is runtime/reboot verification, not a full ROM build.
Off-state reboot, hotspot and Wi-Fi Aware were not tested.
APF, RSSI monitoring and country-code HAL warnings remain outside this fix.
