#!/usr/bin/env python3
"""List cc_prebuilt_library_shared modules whose output name != blob DT_SONAME."""
import os, re, subprocess, sys
bp, root, readobj = sys.argv[1:4]
txt = open(bp).read()
for blk in re.findall(r"^cc_prebuilt_library_shared \{\n(.*?)\n\}", txt, re.S | re.M):
    if "check_elf_files: false" in blk:
        continue
    name = re.search(r'^    name: "([^"]+)"', blk, re.M).group(1)
    st = re.search(r'^    stem: "([^"]+)"', blk, re.M)
    out = (st.group(1) if st else name) + ".so"
    src = re.search(r'"(proprietary/[^"]+\.so)"', blk)
    if not src:
        continue
    d = subprocess.run([readobj, "--dynamic-table", os.path.join(root, src.group(1))],
                       capture_output=True, text=True).stdout
    m = re.search(r"SONAME\s+Library soname: \[([^\]]+)\]", d)
    if m and m.group(1) != out:
        print(f"{name}\tout={out}\tsoname={m.group(1)}\tstem={'yes' if st else 'no'}")
