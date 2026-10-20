#!/usr/bin/env bash
set -euo pipefail
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER="${1:-$TEST_DIR/../scripts/build-integrated-rom.sh}"
for scenario in '7 0 7' '0 9 9' '0 0 0'; do
    read -r builder logger expected <<< "$scenario"
    set +e
    result=$(BASH_ENV="$TEST_DIR/build_launcher_mock_env.sh" MOCK_M_EXIT="$builder" MOCK_TEE_EXIT="$logger" bash "$LAUNCHER" 2>&1)
    actual=$?
    set -e
    if [ "$actual" -ne "$expected" ]; then
        printf 'FAIL: builder=%s logger=%s expected=%s actual=%s\n' "$builder" "$logger" "$expected" "$actual"
        exit 1
    fi
done
echo 'PASS: build and log failures propagate; success returns zero'
