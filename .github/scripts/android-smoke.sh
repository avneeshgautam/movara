#!/usr/bin/env bash
# Installs the APK on the CI emulator, launches it, and fails if the app is
# not still running ~30s later or logged a fatal exception. Errors are echoed
# as ::error:: annotations (readable without a GitHub login). Leaves a
# screenshot at smoke.png for the release page.
set -u
APK="$1"
PKG="com.avneesh.movara_app"

fail() {
  echo "::error::SMOKE_FAIL: $1"
  exit 1
}

adb install -r "$APK" || fail "adb install failed"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 30

pid=$(adb shell pidof "$PKG" | tr -d '\r')
crash=$(adb logcat -d | grep -A15 "FATAL EXCEPTION")
adb exec-out screencap -p > smoke.png || true

if [ -z "$pid" ] || [ -n "$crash" ]; then
  detail=$(printf '%s' "$crash" | grep -E "FATAL|Exception|Error|Caused by|	at " \
    | head -15 | tr '\n' '|' | cut -c1-3500)
  fail "app not running after launch (pid='${pid}'). ${detail}"
fi
echo "Smoke test passed: $PKG running as pid $pid"
