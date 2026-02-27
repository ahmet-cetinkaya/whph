#!/bin/bash

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../packages/acore-scripts/src/logger.sh"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

# Generate screenshots for supported locales
#
# Usage:
#   ./generate_screenshots.sh mobile --all      # Generate mobile screenshots for all locales
#   ./generate_screenshots.sh mobile <locale>   # Generate mobile screenshots for a specific locale (e.g., tr)
#   ./generate_screenshots.sh desktop --all     # Generate desktop screenshots for all locales
#   ./generate_screenshots.sh desktop <locale>  # Generate desktop screenshots for a specific locale

set -e

cd "$SRC_DIR"

# All supported locales
LOCALES=(
	"cs" "da" "de" "el" "en" "es" "fi" "fr" "it" "ja" "ko" "nl" "no" "pl" "pt" "ro" "ru" "sl" "sv" "tr" "uk" "zh"
)

ADB_DEVICE_READY=0

setup_android_screenshot_mode() {
	if [ "$ADB_DEVICE_READY" -eq 1 ]; then
		return
	fi

	if ! command -v adb >/dev/null 2>&1; then
		acore_log_error "adb not found. Please install Android platform-tools and ensure adb is in PATH."
		exit 1
	fi

	acore_log_info "Waiting for Android device/emulator..."
	adb wait-for-device

	# Wait until Android reports boot completed.
	local boot_completed=""
	for _ in {1..60}; do
		boot_completed=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
		if [ "$boot_completed" = "1" ]; then
			break
		fi
		sleep 1
	done

	if [ "$boot_completed" != "1" ]; then
		acore_log_error "Android device/emulator is not fully booted."
		exit 1
	fi

	acore_log_info "Applying clean status bar demo mode for screenshots..."
	adb shell settings put global sysui_demo_allowed 1
	adb shell am broadcast -a com.android.systemui.demo -e command enter
	adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
	adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
	adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
	adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4
	adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

	ADB_DEVICE_READY=1
}

cleanup_android_screenshot_mode() {
	if [ "$ADB_DEVICE_READY" -eq 1 ]; then
		acore_log_info "Restoring Android status bar (exit demo mode)..."
		adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true
	fi
}

trap cleanup_android_screenshot_mode EXIT

# Function to run screenshot for a locale
run_for_locale() {
	local locale=$1
	acore_log_info "Generating screenshots for locale: $locale"

	setup_android_screenshot_mode

	# Clear app data to reset demo data for fresh locale
	adb shell pm clear me.ahmetcetinkaya.whph 2>/dev/null || true

	# Run flutter drive with locale via both env var and dart-define
	SCREENSHOT_LOCALE=$locale fvm flutter drive \
		--driver=test/integration/screenshot_grabbing/test_driver.dart \
		--target=test/integration/screenshot_grabbing/screenshot_capture.dart \
		--dart-define=DEMO_MODE=true \
		--dart-define=SCREENSHOT_LOCALE="$locale"

	acore_log_success "Completed screenshots for locale: $locale"

	# If it was English, copy to en-GB
	if [ "$locale" == "en" ]; then
		copy_en_to_gb
	fi
}

# Function to copy English screenshots to en-GB
copy_en_to_gb() {
	acore_log_info "Copying English screenshots to en-GB..."
	EN_US_DIR="../fastlane/metadata/android/en-US/images/phoneScreenshots"
	EN_GB_DIR="../fastlane/metadata/android/en-GB/images/phoneScreenshots"
	mkdir -p "$EN_GB_DIR"
	if [ -d "$EN_US_DIR" ] && [ "$(ls -A $EN_US_DIR 2>/dev/null)" ]; then
		cp -r "$EN_US_DIR"/* "$EN_GB_DIR/"
		acore_log_success "Copied English screenshots to en-GB"
	else
		acore_log_warning "No English screenshots found to copy"
	fi
}

# Function to run screenshot for desktop
run_desktop() {
	local locale=${1:-en}
	acore_log_info "Generating desktop screenshots for locale: $locale"

	# Clear app data to reset demo data for fresh locale
	rm -rf ~/.local/share/whph/debug_whph 2>/dev/null || true

	# Run flutter drive for linux desktop
	DESKTOP_SCREENSHOT=true SCREENSHOT_LOCALE="$locale" fvm flutter drive \
		-d linux \
		--driver=test/integration/screenshot_grabbing/test_driver.dart \
		--target=test/integration/screenshot_grabbing/screenshot_capture.dart \
		--dart-define=DEMO_MODE=true \
		--dart-define=SCREENSHOT_LOCALE="$locale" \
		--dart-define=DESKTOP_SCREENSHOT=true

	acore_log_success "Completed desktop screenshots for locale: $locale"
}

run_mobile_command() {
	local target=$1

	if [ "$target" == "--all" ]; then
		acore_log_info "Starting mobile screenshot generation for ${#LOCALES[@]} locales..."
		for locale in "${LOCALES[@]}"; do
			run_for_locale "$locale"
		done
		acore_log_success "All mobile screenshots generated successfully!"
	elif [ -n "$target" ]; then
		run_for_locale "$target"
	else
		acore_log_warning "Usage: ./generate_screenshots.sh mobile [--all|<locale>]"
		exit 1
	fi
}

run_desktop_command() {
	local target=$1

	if [ "$target" == "--all" ]; then
		acore_log_info "Starting desktop screenshot generation for ${#LOCALES[@]} locales..."
		for locale in "${LOCALES[@]}"; do
			run_desktop "$locale"
		done
		acore_log_success "All desktop screenshots generated successfully!"
	elif [ -n "$target" ]; then
		run_desktop "$target"
	else
		run_desktop "en"
	fi
}

# Process arguments with explicit subcommands
subcommand=$1
target=$2

case "$subcommand" in
	mobile)
		run_mobile_command "$target"
		;;
	desktop)
		run_desktop_command "$target"
		;;
	*)
		acore_log_warning "Usage:"
		acore_log_info "  ./generate_screenshots.sh mobile --all      # Generate mobile screenshots for all locales"
		acore_log_info "  ./generate_screenshots.sh mobile <locale>   # Generate mobile screenshots for a specific locale (e.g., tr)"
		acore_log_info "  ./generate_screenshots.sh desktop --all     # Generate desktop screenshots for all locales"
		acore_log_info "  ./generate_screenshots.sh desktop <locale>  # Generate desktop screenshots for a specific locale"
		exit 1
		;;
esac
