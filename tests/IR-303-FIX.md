# Consumer IR integration (2026-10-15)

The stock 303 service binary and ODM consumerir.qcom library were installed,
but the product omitted the init RC, AIDL VINTF fragment and consumerir feature.
The connected device likewise had no vendor.ir-default init service or consumer_ir
framework service. /dev/ir_spi existed, owned by system:system, but had the generic
device SELinux label. The device was permissive during investigation.

device.mk now installs the matching AOSP RC and V1 manifest plus the standard
consumerir feature, without replacing either proprietary binary. Device policy
labels only /dev/ir_spi and grants the IR HAL read/write/ioctl access to it.

Stock 303 SHA-256 (tree and device matched):

- vendor/bin/hw/android.hardware.ir-service.example:
  2d0146e68f000cfdeb3a6474be8d6fbd976864ddcdb5abfbd04f313a57f59241
- odm/lib64/hw/consumerir.qcom.so:
  fc9e6f2c7770b0f5eb765af8e6eec17494ba7a081a47051606188bec17164f9a

Host installation checks: python3 device/xiaomi/xuanyuan/tests/test_ir_install.py
(three missing-file failures before the change, all three passed afterward).

The three glue files were also installed into the existing live vendor overlay;
their modes/labels were checked and /vendor was returned to read-only. Existing
NFC/Wi-Fi/audio files and both 303 IR binaries were not changed. The new SELinux
policy is tree-only until a ROM/policy build; live investigation was permissive.

After the approved reboot, sys.boot_completed=1 and vendor.ir-default=running.
The service ran as system in u:r:hal_ir_default:s0. The framework registered
consumer_ir and android.hardware.consumerir. hasIrEmitter returned true;
getCarrierFrequencies returned six frequency pairs: 30000, 33000, 36000, 38000,
40000 and 56000 Hz. Both proprietary hashes remained unchanged. No physical
transmission was performed by these read-only queries.

The user confirmed actual appliance control after reboot (2026-10-15).
Pending: full policy/build validation for the new EvoX build.

The first EvoX attempt passed Soong analysis but Kati rejected VINTF metadata
in PRODUCT_COPY_FILES (21:07 JST). The build declaration now uses
DEVICE_MANIFEST_FILE in BoardConfig.mk, merging the same AIDL HAL into the
vendor manifest. RC and feature installation are unchanged. The live overlay
was not changed. Revisit that temporary fragment when an actual ROM flash is
authorized; do not add a duplicate IR declaration to a flashed aggregate.
Do not call physical IR transmission verified until an appliance responds.
