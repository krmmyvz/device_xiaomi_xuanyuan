#!/usr/bin/env python3
"""ELF DT_NEEDED okuyucu (macOS/Linux, harici araç gerekmez)."""
import struct
import sys


def needed(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"\x7fELF":
        return None
    is64 = data[4] == 2
    little = data[5] == 1
    end = "<" if little else ">"

    if is64:
        e_phoff = struct.unpack_from(end + "Q", data, 0x20)[0]
        e_phentsize = struct.unpack_from(end + "H", data, 0x36)[0]
        e_phnum = struct.unpack_from(end + "H", data, 0x38)[0]
    else:
        e_phoff = struct.unpack_from(end + "I", data, 0x1C)[0]
        e_phentsize = struct.unpack_from(end + "H", data, 0x2A)[0]
        e_phnum = struct.unpack_from(end + "H", data, 0x2C)[0]

    loads = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if is64:
            p_type = struct.unpack_from(end + "I", data, off)[0]
            p_offset = struct.unpack_from(end + "Q", data, off + 8)[0]
            p_vaddr = struct.unpack_from(end + "Q", data, off + 16)[0]
            p_filesz = struct.unpack_from(end + "Q", data, off + 32)[0]
        else:
            p_type = struct.unpack_from(end + "I", data, off)[0]
            p_offset = struct.unpack_from(end + "I", data, off + 4)[0]
            p_vaddr = struct.unpack_from(end + "I", data, off + 8)[0]
            p_filesz = struct.unpack_from(end + "I", data, off + 16)[0]
        if p_type == 1:  # PT_LOAD
            loads.append((p_vaddr, p_offset, p_filesz))

    def v2o(v):
        for va, po, sz in loads:
            if va <= v < va + sz:
                return po + (v - va)
        return None

    if is64:
        e_shoff = struct.unpack_from(end + "Q", data, 0x28)[0]
        e_shentsize = struct.unpack_from(end + "H", data, 0x3A)[0]
        e_shnum = struct.unpack_from(end + "H", data, 0x3C)[0]
        e_shstrndx = struct.unpack_from(end + "H", data, 0x3E)[0]
    else:
        e_shoff = struct.unpack_from(end + "I", data, 0x20)[0]
        e_shentsize = struct.unpack_from(end + "H", data, 0x2E)[0]
        e_shnum = struct.unpack_from(end + "H", data, 0x30)[0]
        e_shstrndx = struct.unpack_from(end + "H", data, 0x32)[0]

    secs = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsize
        if is64:
            sh_name = struct.unpack_from(end + "I", data, off)[0]
            sh_type = struct.unpack_from(end + "I", data, off + 4)[0]
            sh_offset = struct.unpack_from(end + "Q", data, off + 24)[0]
            sh_size = struct.unpack_from(end + "Q", data, off + 32)[0]
            sh_link = struct.unpack_from(end + "I", data, off + 40)[0]
            sh_entsize = struct.unpack_from(end + "Q", data, off + 56)[0]
        else:
            sh_name = struct.unpack_from(end + "I", data, off)[0]
            sh_type = struct.unpack_from(end + "I", data, off + 4)[0]
            sh_offset = struct.unpack_from(end + "I", data, off + 16)[0]
            sh_size = struct.unpack_from(end + "I", data, off + 20)[0]
            sh_link = struct.unpack_from(end + "I", data, off + 24)[0]
            sh_entsize = struct.unpack_from(end + "I", data, off + 36)[0]
        secs.append((sh_name, sh_type, sh_offset, sh_size, sh_link, sh_entsize))

    shstr = secs[e_shstrndx]
    names = data[shstr[2]:shstr[2] + shstr[3]]

    def nstr(idx):
        end_i = names.find(b"\0", idx)
        return names[idx:end_i].decode("utf-8", "replace")

    dyn = None
    dynstr = None
    for s in secs:
        nm = nstr(s[0])
        if nm == ".dynamic":
            dyn = s
        if nm == ".dynstr":
            dynstr = s
    if not dyn or not dynstr:
        return []

    strtab = data[dynstr[2]:dynstr[2] + dynstr[3]]
    out = []
    step = 16 if is64 else 8
    fmt = end + ("Qq" if is64 else "Ii")
    for off in range(dyn[2], dyn[2] + dyn[3], step):
        tag, val = struct.unpack_from(fmt, data, off)
        if tag == 0:
            break
        if tag == 1:  # DT_NEEDED
            end_i = strtab.find(b"\0", val)
            out.append(strtab[val:end_i].decode("utf-8", "replace"))
    return out


if __name__ == "__main__":
    for p in sys.argv[1:]:
        try:
            n = needed(p)
        except Exception as e:  # noqa: BLE001
            n = [f"HATA: {e}"]
        print(f"=== {p.split('/')[-1]} ===")
        if n is None:
            print("  ELF degil")
            continue
        hits = [x for x in n if "composer3" in x or "camera." in x or "graphics" in x]
        for x in (hits or n[:6]):
            print("  ", x)
