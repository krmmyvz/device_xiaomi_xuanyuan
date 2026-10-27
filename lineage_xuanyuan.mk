#

# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from generic device
$(call inherit-product, device/xiaomi/xuanyuan/device.mk)

# Keep the stock 303 vendor boot ramdisk and its kernel modules intact.
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# xuanyuan requires Xiaomi's stock Wi-Fi HAL. Drop the generic AOSP service
# after common product inheritance so both services do not target the same path.
PRODUCT_PACKAGES := $(filter-out android.hardware.wifi-service,$(PRODUCT_PACKAGES))

PRODUCT_PACKAGES := $(filter-out android.hardware.sensors-service.multihal,$(PRODUCT_PACKAGES))
# Use the stock/Neoteric Xiaomi fingerprint HAL; do not install the generic Lineage service.
PRODUCT_PACKAGES := $(filter-out \
    android.hardware.biometrics.fingerprint-service.lineage, \
    $(PRODUCT_PACKAGES))

PRODUCT_DEVICE := xuanyuan
PRODUCT_NAME := lineage_xuanyuan
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := 25010PN30G
PRODUCT_MANUFACTURER := Xiaomi

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# The stock QTI effect factory loads the V2/V6 ABI blobs from vendor.  Drop
# the newer AOSP implementations so the stock prebuilts are the sole owners
# of vendor/lib64/soundfx for these five library names.
PRODUCT_PACKAGES := $(filter-out \
    libdownmixaidl \
    libdynamicsprocessingaidl \
    libloudnessenhanceraidl \
    libreverbaidl \
    libvisualizeraidl, \
    $(PRODUCT_PACKAGES))

# Diagnostic build (temporary; revert for daily builds): debuggable userdebug with
# preloaded adb keys so logs can be read when the display never comes up.
# Must be empty: add_json_bool treats any non-empty value (even "false") as true.
PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG :=
PRODUCT_ADB_KEYS := vendor/xiaomi/xuanyuan/debug/adb_keys
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/debug/diaglog.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/diaglog.rc \
    vendor/xiaomi/xuanyuan/debug/diaglog.sh:$(TARGET_COPY_OUT_SYSTEM)/bin/diaglog.sh
PRODUCT_PRODUCT_PROPERTIES += persist.sys.usb.config=adb
