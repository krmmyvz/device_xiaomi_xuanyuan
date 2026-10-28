#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Shared Xiaomi SM8750 product layer (DADA-derived structure).
$(call inherit-product, device/xiaomi/sm8750-common/common.mk)

# Authorize the development host in recovery without requiring an on-device
# confirmation dialog. This is the public half of the local ADB keypair.
PRODUCT_ADB_KEYS := $(wildcard device/xiaomi/xuanyuan/recovery/adb_keys)

# CamX SoC HAL compatibility path
PRODUCT_PACKAGES += xuanyuan_camera_sm8750_vendor_path
PRODUCT_PACKAGES += xuanyuan_vendor_camera_camera_qcom_so xuanyuan_vendor_camera_aon_front_i_1_pb xuanyuan_vendor_camera_aon_front_ii_1_pb xuanyuan_vendor_camera_aon_rear_i_2_pb xuanyuan_vendor_camera_aon_rear_ii_2_pb xuanyuan_vendor_camera_bitmlconfig_bin xuanyuan_vendor_camera_com_qti_ofe_profiledb_default_bin

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=ext4 \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script

# API levels
PRODUCT_SHIPPING_API_LEVEL := 35

# Legacy HIDL compatibility
# The stock vendor stack still exposes legacy HIDL HALs even though the
# device launched on API level 35.
PRODUCT_PACKAGES += \
    android.hidl.allocator@1.0-service \
    android.hidl.memory@1.0-impl \
    hwservicemanager

# Core vendor services
# Use the source-built modules here. The similarly named proprietary
# prebuilts are dependency-only variants and are not installable.
PRODUCT_PACKAGES += \
    android.hardware.health-service.qti \
    charger \
    wpa_supplicant

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# Developer GSI AVB keys for first-stage mounts
$(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)

# fastbootd and Qualcomm recovery HALs
# QTI Boot Control is required in recovery so fastbootd reports the real
# current slot and updates the matching liblp metadata slot.
PRODUCT_PACKAGES += \
    android.hardware.health-service.qti_recovery \
    android.hardware.boot-service.qti.recovery-xuanyuan \
    fastbootd

# Kernel
PRODUCT_ENABLE_UFFD_GC := true

# Overlays
PRODUCT_PACKAGE_OVERLAYS += device/xiaomi/xuanyuan/overlay
PRODUCT_ENFORCE_RRO_TARGETS := *

# Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Product characteristics
PRODUCT_CHARACTERISTICS := nosdcard

# VINTF
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    device/xiaomi/xuanyuan/vintf/device_framework_matrix.xml

# Rootdir
PRODUCT_PACKAGES += \
    coresight_reset_source_sink.sh \
    dcc-script-tuna.sh \
    dcc-script.sh \
    dcc_extension.sh \
    flash.sh \
    flash_before.sh \
    init.class_main.sh \
    init.crda.sh \
    init.kernel.extra_free_kbytes.sh \
    init.kernel.init_boot-memory.sh \
    init.kernel.post_boot-kera.sh \
    init.kernel.post_boot-kera_2_3_1.sh \
    init.kernel.post_boot-kera_2_4_0.sh \
    init.kernel.post_boot-kera_3_2_1.sh \
    init.kernel.post_boot-kera_default_3_4_1.sh \
    init.kernel.post_boot-memory.sh \
    init.kernel.post_boot-sun.sh \
    init.kernel.post_boot-sun_5_2.sh \
    init.kernel.post_boot-sun_6_0.sh \
    init.kernel.post_boot-sun_default_6_2.sh \
    init.kernel.post_boot-tuna.sh \
    init.kernel.post_boot-tuna_1_3_2_1.sh \
    init.kernel.post_boot-tuna_2_2_2_1.sh \
    init.kernel.post_boot-tuna_2_3_1_1.sh \
    init.kernel.post_boot-tuna_2_3_2_0.sh \
    init.kernel.post_boot-tuna_default_2_3_2_1.sh \
    init.kernel.post_boot.sh \
    init.mdm.sh \
    init.qcom.class_core.sh \
    init.qcom.coex.sh \
    init.qcom.early_boot.sh \
    init.qcom.efs.sync.sh \
    init.qcom.post_boot.sh \
    init.qcom.sdio.sh \
    init.qcom.sensors.sh \
    init.qcom.sh \
    init.qcom.usb.sh \
    init.qcrild.sh \
    init.qti.display_boot.sh \
    init.qti.kernel.debug-kera.sh \
    init.qti.kernel.debug-sun.sh \
    init.qti.kernel.debug-tuna.sh \
    init.qti.kernel.debug.sh \
    init.qti.kernel.early_debug-kera.sh \
    init.qti.kernel.early_debug-sun.sh \
    init.qti.kernel.early_debug-tuna.sh \
    init.qti.kernel.early_debug.sh \
    init.qti.kernel.sh \
    init.qti.keymaster.sh \
    init.qti.media.sh \
    init.qti.qcv.sh \
    init.qti.write.sh \
    init.qvrd.usb_mtu_set.sh \
    init.xiaomi.modem.sh \
    init.xrcommd.usb_mtu_set.sh \
    qca6234-service.sh \
    system_dlkm_modprobe.sh \
    ufs_ffu.sh \
    vendor.qti.diag.sh \
    vendor_modprobe.sh \

PRODUCT_PACKAGES += \
    fstab.qcom \
    init.batterysecret.rc \
    init.mi_thermald.rc \
    init.qcom.factory.rc \
    init.qcom.rc \
    init.qcom.usb.rc \
    init.qti.kernel.rc \
    init.qti.kernel.target.rc \
    init.qti.ufs.rc \
    init.target.rc \
    init.recovery.hardware.rc \
    init.recovery.qcom.rc \
    miui.factoryreset.rc \

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.qcom

PRODUCT_PACKAGES += \
    libprotobuf-cpp-full-21.12-system_ext

PRODUCT_PACKAGES += \
    libaudio_aidl_conversion_common_ndk_system

PRODUCT_PACKAGES += \
    libaudioroute_xuanyuan_system \
    libaudioutils_xuanyuan_system \
    libaudioutils_xuanyuan_product \
    libtinyalsa_xuanyuan_system \
    libtinyalsa_xuanyuan_product

# Soong namespaces
#
# hardware/xiaomi: Xiaomi'nin kendi HAL agaci (xiaomi-8750/android_hardware_xiaomi).
# Bu ad Soong'da bir namespace OLUSTURMASI icin PRODUCT_SOONG_NAMESPACES
# icinde olmali. Cihaz agacinin Android.bp dosyasi bu namespace'i
# "imports" ile kullaniyor; tanimlanmazsa Soong su hatayi verir:
#
#   error: device/xiaomi/xuanyuan/Android.bp:6:1: module "soong_namespace":
#          namespace hardware/xiaomi does not exist
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/qcom-caf/wlan \
    hardware/qcom-caf/sm8750 \
    hardware/xiaomi \
    vendor/xiaomi/xuanyuan

# Inherit the proprietary files
$(call inherit-product, vendor/xiaomi/xuanyuan/xuanyuan-vendor.mk)

# Early boot diagnostics and device-specific service synchronization
PRODUCT_COPY_FILES += \
    device/xiaomi/xuanyuan/rootdir/system_ext/etc/init/init.xuanyuan.bootdiag.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/init.xuanyuan.bootdiag.rc \
    device/xiaomi/xuanyuan/rootdir/system_ext/etc/init/init.xuanyuan.security.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/init.xuanyuan.security.rc \
    device/xiaomi/xuanyuan/rootdir/system_ext/bin/bootdiag.sh:$(TARGET_COPY_OUT_SYSTEM_EXT)/bin/bootdiag.sh \
    device/xiaomi/xuanyuan/rootdir/odm/etc/init/init.xuanyuan-native-resolution.rc:$(TARGET_COPY_OUT_ODM)/etc/init/init.xuanyuan-native-resolution.rc

# Stock product compatibility: keep the stock zero-byte QTI public library list as a real file.
PRODUCT_COPY_FILES += \
    device/xiaomi/xuanyuan/prebuilts/product/etc/public.libraries-qti.txt:$(TARGET_COPY_OUT_PRODUCT)/etc/public.libraries-qti.txt

PRODUCT_COPY_FILES += \
    device/xiaomi/xuanyuan/rootdir/system_ext/etc/permissions/privapp-permissions-xuanyuan.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/privapp-permissions-xuanyuan.xml

# Qualcomm telephony shared libraries required by stock qcrilmsgtunnel.
PRODUCT_COPY_FILES += \
    device/xiaomi/xuanyuan/prebuilts/esim/framework/qti-telephony-hidl-wrapper-prd.jar:$(TARGET_COPY_OUT_SYSTEM_EXT)/framework/qti-telephony-hidl-wrapper.jar

# These source-tree permission XMLs are byte-identical to the stock versions.
PRODUCT_PACKAGES += \
    qti_telephony_hidl_wrapper.xml \
    qti_telephony_utils.xml

# Legacy vendor Binder context manager required by stock vendor stack
PRODUCT_PACKAGES += \
    vndservicemanager

# Runtime AIDL library required by the stock KeyMint V3 services.
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-V3-ndk.vendor

# Compatibility libraries required by the stock Android 15 vendor/ODM HALs.
PRODUCT_PACKAGES += \
    android.hardware.camera.provider-V2-ndk.vendor \
    android.hardware.drm-V1-ndk.vendor \
    android.hardware.graphics.allocator-V1-ndk.vendor \
    android.hardware.graphics.common-V5-ndk.vendor \
    android.hardware.sensors-V2-ndk.vendor \
    android.hardware.thermal@1.0.vendor \
    libcld80211 \
    libprotobuf-cpp-full-21.12-vendorcompat \
    libprotobuf-cpp-lite-21.12-vendorcompat \
    libsensorndkbridge \
    vendor.qti.diaghal-V1-ndk-system_ext \
    vendor.qti.hardware.display.allocator@4.0.vendor

# Stable AIDL compatibility libraries required by the stock Android 15 audio HAL.
# Retain the stock303 V4 provider/session ABI used by QTI software A2DP.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth.audio-V4-ndk.vendor \
    android.hardware.bluetooth.audio-impl \
    libbluetooth_audio_session_aidl \
    libstagefright_foundation-v33

# Stock AIDL NDK libs that no installed module provides but stock vendor blobs
# link against (audio HAL, camera provider, SPU keymint).
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.audio.core-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.audio.core-V2-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.audio.core.sounddose-V1-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.audio.core.sounddose-V1-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.audio.effect-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.audio.effect-V2-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.metadata-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.metadata-V2-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.security.sharedsecret-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.security.sharedsecret-V2-ndk.so

# Stock camera AIDL NDK libs. The stock camx provider was built against these;
# the source-built ones link newer metadata/common versions and corrupt the
# provider heap when it frees a CaptureRequest. These copies win over the
# source modules that install the same paths.
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.common-V1-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.common-V1-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.device-V1-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.device-V1-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.device-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.device-V2-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.metadata-V1-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.metadata-V1-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.provider-V1-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.provider-V1-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/android.hardware.camera.provider-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.camera.provider-V2-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/vendor.qti.hardware.camera.offlinecamera-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/vendor.qti.hardware.camera.offlinecamera-V2-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/vendor.qti.hardware.camera.aon-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/vendor.qti.hardware.camera.aon-V2-ndk.so

# SM8750 AudioPolicy uses the xuanyuan-specific top-level policy.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_ODM)/etc/audio_policy_configuration.xml \
    $(LOCAL_PATH)/configs/audio/vendor_audio_interfaces.xml:$(TARGET_COPY_OUT_ODM)/etc/audio/sku_sun/vendor_audio_interfaces.xml \
    $(LOCAL_PATH)/configs/audio/vendor_audio_interfaces.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio/vendor_audio_interfaces.xml

# JPEG UltraHDR and HEIF compatibility: retain gainmaps, omit orphan sharp-image branches.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/camera/satsnapshot-hdr-compatible.json:$(TARGET_COPY_OUT_ODM)/etc/camera/xiaomi/satsnapshot.json

# Xiaomi 15 Ultra physical UDFPS stack: the stock OS4 mfp-daemon, which the
# stock vendor SELinux policy already confines (vendor_mfp-daemon). It loads the
# stock fingerprint.{qcom,goodix}_us modules from /odm/lib64/hw; the AIDL
# runtime libs it links come from source.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.common-V4-ndk.vendor \
    android.hardware.biometrics.common.thread.vendor \
    android.hardware.biometrics.common.util.vendor \
    android.hardware.biometrics.fingerprint-V5-ndk.vendor \
    android.hardware.fingerprint.permission-neoteric \
    qti_fingerprint_interface.permission-neoteric

PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/odm/bin/hw/mfp-daemon:$(TARGET_COPY_OUT_ODM)/bin/hw/mfp-daemon \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/init/init.mfp-daemon.aidl.rc:$(TARGET_COPY_OUT_ODM)/etc/init/init.mfp-daemon.aidl.rc


# Camera feature declarations from AOSP plus the stock xuanyuan extension list.
PRODUCT_PACKAGES += \
    libcamxexternalformatutils-vendor-xuanyuan

# The camera provider uses the vendor (stock OS4) graphics stack, except for
# tinyxml2/gralloctypes, whose source-built vendor variants differ from the ones
# camx was built against; stock OS4 copies go to /odm/lib64 instead. The old
# stock303 copies broke gralloc buffer mapping. camx also mishandles tagged heap
# pointers, so the provider (patched to DT_NEEDED callstack.so) loads a shim
# that turns heap pointer tagging off for that process only.
PRODUCT_PACKAGES += \
    android.hardware.graphics.common-V5-ndk.vendor \
    android.hardware.graphics.allocator-V2-ndk.vendor \
    libcamera_heap_compat

PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/odm/lib64/libtinyxml2.so:$(TARGET_COPY_OUT_ODM)/lib64/libtinyxml2.so \
    vendor/xiaomi/xuanyuan/proprietary/odm/lib64/libgralloctypes.so:$(TARGET_COPY_OUT_ODM)/lib64/libgralloctypes.so

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.camera.concurrent.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.concurrent.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.raw.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.raw.xml \
    device/xiaomi/xuanyuan/neoteric_compat/vendor/etc/permissions/camera_extensions.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/camera_extensions.xml

# xuanyuan compatibility symlinks and feature declarations.
# The source Wi-Fi service is non-installable; retain the stock303 HAL instead
# of falling back to wificond before CNSS has created wlan0.
PRODUCT_PACKAGES += android.hardware.wifi-service_vendor

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/wifi/android.hardware.wifi-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.wifi-service.rc

# Keep these source-built or stock-derived; do not install Neoteric prebuilts.
PRODUCT_PACKAGES += \
    xuanyuan_wlan_kiwi_v2_cfg \
    xuanyuan_wlan_kiwi_v2_mac \
    xuanyuan_wlan_peach_cfg \
    xuanyuan_wlan_peach_mac \
    xuanyuan_wlan_peach_v2_cfg \
    xuanyuan_wlan_peach_v2_mac \
    xuanyuan_wlan_qca6750_cfg \
    xuanyuan_wlan_qca6750_mac \
    xuanyuan_wlan_wcn7750_cfg \
    xuanyuan_wlan_wcn7750_mac \
    xuanyuan_wlanmdsp_otaupdate \
    xuanyuan_a16_FrameworksRes \
    xuanyuan_a16_SystemUIRes

# The 303 IR service is a prebuilt, so it does not inherit the source
# module's init_rc/vintf_fragments. Install the RC and feature here; the AIDL
# manifest is merged through DEVICE_MANIFEST_FILE in BoardConfig.mk.
PRODUCT_COPY_FILES += \
    hardware/interfaces/ir/aidl/default/android.hardware.ir-service.example.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.ir-service.example.rc \
    frameworks/native/data/etc/android.hardware.consumerir.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.consumerir.xml

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.audio.pro.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.pro.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.telephony.cdma.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.cdma.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.aware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.aware.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.wifi.rtt.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.rtt.xml \
    $(LOCAL_PATH)/prebuilts/stock/permissions/vendor.hardware.vibratorfeature-permission.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/vendor.hardware.vibratorfeature-permission.xml


# Build the Qualcomm USB HAL from source. The xuanyuan libc++ lacks the
# internal __hash_memory symbol used by the old prebuilt.
# Prebuilt vibratorfeature-wrapper is linked against AIDL vibrator V2.
PRODUCT_PACKAGES += \
    android.hardware.vibrator-V2-ndk.vendor

PRODUCT_PACKAGES += \
    android.hardware.usb-service.qti-xuanyuan \
    android.hardware.usb.gadget-service.qti-xuanyuan \
    usb_compositions.conf

# SM8750 Xiaomi sensors stack (matched to Xiaomi 15-series reference implementation).
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.xiaomi-sm8750-multihal \
    sensors.xiaomi.sm8750.udfps

# Keep stock sensor sub-HALs in vendor; add the SM8750 UDFPS sub-HAL from ODM.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/sensors/udfps/hals.conf:$(TARGET_COPY_OUT_ODM)/etc/sensors/hals.conf

# eSIM / eUICC support.
# Keep the stock/QTI runtime pieces already used by xuanyuan, and add the
# same product-side telephony framework pieces used by Xiaomi's SM8750 tree.
# OpenEUICC and the stock EidService/uimremote* services are left out for now:
# they do not build against this tree yet.
PRODUCT_PACKAGES += \
    uimlpaservice-xuanyuan \
    uimlpalibrary-xuanyuan \
    libjni_aidl_service-xuanyuan \
    xuanyuan_lpa_permission

# Feature declarations belong under permissions, not sysconfig.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.euicc.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/android.hardware.telephony.euicc.xml \
    $(LOCAL_PATH)/prebuilts/esim/sysconfig/android.hardware.telephony.euicc.mep.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/android.hardware.telephony.euicc.mep.xml

# Xiaomi 15 Ultra MIUI Camera 6.4.000450.1 (Android 16 FILTERFIX)
PRODUCT_PACKAGES += \
    MiuiCamera \
    miui-cameraopt \
    xuanyuan_miuicamera_device_features \
    xuanyuan_miuicamera_privapp_permissions \
    xuanyuan_miuicamera_cameraopt_json \
    xuanyuan_miuicamera_cameraopt_perf_json \
    xuanyuan_miuicamera_cameraopt_reclaim_json \
    xuanyuan_miuicamera_cameraopt_thirdparty_json \
    xuanyuan_miuicamera_cameraopt_permission \
    xuanyuan_miuicamera_task_profiles \
    libcameraopt_miuicamera_system_ext \
    libcameraopt_jni_miuicamera_system_ext \
    libcamera_algoup_jni_xiaomi_miuicamera_system_ext

# Stock libui/libgui: stock camx and other vendor blobs are built against them;
# the source-built vendor variants corrupt the camera provider heap.
# systemhelperaidl-V1: stock adds ISystemTUICallback, which mitrustedui links.
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/libui.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libui.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/libgui.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgui.so \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/vendor.qti.hardware.systemhelperaidl-V1-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/vendor.qti.hardware.systemhelperaidl-V1-ndk.so

# Stock QCC system HAL (system_ext): the location XTRA daemon registers with QCC
# before downloading assistance data.
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/bin/qccsyshal_aidl-service:$(TARGET_COPY_OUT_SYSTEM_EXT)/bin/qccsyshal_aidl-service \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/etc/init/vendor.qti.qccsyshal_aidl-service.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/vendor.qti.qccsyshal_aidl-service.rc \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/etc/permissions/com.qti.qcc.vendor_qcc.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/com.qti.qcc.vendor_qcc.xml \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/libqcc.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libqcc.so \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/libqcc_netstats.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libqcc_netstats.so \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/libqccdme.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libqccdme.so \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/libqccfileservice.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libqccfileservice.so \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/vendor.qti.qccsyshal_aidl-V1-ndk.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.qccsyshal_aidl-V1-ndk.so \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/vendor.qti.qccsyshal_aidl-halimpl.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.qccsyshal_aidl-halimpl.so \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/vendor.qti.qccvndhal_aidl-V2-ndk.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.qccvndhal_aidl-V2-ndk.so

# libcameraopt links the stock quickcamera AIDL client (stock OS4 system_ext).
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/system_ext/lib64/vendor.xiaomi.hardware.quickcamera-V1-ndk.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.xiaomi.hardware.quickcamera-V1-ndk.so

# Restore stock Qualcomm RFS symlink tree.
$(call inherit-product, device/xiaomi/xuanyuan/rfs_symlinks/rfs_symlinks.mk)

# Stock files no module installs (memtrack, feature declarations, overlays).
$(call inherit-product, device/xiaomi/xuanyuan/stock_missing.mk)

# Xiaomi compatibility HAL wrappers.
PRODUCT_PACKAGES += \
    vibratorfeature-wrapper-neoteric

# Stock Xiaomi multimedia/Bluetooth codec additions absent from the base ROM.
PRODUCT_PACKAGES += \
    liblhdc-xuanyuan-stock \
    liblhdcv5-xuanyuan-stock \
    vendor.dolby.hardware.dms@2.0-xuanyuan-stock \
    libaivsopus-xuanyuan-stock \
    libmimediacodec-xuanyuan-stock \
    libqape.qti-xuanyuan-stock \
    libtelecodec_android-xuanyuan-stock \
    libvideocodeccapability-xuanyuan-stock \
    libvideocodecinfo-xuanyuan-stock \
    vendor.dolby.dvs-V1-ndk-xuanyuan-stock \
    vendor.xiaomi.hardware.videoservice-V2-ndk-xuanyuan-stock

# Keep the source vndfwk shim. The camera interfaces use preferred stock
# providers under the canonical vendor-variant identities (no duplicate owner).
PRODUCT_PACKAGES += libqti_vndfwk_detect.vendor
PRODUCT_PACKAGES += android.frameworks.cameraservice.common-V1-ndk.vendor

# Advertise supported NFC hardware to PackageManager.
PRODUCT_COPY_FILES += frameworks/native/data/etc/android.hardware.nfc.xml:vendor/etc/permissions/android.hardware.nfc.xml

# Required by mifaced/libcamera2ndk_vendor at runtime.
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/vendor/lib64/libcamera2ndk_vendor.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcamera2ndk_vendor.so
PRODUCT_PACKAGES += android.frameworks.cameraservice.device-V2-ndk.vendor

PRODUCT_PACKAGES += android.frameworks.cameraservice.service-V2-ndk.vendor
PRODUCT_COPY_FILES += frameworks/native/data/etc/android.hardware.nfc.hce.xml:vendor/etc/permissions/android.hardware.nfc.hce.xml

# SELinux: the vendor/odm policy is the stock OS4.0.0.6 one (202404). init compiles the
# split policy at boot (enforcing); a build-time precompiled policy would mix it with
# AOSP 16 neverallows. Re-enable once the vendor policy is built from source.
PRODUCT_PRECOMPILED_SEPOLICY := false
