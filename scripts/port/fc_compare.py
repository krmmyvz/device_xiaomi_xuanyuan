#!/usr/bin/env python3
"""Compare phone SELinux labels of vendor/odm executables with our build's file_contexts.

Lookup approximates libselinux: exact entries win; otherwise the matching regex
with the longest literal prefix (later entry on ties).
Usage: fc_compare.py <phone_labels.txt> <product_out>
"""
import os
import re
import sys

labels_path, out = sys.argv[1], sys.argv[2]
specs = []
for f in ["vendor/etc/selinux/vendor_file_contexts", "odm/etc/selinux/odm_file_contexts"]:
    for line in open(os.path.join(out, f)):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        path, ctx = parts[0], parts[-1]
        if len(parts) == 3 and parts[1] not in ("--", "-f"):
            continue
        lit = re.match(r"[^.^$?*+|\[\](){}\\]*", path).group(0)
        meta = lit != path
        try:
            specs.append((re.compile("^" + path + "$"), meta, len(lit), ctx))
        except re.error:
            pass


def lookup(p):
    best = None
    for i, (rx, meta, plen, ctx) in enumerate(specs):
        if rx.match(p):
            key = (0 if meta else 1, plen, i)
            if best is None or key >= best[0]:
                best = (key, ctx)
    return best[1] if best else "NOMATCH"


def t(ctx):
    return ctx.split(":")[2] if ctx.count(":") >= 3 else ctx


mism = []
for line in open(labels_path):
    ctx, path = line.split()
    if not os.path.isfile(os.path.join(out, path.lstrip("/"))):
        continue
    ours = lookup(path)
    if t(ours) != t(ctx):
        mism.append((path, t(ctx), t(ours)))
generic = [m for m in mism if m[2] in ("vendor_file", "NOMATCH")]
print(f"mismatch {len(mism)}  (generic vendor_file/NOMATCH: {len(generic)})")
for p, ph, us in sorted(mism):
    print(f"{p}\tphone={ph}\tours={us}")
