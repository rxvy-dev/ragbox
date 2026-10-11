#!/usr/bin/env bash
# Build the Ragbox release APK and install it on every Android device
# plugged in over USB (with USB debugging enabled).
#
#   ./build_install.sh              build + install on all connected devices
#   ./build_install.sh --no-install build only (APK ends up in dist/)
#   ./build_install.sh --test       run the unit tests first
#
# Requirements: Flutter SDK (stable, 3.27 or newer) with the Android toolchain
# set up (`flutter doctor` shows Android toolchain OK), and adb on PATH or in
# $ANDROID_HOME/platform-tools.
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=1
TESTS=0
for arg in "$@"; do
  case "$arg" in
    --no-install) INSTALL=0 ;;
    --test) TESTS=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

red() { printf '\033[1;31m%s\033[0m\n' "$*"; }
info() { printf '\033[1;37m==> %s\033[0m\n' "$*"; }

if ! command -v flutter >/dev/null 2>&1; then
  red "Flutter SDK not found on PATH."
  echo "Install it from https://docs.flutter.dev/get-started/install/linux/android"
  echo "then run 'flutter doctor --android-licenses' and try again."
  exit 1
fi

ADB="$(command -v adb || true)"
if [ -z "$ADB" ]; then
  for c in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk"; do
    if [ -n "$c" ] && [ -x "$c/platform-tools/adb" ]; then ADB="$c/platform-tools/adb"; break; fi
  done
fi

# Generate the platform boilerplate that is not checked in (Gradle wrapper,
# Gradle scripts matching *your* Flutter version, launcher fallback PNGs...).
# `flutter create` never overwrites existing files, so the game code,
# MainActivity.kt, the manifest and the icon are kept as they are.
if [ ! -f android/gradlew ] || { [ ! -f android/app/build.gradle ] && [ ! -f android/app/build.gradle.kts ]; }; then
  info "Generating Android project files (first build only)"
  flutter create --platforms=android --org dev.rxvy --project-name ragbox . >/dev/null
fi

info "Fetching packages"
flutter pub get >/dev/null

if [ "$TESTS" = 1 ]; then
  info "Running tests"
  flutter test
fi

info "Building release APK (first build downloads Gradle, takes a few minutes)"
flutter build apk --release

VERSION="$(grep '^version:' pubspec.yaml | sed -E 's/version: *([^+]+).*/\1/')"
mkdir -p dist
APK="dist/ragbox-v${VERSION}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$APK"
info "APK ready: $APK ($(du -h "$APK" | cut -f1))"

[ "$INSTALL" = 1 ] || exit 0

if [ -z "$ADB" ]; then
  red "adb not found - install Android platform-tools to install over USB."
  echo "You can also copy $APK to the phone and open it there."
  exit 1
fi

"$ADB" start-server >/dev/null 2>&1 || true
mapfile -t DEVICES < <("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
mapfile -t UNAUTH < <("$ADB" devices | awk 'NR>1 && $2=="unauthorized" {print $1}')

for d in "${UNAUTH[@]:-}"; do
  [ -n "$d" ] && red "Device $d is unauthorized: unlock it and accept the 'Allow USB debugging' prompt, then re-run."
done

if [ "${#DEVICES[@]}" -eq 0 ] || [ -z "${DEVICES[0]:-}" ]; then
  red "No Android device connected."
  echo "On each phone/tablet: Settings > About > tap 'Build number' 7 times,"
  echo "then Settings > System > Developer options > enable 'USB debugging'."
  echo "Plug it in, accept the prompt and run this script again."
  exit 1
fi

FAILED=0
for d in "${DEVICES[@]}"; do
  MODEL="$("$ADB" -s "$d" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
  info "Installing on ${MODEL:-device} ($d)"
  if "$ADB" -s "$d" install -r "$APK"; then
    "$ADB" -s "$d" shell monkey -p dev.rxvy.ragbox -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
    echo "   launched Ragbox on ${MODEL:-$d}"
  else
    red "   install failed on $d (if an older build signed differently is installed, uninstall it first: $ADB -s $d uninstall dev.rxvy.ragbox)"
    FAILED=1
  fi
done
exit $FAILED
