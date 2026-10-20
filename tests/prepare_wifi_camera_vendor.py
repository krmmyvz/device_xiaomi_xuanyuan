from pathlib import Path
import shutil,hashlib
r=Path("/home/user/rom/xuanyuan")
d=r/"device/xiaomi/xuanyuan"
p=r/"out/target/product/xuanyuan"
v=r/"vendor/xiaomi/xuanyuan/proprietary/vendor"
base=p/"vendor_200mp_only_tree"
out=p/"vendor_wifi_camera_restore_20261012"
camera="lib64/android.frameworks.cameraservice.common-V1-ndk.so"
files={
"bin/hw/android.hardware.wifi-service":v/"bin/hw/android.hardware.wifi-service",
"etc/init/android.hardware.wifi-service.rc":d/"configs/wifi/android.hardware.wifi-service.rc",
"etc/vintf/manifest/android.hardware.wifi-service.xml":d/"configs/wifi/android.hardware.wifi-service.xml",
"lib64/libwifi-system-iface.so":v/"lib64/libwifi-system-iface.so"
}
assert base.is_dir() and (base/camera).is_file()
assert not out.exists()
assert all(f.is_file() for f in files.values())
shutil.copytree(base,out,symlinks=True)
for name,src in files.items():
 dest=out/name
 dest.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(src,dest)
 assert hashlib.sha256(src.read_bytes()).digest()==hashlib.sha256(dest.read_bytes()).digest()
 print("ADDED",name, dest.stat().st_size)
assert (out/camera).read_bytes()==(base/camera).read_bytes()
print("STAGED_WIFI_AND_CAMERA",out)
