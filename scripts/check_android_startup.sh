#!/usr/bin/env bash
# Run after installing the release APK. Verifies native startup on a device.
# Set ANDROID_SERIAL when multiple devices are connected.
set -euo pipefail

package=com.vineetsarpal.autodentifyr
adb shell am force-stop "$package"
adb shell am start -W -n "$package/.MainActivity"
sleep 5

app_pid=$(adb shell pidof "$package" | tr -d '\r' || true)
if [[ -z "$app_pid" ]]; then
  echo "FAIL: App exited during startup. Inspect adb logcat -b crash."
  exit 1
fi

echo "PASS: App remains running after startup (PID $app_pid)."
