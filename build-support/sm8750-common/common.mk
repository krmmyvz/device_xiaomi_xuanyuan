#
# Xiaomi SM8750 common product configuration
#
# Derived from the working DADA lineage-23.2 layout, with Ultra-specific
# vendor blobs and service instance names kept in device/xiaomi/xuanyuan.
#

SM8750_COMMON_PATH := device/xiaomi/sm8750-common

# Qualcomm common RFS/linker layout.
$(call inherit-product, hardware/qcom-caf/common/common.mk)

# The integrated MPSS firmware lives on the modem_firmware mount on sun.
$(call soong_config_set,rfs,mpss_firmware_symlink_target,modem_firmware)

# Physical firmware / VM mountpoints used by second-stage init.
PRODUCT_PACKAGES += \
    vendor_bt_firmware_mountpoint \
    vendor_dsp_mountpoint \
    vendor_firmware_mnt_mountpoint \
    vendor_modem_firmware_mountpoint \
    product_vm_system_mountpoint

# Audio remains xuanyuan-specific.
# DADA's common AudioPolicy / vendor-extension stack is not ABI-compatible
# with the Xiaomi 15 Ultra stock Bluetooth Audio HAL and causes
# audiohalservice.qti + com.android.bluetooth to abort.

# Common biometric AIDL runtime.  The physical fingerprint wrapper/HAL
# remains xuanyuan-specific because 15 Ultra uses the QCOM ultrasonic path.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.common.config.vendor \
    android.hardware.biometrics.common.thread.vendor \
    android.hardware.biometrics.common.util.vendor \
    android.hardware.biometrics.common-V4-ndk.vendor \
    android.hardware.biometrics.fingerprint-V4-ndk.vendor \
    android.hardware.biometrics.fingerprint-V5-ndk.vendor

# Product/system telephony framework shared by the SM8750 Xiaomi stack.
# Keep xuanyuan's stock normal QTI jars as direct copies in device.mk;
# these installable modules are the variants already verified by this tree.
PRODUCT_PACKAGES += \
    extphonelib \
    extphonelib-product \
    extphonelib.xml \
    extphonelib_product.xml \
    ims-ext-common \
    ims_ext_common.xml \
    qti-telephony-hidl-wrapper-prd \
    qti_telephony_hidl_wrapper_prd.xml \
    qti-telephony-utils-prd \
    qti_telephony_utils_prd.xml \
    telephony-ext \
    xiaomi-telephony-stub

PRODUCT_BOOT_JARS += \
    telephony-ext \
    xiaomi-telephony-stub
