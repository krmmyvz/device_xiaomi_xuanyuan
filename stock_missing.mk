# Stock OS4 vendor/odm files that no module or blob list installs:
# Memtrack init and feature declarations (Thales eSE StrongBox/Weaver left out:
# the eSE applet does not answer yet and stalls keystore for a minute per boot).
# Generated from the stock dump; the files live in the vendor proprietary tree.
PRODUCT_COPY_FILES += \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/init/memtrack_qti.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/memtrack_qti.rc \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/com.xiaomi.sensor.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/com.xiaomi.sensor.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level-1.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.vulkan.version-1_3.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_3.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/privapp-permissions-qti-vendor.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/privapp-permissions-qti-vendor.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.dynamic.head_tracker.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.dynamic.head_tracker.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.stepdetector.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.compass.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.accelerometer.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.gyroscope.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.proximity.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.light.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_sun/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_sun/android.hardware.sensor.stepcounter.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute-0.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.software.device_id_attestation.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_id_attestation.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.software.vulkan.deqp.level.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_1.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/com.android.se.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/com.android.se.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/features_com.android.virt.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/features_com.android.virt.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/vendor.qti.qva.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/vendor.qti.qva.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.se.omapi.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.ese.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.software.opengles.deqp.level.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.opengles.deqp.level.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.hardware_keystore.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.hardware_keystore.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.telephony.mbms.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.mbms.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/vendor.qti.dcf.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/vendor.qti.dcf.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.dynamic.head_tracker.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.dynamic.head_tracker.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.stepdetector.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.compass.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.accelerometer.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.gyroscope.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.proximity.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.light.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_tuna/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_tuna/android.hardware.sensor.stepcounter.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/xiaomi.global.hardware.features.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/xiaomi.global.hardware.features.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.telephony.satellite.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.satellite.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.hifi_sensors.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.hifi_sensors.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.dynamic.head_tracker.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.dynamic.head_tracker.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.stepdetector.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.ambient_temperature.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.ambient_temperature.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.barometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.barometer.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.compass.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.relative_humidity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.relative_humidity.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.accelerometer.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.gyroscope.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.proximity.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.light.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/sku_kera/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/sku_kera/android.hardware.sensor.stepcounter.xml \
    vendor/xiaomi/xuanyuan/proprietary/vendor/etc/permissions/android.hardware.se.omapi.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.uicc.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.sensor.hifi_sensors.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.sensor.hifi_sensors.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.nfc.hcef.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.nfc.hcef.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/com.android.nfc_extras.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/com.android.nfc_extras.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.sensor.barometer.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.sensor.barometer.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.context_hub.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.context_hub.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.nfc.ese.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.nfc.ese.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.location.gps.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.se.omapi.ese.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.se.omapi.ese.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.nfc.uicc.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.nfc.uicc.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/com.nxp.mifare.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/com.nxp.mifare.xml \
    vendor/xiaomi/xuanyuan/proprietary/odm/etc/permissions/android.hardware.se.omapi.uicc.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.se.omapi.uicc.xml


# Stock vendor/odm runtime resource overlays (static RROs): framework power
# profile/brightness, Wi-Fi capabilities, Bluetooth XPAN, and the SecureElement
# vendor OMAPI switch that StrongBox and Weaver need.
PRODUCT_PACKAGES += \
    xuanyuan_stock_overlay_SecureElementResTarget_Vendor \
    xuanyuan_stock_overlay_WifiResMainlineTarget \
    xuanyuan_stock_overlay_WifiResMainlineTarget_spf \
    xuanyuan_stock_overlay_WifiResTarget \
    xuanyuan_stock_overlay_WifiResTarget_spf \
    xuanyuan_stock_overlay_XpanResTarget_Vendor \
    xuanyuan_stock_overlay_FrameworksResTarget_Vendor
