#!/usr/bin/env python3
"""
VM'deki mevcut vendor agaci ile bizim OS4.0.0.6 agacimiz arasindaki
farki hesaplar ve rsync --files-from icin liste uretir.

Kurallar:
  - bizde olup VM'de olmayan  -> aktar (yeni dosya)
  - ikisinde de var ama boyut farkli -> aktar (daha guncel olan bizimki)
  - ayni isim + ayni boyut  -> atla (aktarilacak bir sey yok)
  - VM'de olup bizde olmayan -> silinecek listeye yaz
"""
import pathlib
import sys

root = pathlib.Path("work/vendor-tree")
vm_list = pathlib.Path("work/vm-vendor-filelist.txt")

vm = {}
for line in vm_list.read_text().splitlines():
    line = line.strip()
    if not line:
        continue
    size, path = line.split(None, 1)
    path = path.replace("./", "", 1)
    if not path.startswith("proprietary/"):
        path = "proprietary/" + path
    vm[path] = int(size)

ours = {}
for p in (root / "proprietary").rglob("*"):
    if p.is_file() and p.name != ".DS_Store":
        ours[str(p.relative_to(root))] = p.stat().st_size

to_transfer = []
for path, size in ours.items():
    if path not in vm:
        to_transfer.append(path)
    elif vm[path] != size:
        to_transfer.append(path)

to_delete = [p for p in vm if p not in ours]

mb = sum(ours[p] for p in to_transfer) / 1024 / 1024
print(f"VM'deki dosya      : {len(vm)}")
print(f"bizim dosya        : {len(ours)}")
print(f"aktarilacak        : {len(to_transfer)} dosya  {mb:.0f} MB")
print(f"silinecek (fazlal) : {len(to_delete)} dosya  {sum(vm[p] for p in to_delete)/1024/1024:.0f} MB")

out = pathlib.Path("work/vendor-delta-files.txt")
out.write_text("\n".join(sorted(to_transfer)) + "\n")
print(f"liste yazildi      : {out}")

dele = pathlib.Path("work/vendor-extra-files.txt")
dele.write_text("\n".join(sorted(to_delete)) + "\n")
print(f"liste yazildi      : {dele}")

# build tanimlari ayrica (her zaman gonder)
for f in ("Android.bp", "xuanyuan-vendor.mk", "BoardConfigVendor.mk", "Android.mk"):
    p = out.read_text().splitlines()
    if f not in p:
        p.append(f)
out.write_text("\n".join(sorted(set(p))) + "\n")
print("build tanimlari listeye eklendi")
