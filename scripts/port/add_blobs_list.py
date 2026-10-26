#!/usr/bin/env python3
"""Add prebuilt shared libs from the phone dump, listed in a TSV file.

TSV columns: <path in dump> <module name> <odm|vendor|system_ext> [relative_install_path]
The file is copied to proprietary/<path> (system/ paths go to system_ext/) and a
cc_prebuilt_library_shared block with empty shared_libs is appended; run
elf_needed_fix.py afterwards to fill dependencies.
Usage: add_blobs_list.py <dump_dir> <vendor_tree> <list.tsv> [--apply]
"""
import os
import shutil
import sys

dump, tree, listf = sys.argv[1:4]
apply = "--apply" in sys.argv
PART = {"vendor": "    soc_specific: true,", "odm": "    device_specific: true,",
        "system_ext": "    system_ext_specific: true,"}

bp_path = os.path.join(tree, "Android.bp")
bp = open(bp_path).read()
blocks, copies = [], []
for line in open(listf):
    f = line.split()
    if not f or f[0].startswith("#"):
        continue
    src, name, part = f[:3]
    rel = f[3] if len(f) > 3 else None
    dst = src if not src.startswith("system/") else "system_ext/" + src.split("/", 1)[1]
    s, d = os.path.join(dump, src), os.path.join(tree, "proprietary", dst)
    if not os.path.isfile(s):
        sys.exit(f"missing in dump: {src}")
    if f'name: "{name}",' in bp:
        sys.exit(f"module exists: {name}")
    if os.path.exists(d):
        sys.exit(f"refusing to overwrite: {dst}")
    stem = os.path.basename(dst)[:-3]
    lines = ["cc_prebuilt_library_shared {", f'    name: "{name}",']
    if stem != name:
        lines.append(f'    stem: "{stem}",')
    lines += ['    owner: "xiaomi",', "    strip: {", "        none: true,", "    },",
              "    target: {", "        android_arm64: {", "            srcs: [",
              f'                "proprietary/{dst}",', "            ],",
              "            shared_libs: [", "            ],", "        },", "    },",
              '    compile_multilib: "64",']
    if rel:
        lines.append(f'    relative_install_path: "{rel}",')
    lines += [PART[part], "}"]
    blocks.append("\n".join(lines))
    copies.append((s, d))
    print(f"add {part:10s} {name}  <- {src}")
if apply:
    for s, d in copies:
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy2(s, d)
    open(bp_path, "w").write(bp.rstrip("\n") + "\n\n" + "\n\n".join(blocks) + "\n")
    print("APPLIED")
else:
    print("dry-run (use --apply)")
