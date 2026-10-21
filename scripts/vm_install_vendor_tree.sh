#!/usr/bin/env bash
# Vendor agacini kendi OS4.0.0.6 agacimizla degistirir ve dogrular.
#
# Onceki durum: vendor/xiaomi/xuanyuan = xiaomi-8750/proprietary_vendor_xuanyuan
# (beryl) checkout'u. Eksik: composer3-V2/V3, offlinecamera-V2, camera.device-V2,
# camera.metadata-V2 AIDL mirror kutuphaneleri. CAF ve vendor Android.bp'leri
# bunlari gerektiriyor -> "depends on undefined module".
#
# Bu adim:
#   1) delta aktarimi (rsync --files-from) zaten yapilmis olmali
#   2) fazla dosyalari siler (bizde olmayan 98 dosya)
#   3) git metadata'sini kaldirir (proje manifest'ten cikarilacak)
#   4) build tanimlarini dogrular
set -u
cd /mnt/src

V=vendor/xiaomi/xuanyuan

echo "=== 1) fazla dosyalar siliniyor (bizim agacta olmayanlar) ==="
if [ -f /mnt/out/vendor-extra-files.txt ]; then
  n=0
  while read -r f; do
    [ -n "$f" ] || continue
    p="/mnt/src/$f"
    if [ -f "$p" ]; then rm -f "$p"; n=$((n+1)); fi
  done < /mnt/out/vendor-extra-files.txt
  echo "  silinen: $n"
else
  echo "  (liste yok, atlandi)"
fi

echo
echo "=== 2) git metadata kaldiriliyor (dizin artifact'e devrediliyor) ==="
if [ -d "$V/.git" ]; then
  rm -rf "$V/.git"
  echo "  $V/.git silindi"
fi

echo
echo "=== 3) build tanimlari ==="
for f in Android.bp xuanyuan-vendor.mk BoardConfigVendor.mk Android.mk; do
  if [ -f "$V/$f" ]; then
    printf "  var   %-22s %s bayt\n" "$f" "$(stat -c%s "$V/$f")"
  else
    printf "  YOK   %s\n" "$f"
  fi
done

echo
echo "=== 4) AIDL mirror kutuphaneleri (onceki eksikler) ==="
for n in composer3-V1-ndk composer3-V2-ndk composer3-V3-ndk offlinecamera-V2-ndk \
         camera.device-V2-ndk camera.metadata-V2-ndk; do
  f=$(find "$V/proprietary" -name "*${n}.so" 2>/dev/null | head -1)
  printf "  %-24s %s\n" "$n" "${f:-YOK}"
done

echo
echo "=== 5) ağac özeti ==="
echo "  blob sayisi  : $(find "$V/proprietary" -type f 2>/dev/null | wc -l)"
echo "  agac boyutu  : $(du -sh "$V/proprietary" 2>/dev/null | cut -f1)"
echo "  prebuilt     : $(grep -c '^cc_prebuilt' "$V/Android.bp" 2>/dev/null)"
echo "  vendor.mk    : $(wc -l < "$V/xuanyuan-vendor.mk" 2>/dev/null) satir"
