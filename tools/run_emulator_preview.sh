#!/usr/bin/env bash
# Run from the normal desktop terminal, where Flutter, Gradle, and ADB can work.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
cd -- "$project_dir"

flutter_bin="$(command -v flutter || true)"
if [[ -z "$flutter_bin" ]]; then
  flutter_sdk="$(sed -n 's/^flutter\.sdk=//p' android/local.properties)"
  flutter_bin="$flutter_sdk/bin/flutter"
fi
if [[ ! -x "$flutter_bin" ]]; then
  printf 'Flutter was not found. Add your Flutter SDK to PATH and try again.\n' >&2
  exit 1
fi
dart_bin="$(dirname -- "$flutter_bin")/dart"

adb_bin="$(command -v adb || true)"
if [[ -z "$adb_bin" ]]; then
  android_sdk="$(sed -n 's/^sdk\.dir=//p' android/local.properties)"
  adb_bin="$android_sdk/platform-tools/adb"
fi
if [[ ! -x "$adb_bin" ]]; then
  printf 'ADB was not found. Add Android platform-tools to PATH and try again.\n' >&2
  exit 1
fi

device_listing="$("$adb_bin" devices -l)"
if [[ $# -gt 1 ]]; then
  printf 'Usage: bash tools/run_emulator_preview.sh [emulator-serial]\n' >&2
  exit 1
fi
if [[ $# -eq 1 ]]; then
  emulator_serial="$1"
else
  mapfile -t emulator_ids < <(printf '%s\n' "$device_listing" | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1 }')
  if [[ ${#emulator_ids[@]} -ne 1 ]]; then
    printf '%s\n' "$device_listing"
    printf 'Start one emulator, or specify its serial: bash tools/run_emulator_preview.sh emulator-5554\n' >&2
    exit 1
  fi
  emulator_serial="${emulator_ids[0]}"
fi
"$adb_bin" -s "$emulator_serial" get-state

output_dir="$project_dir/build/emulator-preview/$(date +%Y%m%d-%H%M%S)"
mkdir -p -- "$output_dir"
exec > >(tee "$output_dir/run.log") 2>&1
printf 'Testing and launching Xenn Do on %s\n' "$emulator_serial"

if [[ ! -f .dart_tool/package_config.json ]]; then
  "$flutter_bin" pub get
fi
"$dart_bin" format --output=none --set-exit-if-changed lib test
"$flutter_bin" analyze --no-pub
"$flutter_bin" test --no-pub --concurrency=1
"$flutter_bin" build apk --debug --no-pub

# A replacement install retains the emulator's existing app database/settings.
"$adb_bin" -s "$emulator_serial" install -r build/app/outputs/flutter-apk/app-debug.apk
app_id="$(sed -n 's/^[[:space:]]*applicationId = "\([^"]*\)".*/\1/p' android/app/build.gradle.kts)"
if [[ -z "$app_id" ]]; then
  printf 'Could not determine the Android application ID.\n' >&2
  exit 1
fi
"$adb_bin" -s "$emulator_serial" shell am start -W -n "$app_id/.MainActivity"
sleep 2
if "$adb_bin" -s "$emulator_serial" exec-out screencap -p > "$output_dir/today.png"; then
  printf 'Launched. Screenshot: %s/today.png\n' "$output_dir"
else
  printf 'Launched, but the screenshot could not be captured.\n' >&2
fi
printf 'Log: %s/run.log\n' "$output_dir"
