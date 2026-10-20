#!/usr/bin/env bash
# HIZLI bozuk proje tespiti.
#
# Tarama yontemi: her projenin kok dizininde "build girdisi" olan dosyalar
# (Android.bp, Android.mk, *.mk) var mi, ve bos mu? 0 byte olanlar NAS
# baglantisi kesintisi sirasinda yarim yazilmis demektir.
#
# fsck'ten cok daha hizlidir ve build'i gercekten bozan durumlari
# (eksik/bozuk Android.bp) yakalar.
#
# Kullanim: bash find_broken.sh [cikti_dosyasi]
set -uo pipefail
AOSP="${AOSP_ROOT:-/mnt/src}"
OUT="${1:-/tmp/broken_projects.txt}"

cd "$AOSP" || exit 1
repo list 2>/dev/null | cut -d: -f1 > /tmp/all_projects.txt

: > "$OUT"
TOTAL=0
BROKEN=0
while read -r p; do
  [ -z "$p" ] && continue
  TOTAL=$((TOTAL+1))
  d="$AOSP/$p"
  [ -d "$d" ] || { echo "$p" >> "$OUT"; BROKEN=$((BROKEN+1)); continue; }
  # Kok seviyede build girdisi dosyalarina bak
  bad=0
  for f in "$d"/*.bp "$d"/*.mk; do
    [ -f "$f" ] || continue
    if [ ! -s "$f" ]; then bad=1; break; fi
  done
  # Ust dizin Android.bp bos mu (namespace tanimlari orada)
  if [ "$bad" = 0 ] && [ -d "$d" ]; then
    for sub in "$d"/*/; do
      [ -f "${sub}Android.bp" ] || continue
      [ -s "${sub}Android.bp" ] || { bad=1; break; }
    done
  fi
  if [ "$bad" = 1 ]; then
    echo "$p" >> "$OUT"
    BROKEN=$((BROKEN+1))
  fi
done < /tmp/all_projects.txt

echo "toplam proje: $TOTAL"
echo "bozuk proje: $BROKEN"
echo "liste: $OUT"
head -40 "$OUT"
