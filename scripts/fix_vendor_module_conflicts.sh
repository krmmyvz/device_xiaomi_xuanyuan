#!/usr/bin/env bash
# vendor/xiaomi/xuanyuan: cakisan modul isimlerinin duzeltilmesi.
#
# SORUN
# -----
# vendor/xiaomi/xuanyuan/Android.bp (Xiaomi'nin public vendor reposundan,
# "Automatically generated") icinde "libQnnSaver" iki kez tanimli:
#
#   cc_prebuilt_library_shared { name: "libQnnSaver", ... }   -> cc.Module
#   prebuilt_rfsa             { name: "libQnnSaver", ... }   -> etc.PrebuiltEtc
#
# (AOSP'nin kendi tanimi: build/soong/etc/prebuilt_etc.go ->
#  ctx.RegisterModuleType("prebuilt_rfsa", PrebuiltRFSAFactory))
#
# Ayni isim iki farkli modul tipinde olunca Soong'un prebuilt_select
# mutator'i birini digerine cast etmeye calisiyor ve PANIC veriyor:
#
#   internal error: panic in VisitDirectDeps(module "libQnnSaver" ...)
#   interface conversion: android.Module is *etc.PrebuiltEtc, not *cc.Module
#
# COZUM
# -----
# prebuilt_rfsa bloğundaki modul adini benzersizlestirir. "filename"
# ve "src" degismez - yani RFSA firmware'i adsp partition'ina AYNI
# dosya adiyla kopyalanir, sadece Soong modul adi farkli olur.
#
# Not: bu upstream vendor reposunun kendi hatasidir; iki blok da upstream
# dosyasinda aynen mevcuttur.
#
# Idempotenttir.
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
TARGET="$AOSP/vendor/xiaomi/xuanyuan/Android.bp"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ -f "$TARGET" ] || { err "bulunamadi: $TARGET"; exit 1; }

python3 - "$TARGET" <<'PY'
import re, sys, collections

p = sys.argv[1]
txt = open(p).read()

# Her modul blogunu (tip, ad, govde) olarak cikar.
# Govde, blok acilisindan sonraki karsilik gelen "}"a kadardir.
blocks = []
for m in re.finditer(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*\{', txt, re.M):
    typ = m.group(1)
    start = m.end()
    depth = 1
    i = start
    while i < len(txt) and depth > 0:
        if txt[i] == '{':
            depth += 1
        elif txt[i] == '}':
            depth -= 1
        i += 1
    body = txt[start:i]
    nm = re.search(r'name:\s*"([^"]+)"', body)
    if nm:
        blocks.append((typ, nm.group(1), m.start(), i))

counts = collections.Counter(n for _, n, _, _ in blocks)
dupes = {n for n, c in counts.items() if c > 1}

# Duzeltmeleri en sondan basa dogru uygula (offsetler kaymasin).
edits = []
for name in sorted(dupes):
    same = [(typ, s, e) for typ, n, s, e in blocks if n == name]
    types = {t for t, _, _ in same}
    if "prebuilt_rfsa" not in types:
        continue
    for typ, s, e in same:
        if typ != "prebuilt_rfsa":
            continue
        new_name = name + "_rfsa"
        body = txt[s:e]
        new_body = re.sub(r'(name:\s*)"[^"]+"',
                          lambda m2: m2.group(1) + '"' + new_name + '"',
                          body, count=1)
        edits.append((s, e, new_body))
        print("[+] prebuilt_rfsa '%s' -> '%s'" % (name, new_name))

if edits:
    for s, e, new_body in sorted(edits, reverse=True):
        txt = txt[:s] + new_body + txt[e:]
    open(p, "w").write(txt)
    print("[✓] %d blok yeniden adlandirildi" % len(edits))
else:
    print("[✓] prebuilt_rfsa cakismasi yok")
PY

log "tamamlandi"
