#!/usr/bin/env python3
"""Reconcile vendor/xiaomi/xuanyuan prebuilt shared_libs with blob DT_NEEDED.

Mimics Soong's check_elf_file: every DT_NEEDED of a checked prebuilt must be
the output filename of one of its shared_libs deps. For each unmet entry:
  1. a platform module whose variant for the module's partition produces that
     file (from the ninja target list) is added,
  2. else a vendor-tree module of the same image (vendor/odm vs system) whose
     stem/name produces that file is added,
  3. else the module gets check_elf_files: false (blob missing from the dump).
A dep producing a different version of the same AIDL interface
(<base>-V<n>-ndk) that the blob does not need is dropped.

Usage: elf_needed_fix.py <Android.bp> <so_targets.txt> <readobj> [--apply]
"""
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict

bp_path, targets_path, readobj = sys.argv[1:4]
apply = "--apply" in sys.argv
root = os.environ.get("VROOT") or os.path.dirname(bp_path)

SYSTEM_LIBS = {"libc.so", "libm.so", "libdl.so"}
# Platform modules that must not be picked (e.g. unfrozen aidl versions).
EXCLUDE_PLATFORM = set(filter(None, os.environ.get("EXCLUDE_PLATFORM", "").split(",")))
VARIANT = {"vendor": "android_vendor_arm64_armv8-a_shared",
           "system": "android_arm64_armv8-a_shared",
           "product": "android_product_arm64_armv8-a_shared"}

# platform: (variant, filename) -> module name; skip vendor-tree outputs.
platform = {}
platform_file = {}
for t in open(targets_path):
    t = t.strip()
    if "/vendor/xiaomi/xuanyuan/" in t:
        continue
    parts = t.split("/")
    if len(parts) < 4:
        continue
    fname, variant, module = parts[-1], parts[-2], parts[-3]
    platform.setdefault((variant, fname), module)
    platform_file.setdefault((variant, module), fname)

text = open(bp_path).read()
lines = text.split("\n")

# Split into top-level blocks: [start, end] inclusive.
blocks = []
start = None
for i, l in enumerate(lines):
    if re.match(r"^[a-z_]+ \{", l):
        start = i
    elif l == "}" and start is not None:
        blocks.append((start, i))
        start = None


def prop(block_lines, key):
    for l in block_lines:
        m = re.match(r'^    %s: "?([^",]+)"?,' % key, l)
        if m:
            return m.group(1)
    return None


def image_of(bl):
    s = "\n".join(bl)
    if "system_ext_specific: true" in s:
        return "system"
    if "product_specific: true" in s:
        return "product"
    if re.search(r"soc_specific: true|device_specific: true|vendor: true|proprietary: true", s):
        return "vendor"
    return "system"


modules = {}  # name -> dict
for s, e in blocks:
    bl = lines[s:e + 1]
    if not bl[0].startswith("cc_prebuilt_"):
        continue
    name = prop(bl, "name")
    if not name:
        continue
    stem = prop(bl, "stem") or name
    modules[name] = {"range": (s, e), "image": image_of(bl),
                     "file": stem + (".so" if bl[0].startswith("cc_prebuilt_library") else ""),
                     "kind": bl[0].split()[0]}

# vendor-tree: (image_group, filename) -> module
tree = defaultdict(list)
for n, m in modules.items():
    grp = "vendor" if m["image"] == "vendor" else "system"
    tree[(grp, m["file"])].append(n)


def dep_file(dep, image):
    """Output filename a dep name resolves to for a module on `image`."""
    if dep.startswith("//"):
        dep = dep.split(":", 1)[1]
    if dep in modules:
        return modules[dep]["file"]
    f = platform_file.get((VARIANT[image], dep))
    if f is None and image == "product":
        f = platform_file.get((VARIANT["system"], dep))
    return f or dep + ".so"


def needed(path):
    try:
        out = subprocess.run([readobj, "--needed-libs", path], capture_output=True,
                             text=True, timeout=30).stdout
    except Exception:
        return None
    res, inside = [], False
    for l in out.splitlines():
        l = l.strip()
        if l.startswith("NeededLibraries ["):
            inside = True
        elif inside and l == "]":
            break
        elif inside and l:
            res.append(l)
    return res


aidl_base = re.compile(r"^(.*)-V\d+-ndk(_vendor|_platform)?$")

edits = {}      # line index -> new content (None = delete)
inserts = defaultdict(list)  # line index -> lines to insert after
report = Counter()
unresolved = defaultdict(set)
changed_modules = []

for name, m in modules.items():
    s, e = m["range"]
    bl = lines[s:e + 1]
    btxt = "\n".join(bl)
    if "check_elf_files: false" in btxt or not m["kind"].startswith("cc_prebuilt_library") and m["kind"] != "cc_prebuilt_binary":
        continue
    # find srcs / shared_libs pairs for arm64
    i = s
    while i <= e:
        if lines[i].strip() == "android_arm64: {":
            j = i
            src = None
            sl_open = sl_close = None
            depth = 0
            while j <= e:
                l = lines[j]
                depth += l.count("{") - l.count("}")
                if src is None:
                    mm = re.match(r'^\s+"(proprietary/[^"]+)",', l)
                    if mm:
                        src = mm.group(1)
                if re.match(r"^\s+shared_libs: \[", l):
                    sl_open = j
                    k = j
                    while not lines[k].strip().startswith("]"):
                        k += 1
                    sl_close = k
                if depth == 0 and j > i:
                    break
                j += 1
            if src and sl_open is not None:
                need = needed(os.path.join(root, src))
                if need is None:
                    break
                deps = []
                for k in range(sl_open + 1, sl_close):
                    mm = re.match(r'^\s+"([^"]+)",', lines[k])
                    if mm:
                        deps.append((k, mm.group(1)))
                have = {dep_file(d, m["image"]): (k, d) for k, d in deps}
                variant = VARIANT[m["image"]]
                grp = "vendor" if m["image"] == "vendor" else "system"
                adds = []
                for so in need:
                    if so in SYSTEM_LIBS or so in have:
                        continue
                    cand = platform.get((variant, so))
                    if cand is None and m["image"] == "product":
                        cand = platform.get((VARIANT["system"], so))
                    if cand in EXCLUDE_PLATFORM:
                        cand = None
                    if cand is None:
                        tc = [t for t in tree.get((grp, so), []) if t != name]
                        cand = tc[0] if tc else None
                    if cand is None:
                        unresolved[name].add(so)
                        continue
                    if cand in [d for _, d in deps] or cand in adds:
                        continue
                    adds.append(cand)
                    report["added"] += 1
                    # drop other versions of the same AIDL interface
                    b = aidl_base.match(so[:-3])
                    if b:
                        for k, d in deps:
                            f = dep_file(d, m["image"])
                            bd = aidl_base.match(f[:-3]) if f.endswith(".so") else None
                            if bd and bd.group(1) == b.group(1) and f not in need:
                                edits[k] = None
                                report["dropped_other_version"] += 1
                indent = re.match(r"^(\s+)", lines[sl_open]).group(1) + "    "
                if adds:
                    inserts[sl_open].extend(f'{indent}"{a}",' for a in adds)
                    changed_modules.append((name, adds))
            i = j
        i += 1
    if name in unresolved:
        # add check_elf_files: false right after the name line
        for k in range(s, e + 1):
            if lines[k].startswith("    name: "):
                inserts[k].append("    check_elf_files: false,")
                report["elf_check_disabled"] += 1
                break

print("summary:", dict(report))
print("\n== modules gaining deps (%d)" % len(changed_modules))
for n, a in changed_modules:
    print(f"  {n}: +{', '.join(a)}")
print("\n== unresolved -> check_elf_files: false (%d modules)" % len(unresolved))
miss = Counter(so for v in unresolved.values() for so in v)
for so, c in miss.most_common():
    print(f"  {c:3d} {so}")
for n in sorted(unresolved):
    print(f"  [{modules[n]['image']}] {n}: {', '.join(sorted(unresolved[n]))}")

if apply:
    out = []
    for i, l in enumerate(lines):
        if edits.get(i, l) is not None:
            out.append(l)
        out.extend(inserts.get(i, []))
    open(bp_path, "w").write("\n".join(out))
    print("APPLIED")
else:
    print("dry-run (use --apply)")
