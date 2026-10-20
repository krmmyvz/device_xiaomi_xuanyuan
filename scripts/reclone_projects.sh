#!/usr/bin/env bash
# Bozuk AOSP projelerini dogrudan yeniden klonlar.
#
# SORUN
# -----
# 'repo sync --force-sync' sirasinda .repo/projects/<path>.git bare
# repo'su bos/yarim kaldiginda repo o projeyi yeniden kuramaz:
#
#   GitCommandError: 'fetch ... aosp ...' on platform/hardware/google/av failed
#   stdout: fatal: not a git repository:
#           '/mnt/src/.repo/projects/hardware/google/av.git'
#
# Bu script bare repo'yu ve calisma agacini temizleyip projeyi DOGRUDAN
# klonlar. 'repo' manifestindeki revision'a gore checkout eder.
#
# Kullanim: bash reclone_projects.sh <project-path> [<project-path> ...]
set -uo pipefail

AOSP="${AOSP_ROOT:-/mnt/src}"
MANIFEST="$AOSP/.repo/manifests/default.xml"
LOCAL_MANIFEST="$AOSP/.repo/local_manifests/local_manifests.xml"

log() { printf '[+] %s\n' "$*"; }
ok()  { printf '[✓] %s\n' "$*"; }
err() { printf '[✗] %s\n' "$*" >&2; }

[ $# -ge 1 ] || { err "kullanim: $0 <project-path> [...]"; exit 1; }

for p in "$@"; do
  log "--- $p ---"
  d="$AOSP/$p"
  [ -d "$d" ] && rm -rf "$d"
  rm -rf "$AOSP/.repo/projects/$p.git" "$AOSP/.repo/project-objects/$p.git" 2>/dev/null

  # Manifest'ten remote + revision bilgisini al.
  # Remotes pinned manifestte degil, local_manifests.xml'de yasar; bu
  # yuzden IKI manifest birlikte okunur.
  remote=$(python3 - "$MANIFEST" "$LOCAL_MANIFEST" "$p" <<'PY'
import sys, xml.etree.ElementTree as ET
mpath, lpath, want = sys.argv[1], sys.argv[2], sys.argv[3]
remotes = {}
projects = []
for path in (mpath, lpath):
    try:
        root = ET.parse(path).getroot()
    except Exception:
        continue
    for r in root.findall("remote"):
        remotes[r.get("name")] = (r.get("fetch") or "").rstrip("/")
    projects.extend(root.findall("project"))
# default remote: fetch=".." -> repo init'in cozdugu base (github.com)
base = "https://github.com"
for pr in projects:
    if pr.get("path") == want:
        rn = pr.get("remote")
        fetch = remotes.get(rn, "") if rn else ""
        if fetch == "..":
            fetch = base
        if not fetch:
            fetch = base
        print(f"{fetch}/{pr.get('name')}\t{pr.get('revision')}\t{pr.get('name')}")
        break
PY
)
  if [ -z "$remote" ]; then err "manifest'te yok: $p"; continue; fi
  url=$(echo "$remote" | cut -f1)
  rev=$(echo "$remote" | cut -f2)
  name=$(echo "$remote" | cut -f3)
  log "  url=$url rev=$rev"

  git_url="$url"
  case "$url" in
    https://github.com/*) git_url="${url}.git" ;;
  esac

  mkdir -p "$(dirname "$d")"
  if ! git clone --quiet --no-checkout "$git_url" "$d" 2>&1 | tail -3; then
    err "klon basarisiz: $git_url"; continue
  fi

  git -C "$d" fetch --quiet --depth=1 origin "$rev" 2>/dev/null \
    || git -C "$d" fetch --quiet origin 2>/dev/null
  if ! git -C "$d" checkout --quiet "$rev" 2>/dev/null; then
    git -C "$d" checkout --quiet FETCH_HEAD 2>/dev/null || {
      err "checkout basarisiz: $rev"; continue; }
  fi

  sz=$(stat -c %s "$d/Android.bp" 2>/dev/null || echo "-")
  ok "$p hazir (HEAD=$(git -C "$d" rev-parse --short HEAD 2>/dev/null), Android.bp=${sz}B)"
done
