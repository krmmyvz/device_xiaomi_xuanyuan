# xuanyuan Live-Fix ROM Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax. Preserve the user's existing multi-repository checkout.

**Goal:** Build a ROM containing the verified live fixes, without relying on adb scratch overlays for their installation.
**Architecture:** Audit live files against stock303, device-owned configuration and source-built modules. Integrate only justified differences, then build and inspect packaged output. Deployment and Magisk boot verification remain separate, explicitly approved phases.
**Tech Stack:** ADB, WSL Ubuntu, Android Soong/Make, Python and Node test scripts.
**Spec:** ../../../tests/ROM-LIVE-INTEGRATION-SPEC.md

## Global Constraints

- Existing checkout: /home/user/rom/xuanyuan; retain unrelated dirty changes.
- 303 blobを維持する。
- 参照repo xiaomi-8750/android_device_xiaomi_xuanyuan は参考専用で、絶対にコピー・cherry-pick・置換しない。
- No device flash/reboot/data wipe/scratch removal in this plan.
- No failed Magisk experiments in ROM prebuilts; no pre-rooted release by default.
- No broad cleanup or automatic commits of existing dirty files.

## Review Focus

- Leftover experimental libraries/configs: exclude unless their active dependency and provenance are verified (Task 1).
- ELF fixups: distinguish changed code from SONAME/DT_NEEDED relocation; validate dependency ownership, not just whole-file hashes (Tasks 1–2).
- Source-built outputs: verify install path and runtime ABI, not identical compiler-dependent hashes (Tasks 1–3).
- Incomplete build/log pipeline: preserve failure exit status and reject stale artifacts (Task 3).
- Persisted scratch overlays: document that later deployment needs separately approved backup/deactivation; never call the current device OverlayFS-free (Task 3).

### Task 1: Live-file ownership audit

**Files:** Create tests/ROM-LIVE-INTEGRATION-AUDIT.md; inspect device.mk, Android.bp, extract-files.py, proprietary-files.txt, configs/, and affected system/core changes.
**Interfaces:** Consumes device upper-file inventory and current working tree. Produces a table of live path, source/build owner, evidence, required action or exclusion reason.

- [ ] Capture scratch upper-file paths and hashes without modifying the device.
- [ ] Map every live file, including libprocessgroup, camera provider/heap compatibility, RRO, UDFPS and Wi-Fi dependencies.
- [ ] Check stock303 `.text` and ELF dependencies for metadata-only differences; classify disabled backups and experimental files explicitly.
- [ ] Verify restored overlay_remounter source is unchanged and failed images have no install rule.
- [ ] Completion: all inventory rows are owned or excluded; unresolved active dependencies block integration rather than being copied blindly.

### Task 2: Close verified build-tree gaps

**Files:** Modify only owners identified by Task 1; existing tests/camera-hdr-graph-test.mjs, tests/test_gapps_sideload_layout.py and relevant source/build checks are verification gates.
**Interfaces:** Consumes the ownership audit. Produces auditable source/config changes and passing pre-build tests.

- [ ] For each actual gap, record a failing ownership/dependency/config check before changing its owner.
- [ ] Integrate the smallest verified fix; keep original 303 code and permitted ELF fixups. Do not copy inactive live experiments into the build.
- [ ] Run `python3 device/xiaomi/xuanyuan/tests/test_gapps_sideload_layout.py` (expected: 2 tests, OK) and `node device/xiaomi/xuanyuan/tests/camera-hdr-graph-test.mjs device/xiaomi/xuanyuan/configs/camera/satsnapshot-hdr-compatible.json` (expected: PASS, 45 nodes/64 links).
- [ ] Run relevant ABI/config checks and `git diff --check` in each modified repository.
- [ ] Completion: checks pass, required live fixes have install rules, experimental Magisk changes remain excluded. Record diffs/hashes; leave unrelated dirty work untouched.

### Task 3: Build and inspect fresh ROM artifacts

**Files:** Create scripts/build-integrated-rom.sh and tests/ROM-LIVE-INTEGRATION-BUILD.md. Output under out/target/product/xuanyuan, log under /tmp.
**Interfaces:** Consumes the audited tree and pre-build checks. Produces fresh ROM/target-files artifacts, SHA256 values, build result and deployment prerequisites.

- [ ] Confirm no active Ninja/Soong build and sufficient disk/RAM. Use existing lineage_xuanyuan-bp4a-userdebug configuration.
- [ ] Launcher uses `set -e -o pipefail`, envsetup/lunch and `m bacon -j2`, with a unique log. Do not use the old tee pipeline's status as build success.
- [ ] Observe meaningful progress/errors; repair only evidenced in-scope build failures. No full clean.
- [ ] Verify build exit status, artifact freshness and package ownership for camera, audio, fingerprint, Wi-Fi, ext4 targets and vendor_boot fstab.
- [ ] Verify normal init/stock boot components are packaged, not either failed Magisk candidate or the remounter bypass.
- [ ] Completion: report build/inspection evidence. Do not flash. Prepare a separately approved, backed-up deployment plan that removes dependence on stale scratch overlays before any Magisk success claim.
