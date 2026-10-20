#!/usr/bin/env bash
set -euo pipefail

device_dump="$(adb shell dumpsys media.audio_policy)"
music_group="$(printf '%s\n' "$device_dump" | awk '
    /-(AUDIO_STREAM_MUSIC|music) \(id:/ { in_music = 1 }
    /-(AUDIO_STREAM_SYSTEM|system) \(id:/ { in_music = 0 }
    in_music { print }
')"

if ! grep -Eq 'DEVICE_CATEGORY_SPEAKER[[:space:]]*:[[:space:]]*\{' <<<"$music_group"; then
    echo "FAIL: active MUSIC volume group has no speaker attenuation curve" >&2
    exit 1
fi

echo "PASS: active MUSIC volume group has a speaker attenuation curve"
