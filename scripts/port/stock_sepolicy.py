#!/usr/bin/env python3
"""Ship the phone's stock vendor/odm SELinux policy instead of the AOSP-built one.

1. Copies stock vendor+odm selinux files from the phone dump into
   vendor/xiaomi/xuanyuan/sepolicy-stock/ (+ labels for our extra services)
   and writes filegroups for them.
2. system/sepolicy: renames the AOSP vendor/odm policy modules to "<name>.aosp"
   and appends prebuilt_etc modules with the original names that install the
   stock files, so install, file_contexts.bin and precompiled_sepolicy all use them.
3. build/make/core/config.mk: lets BOARD_SEPOLICY_VERS_OVERRIDE set the vendor
   sepolicy version (stock vendor policy is 202404).
Usage: stock_sepolicy.py <dump_dir> <src_root> [--apply]
"""
import os
import re
import shutil
import sys

dump, top = sys.argv[1], sys.argv[2]
apply = "--apply" in sys.argv
stock_dir = os.path.join(top, "vendor/xiaomi/xuanyuan/sepolicy-stock")

# module name -> (partition, stock file, Android.bp holding the AOSP module)
MODULES = {
    "plat_pub_versioned.cil": ("vendor", "plat_pub_versioned.cil", "Android.bp"),
    "vendor_sepolicy.cil": ("vendor", "vendor_sepolicy.cil", "Android.bp"),
    "plat_sepolicy_vers.txt": ("vendor", "plat_sepolicy_vers.txt", "Android.bp"),
    "odm_sepolicy.cil": ("odm", "odm_sepolicy.cil", "Android.bp"),
    "vendor_file_contexts": ("vendor", "vendor_file_contexts", "contexts/Android.bp"),
    "vendor_hwservice_contexts": ("vendor", "vendor_hwservice_contexts", "contexts/Android.bp"),
    "vendor_property_contexts": ("vendor", "vendor_property_contexts", "contexts/Android.bp"),
    "vendor_service_contexts": ("vendor", "vendor_service_contexts", "contexts/Android.bp"),
    "vendor_keystore2_key_contexts": ("vendor", "vendor_keystore2_key_contexts", "contexts/Android.bp"),
    "vendor_seapp_contexts": ("vendor", "vendor_seapp_contexts", "contexts/Android.bp"),
    "vndservice_contexts": ("vendor", "vndservice_contexts", "contexts/Android.bp"),
    "odm_file_contexts": ("odm", "odm_file_contexts", "contexts/Android.bp"),
    "odm_hwservice_contexts": ("odm", "odm_hwservice_contexts", "contexts/Android.bp"),
    "odm_property_contexts": ("odm", "odm_property_contexts", "contexts/Android.bp"),
    "odm_service_contexts": ("odm", "odm_service_contexts", "contexts/Android.bp"),
    "odm_seapp_contexts": ("odm", "odm_seapp_contexts", "contexts/Android.bp"),
    "vendor_mac_permissions.xml": ("vendor", "vendor_mac_permissions.xml", "mac_permissions/Android.bp"),
    "odm_mac_permissions.xml": ("odm", "odm_mac_permissions.xml", "mac_permissions/Android.bp"),
}

# Services we install that the stock policy does not know about.
EXTRA_FC = """
# --- xuanyuan port additions (not present in stock OS4.0.0.6) ---
/(odm|vendor)/bin/hw/vibratorfeature-wrapper    u:object_r:hal_vibrator_default_exec:s0
/(vendor|system/vendor)/bin/hw/android\\.hardware\\.sensors-service\\.xiaomi-sm8750-multihal    u:object_r:hal_sensors_default_exec:s0
/(vendor|system/vendor)/bin/hw/android\\.hardware\\.biometrics\\.fingerprint-service\\.xiaomi    u:object_r:hal_fingerprint_default_exec:s0
"""


def fg(name):
    return "xuanyuan_stock_" + re.sub(r"[^A-Za-z0-9]", "_", name)


# 1. stock files + filegroups
bp_lines = ["// Stock OS4.0.0.6 vendor/odm SELinux policy (pulled from the device).",
            "// Consumed by system/sepolicy (see the xuanyuan platform patch)."]
for name, (part, f, _) in MODULES.items():
    src = os.path.join(dump, part, "etc/selinux", f)
    if not os.path.isfile(src):
        sys.exit(f"missing in dump: {part}/etc/selinux/{f}")
    bp_lines += ["", "filegroup {", f'    name: "{fg(name)}",', f'    srcs: ["{part}/{f}"],',
                 '    visibility: ["//system/sepolicy:__subpackages__"],', "}"]
print(f"stock files: {len(MODULES)} -> {stock_dir}")

# 2. system/sepolicy rename + replacements
sep = os.path.join(top, "system/sepolicy")
edits = {}
for name, (part, f, bpf) in MODULES.items():
    p = os.path.join(sep, bpf)
    s = edits.get(p) or open(p).read()
    old = f'    name: "{name}",\n'
    if s.count(old) != 1:
        sys.exit(f"{bpf}: expected one definition of {name}, found {s.count(old)}")
    edits[p] = s.replace(old, f'    name: "{name}.aosp",\n')
repl = ["", "// xuanyuan: vendor/odm policy comes from the stock device policy.",
        "// The AOSP-built modules are kept as <name>.aosp."]
for name, (part, f, _) in MODULES.items():
    repl += ["", "prebuilt_etc {", f'    name: "{name}",',
             f'    src: "//vendor/xiaomi/xuanyuan:{fg(name)}",', f'    filename: "{f}",',
             '    relative_install_path: "selinux",',
             "    vendor: true," if part == "vendor" else "    device_specific: true,", "}"]
top_bp = os.path.join(sep, "Android.bp")
edits[top_bp] = (edits.get(top_bp) or open(top_bp).read()).rstrip("\n") + "\n" + "\n".join(repl) + "\n"

# 3. config.mk override
cfg = os.path.join(top, "build/make/core/config.mk")
c = open(cfg).read()
old_c = "BOARD_SEPOLICY_VERS := $(PLATFORM_SEPOLICY_VERSION)\n"
new_c = ("# xuanyuan: stock vendor sepolicy is older than the platform (mixed build).\n"
         "BOARD_SEPOLICY_VERS := $(if $(BOARD_SEPOLICY_VERS_OVERRIDE),$(BOARD_SEPOLICY_VERS_OVERRIDE),$(PLATFORM_SEPOLICY_VERSION))\n")
if c.count(old_c) != 1:
    sys.exit("config.mk: BOARD_SEPOLICY_VERS line not found")
print("system/sepolicy files:", ", ".join(os.path.relpath(p, top) for p in edits))

if apply:
    for name, (part, f, _) in MODULES.items():
        d = os.path.join(stock_dir, part, f)
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy2(os.path.join(dump, part, "etc/selinux", f), d)
    with open(os.path.join(stock_dir, "vendor/vendor_file_contexts"), "a") as fh:
        fh.write(EXTRA_FC)
    open(os.path.join(stock_dir, "Android.bp"), "w").write("\n".join(bp_lines) + "\n")
    for p, s in edits.items():
        open(p, "w").write(s)
    open(cfg, "w").write(c.replace(old_c, new_c))
    print("APPLIED")
else:
    print("dry-run (use --apply)")
