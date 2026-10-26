#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/xuanyuan

# Stock QCOM ultrasonic HAL uses fingerprint_device V2, including extCmd at
# offset 0xf0. Keep the source UDFPS handler consistent with the AIDL wrapper.
SOONG_CONFIG_NAMESPACES += XIAOMI_BIOMETRICS_FINGERPRINT
SOONG_CONFIG_XIAOMI_BIOMETRICS_FINGERPRINT += IMPL_VER
SOONG_CONFIG_XIAOMI_BIOMETRICS_FINGERPRINT_IMPL_VER := V2

# Stock audio blobs share install paths with AOSP vendor variants. The stock
# prebuilt rules are emitted last and must provide the vendor image copies.
BUILD_BROKEN_DUP_RULES := true
# libcamera2ndk_vendor.so stok blob'u PRODUCT_COPY_FILES ile kuruluyor (Android 16
# ELF kopyalamayi yasakliyor). Vendor agacinda ayni dosyayi kuran modul
# 'libcamera2ndk_vendor_vendor' installable:false oldugu icin kopyalama yolu korunuyor.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    odm \
    boot \
    vendor_boot \
    vbmeta_system \
    vendor_dlkm \
    dtbo \
    init_boot \
    system \
    recovery \
    product \
    system_ext \
    system_dlkm \
    vendor

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 := 
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := xuanyuan
TARGET_NO_BOOTLOADER := true

# Display
TARGET_SCREEN_DENSITY := 600
TARGET_USES_VULKAN := true

# Kernel
BOARD_BOOT_HEADER_VERSION := 4
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_CMDLINE :=
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)
BOARD_RAMDISK_USE_LZ4 := true
# Product is not mounted in recovery, so replace its dangling adb_keys link.
# Keep this development-host authorization restricted to debuggable builds.
ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
# recovery/adb_keys gelistirme makinesine ozel bir anahtardir; her agacta
# bulunmaz. Yalnizca dosya mevcutsa kopyalanir (yoksa build kirilmaz).
ifneq ($(wildcard $(DEVICE_PATH)/recovery/adb_keys),)
BOARD_RECOVERY_IMAGE_PREPARE += \
    rm -f $(TARGET_RECOVERY_ROOT_OUT)/adb_keys && \
    cp $(DEVICE_PATH)/recovery/adb_keys $(TARGET_RECOVERY_ROOT_OUT)/adb_keys && \
    chmod 0644 $(TARGET_RECOVERY_ROOT_OUT)/adb_keys
endif
endif
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_KERNEL_SEPARATED_DTBO := true
TARGET_KERNEL_CONFIG := generic_defconfig
TARGET_KERNEL_SOURCE := kernel/xiaomi/generic

# KERNEL_DIR: prebuilt kernel dosyalarinin bulundugu dizin.
# TARGET_KERNEL_SOURCE ayni dizini verir; yollar agac kokune gore relative'dir.
# (Tanimlanmazsa $(KERNEL_DIR)/kernel -> '/kernel' olur ve prebuilt adimlari patlar.)
KERNEL_DIR := $(TARGET_KERNEL_SOURCE)

# Kernel - prebuilt
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(KERNEL_DIR)/kernel
TARGET_PREBUILT_KERNEL_HEADERS := $(KERNEL_DIR)/prebuilt_kernel_headers.tar.gz
TARGET_PREBUILT_DTB := $(KERNEL_DIR)/dtb.img
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)
BOARD_INCLUDE_DTB_IN_BOOTIMG := 
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_DIR)/dtbo.img
BOARD_PREBUILT_DTBOIMAGE_PRESIGNED := true
BOARD_KERNEL_SEPARATED_DTBO := 
BOARD_PREBUILT_VENDOR_BOOTIMAGE := $(KERNEL_DIR)/vendor_boot.img
BOARD_PREBUILT_VENDOR_DLKMIMAGE := $(KERNEL_DIR)/vendor_dlkm.img
BOARD_PREBUILT_SYSTEM_DLKMIMAGE := $(KERNEL_DIR)/system_dlkm.img
endif

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 18874368
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_SUPER_PARTITION_SIZE := 13421772800
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    odm \
    vendor_dlkm \
    system \
    product \
    system_ext \
    system_dlkm \
    vendor
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 13411287040
BOARD_USES_METADATA_PARTITION := true

# Filesystems
TARGET_FS_CONFIG_GEN += $(DEVICE_PATH)/config.fs

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
# Keep add-on ZIP targets writable and leave room for the 2.1 GB stock NikGapps payload.
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 2250000000
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs

# Platform
TARGET_BOARD_PLATFORM := sun
BOARD_SHIPPING_API_LEVEL := 202404

# SELinux
include device/qcom/sepolicy_vndr/sm8750/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
# Vendor/odm SELinux policy is the stock OS4.0.0.6 one (vendor/xiaomi/xuanyuan/sepolicy-stock),
# built for platform sepolicy 202404; see the system/sepolicy xuanyuan patch.
BOARD_SEPOLICY_VERS_OVERRIDE := 202404
# Stock vendor policy labels /sys/power/mem_sleep itself; keep pre-202504 genfs labels.
BOARD_GENFS_LABELS_VERSION := 202404
BOARD_GENFS_LABELS_VERSION_ALLOW_OLDER := true

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_SYSTEM_EXT_PROP += $(DEVICE_PATH)/system_ext.prop
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_ODM_DLKM_PROP += $(DEVICE_PATH)/odm_dlkm.prop

# Recovery
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Security patch level
VENDOR_SECURITY_PATCH := 2026-02-01

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION := 4
# pre-signed stock DTBO: BOARD_AVB_DTBO_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
# pre-signed stock DTBO: BOARD_AVB_DTBO_ALGORITHM := SHA256_RSA4096
# pre-signed stock DTBO: BOARD_AVB_DTBO_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
# pre-signed stock DTBO: BOARD_AVB_DTBO_ROLLBACK_INDEX_LOCATION := 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_VBMETA_SYSTEM := system system_ext product system_dlkm
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2
BOARD_AVB_VENDOR_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VENDOR_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION := 5

# VINTF

# Inherit the proprietary files
include vendor/xiaomi/xuanyuan/BoardConfigVendor.mk

# VINTF
DEVICE_MANIFEST_SKUS := sun kera tuna
DEVICE_MANIFEST_SUN_FILES := $(DEVICE_PATH)/vintf/manifest_sun.xml
DEVICE_MANIFEST_KERA_FILES := $(DEVICE_PATH)/vintf/manifest_kera.xml
DEVICE_MANIFEST_TUNA_FILES := $(DEVICE_PATH)/vintf/manifest_tuna.xml

ODM_MANIFEST_FILES := $(DEVICE_PATH)/vintf/manifest_odm.xml

# Base manifest: provides target-level for the SKU-less VINTF check.
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/manifest.xml

# Wi-Fi VINTF fragment (Android 16 build rules)
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/configs/wifi/android.hardware.wifi-service.xml

# The stock IR prebuilt has no attached vintf_fragments. Merge its AIDL
# declaration instead of copying VINTF metadata through PRODUCT_COPY_FILES.
DEVICE_MANIFEST_FILE += hardware/interfaces/ir/aidl/default/android.hardware.ir-service.example.xml
