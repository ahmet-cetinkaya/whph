#!/usr/bin/env bash
# Boots an Android emulator and blocks until it is ready to receive an app.
#
# Zed's Dart debug adapter cannot start an emulator itself: it resolves
# `deviceId` against the devices Flutter already sees, so an offline AVD makes
# the session abort with "Device ... not found". Running this first turns the
# AVD into a live device before the debugger looks for it.
#
# Idempotent: if an emulator is already booted, it returns immediately, so
# repeated debug sessions reuse the running instance instead of stacking AVDs.
#
# Usage: start_android_emulator.sh [avd_name]
#   avd_name  AVD to boot. Defaults to the first entry of `emulator -list-avds`.
set -euo pipefail

readonly BOOT_TIMEOUT_SECONDS=300
readonly POLL_INTERVAL_SECONDS=2

# The Android SDK is not on PATH inside every shell, so resolve the tools from
# the SDK root when the bare command is missing.
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"

resolve_tool() {
  local name="$1" sdk_relative_path="$2"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  local sdk_path="$sdk_root/$sdk_relative_path"
  if [[ -x "$sdk_path" ]]; then
    printf '%s\n' "$sdk_path"
    return 0
  fi
  printf 'error: %s not found on PATH or under %s\n' "$name" "$sdk_root" >&2
  return 1
}

ADB="$(resolve_tool adb platform-tools/adb)"
EMULATOR="$(resolve_tool emulator emulator/emulator)"

# A device that is merely "connected" is not usable yet: the system server keeps
# booting for a while after adb reports it. sys.boot_completed is the property
# that flips once the launcher is actually up.
is_device_booted() {
  local state
  state="$("$ADB" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || return 1
  [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]
}

if is_device_booted; then
  echo "Android device already booted; reusing it."
  "$ADB" devices
  exit 0
fi

avd_name="${1:-}"
if [[ -z "$avd_name" ]]; then
  avd_name="$("$EMULATOR" -list-avds | head -n 1)"
fi

if [[ -z "$avd_name" ]]; then
  echo "error: no AVD available. Create one in Android Studio's Device Manager," >&2
  echo "       or with: avdmanager create avd -n <name> -k \"system-images;android-34;google_apis;x86_64\"" >&2
  exit 1
fi

echo "Booting AVD '$avd_name'..."
# `setsid`, not just `nohup`: the emulator has to survive the task runner that
# started it. When Zed finishes a `build` step it terminates that step's process
# group, and a merely nohup'd child stays in that group - the emulator would die
# moments after this script reported success, leaving the debug session to fail
# with "device 'emulator-5554' not found". A new session detaches it for good.
setsid "$EMULATOR" -avd "$avd_name" -netdelay none -netspeed full \
  >/tmp/whph_emulator.log 2>&1 < /dev/null &
disown 2>/dev/null || true

echo "Waiting for the device to finish booting (timeout: ${BOOT_TIMEOUT_SECONDS}s)..."
deadline=$((SECONDS + BOOT_TIMEOUT_SECONDS))
until is_device_booted; do
  if ((SECONDS >= deadline)); then
    echo "error: emulator did not boot within ${BOOT_TIMEOUT_SECONDS}s." >&2
    echo "       See /tmp/whph_emulator.log for the emulator output." >&2
    exit 1
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done

echo "Emulator ready."
"$ADB" devices
