#!/bin/bash

# Source acore logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../packages/acore-scripts/src/logger.sh"

# Generate screenshots for supported locales
#
# Usage:
#   ./generate_screenshots.sh --all        # Generate for all locales
#   ./generate_screenshots.sh <locale>     # Generate for a specific locale (e.g., tr)

set -e

cd "$(dirname "$0")/.."

# All supported locales
LOCALES=(
    "cs" "da" "de" "el" "en" "es" "fi" "fr" "it" "ja" "ko" "nl" "no" "pl" "pt" "ro" "ru" "sl" "sv" "tr" "uk" "zh"
)

# Function to run screenshot for a locale
run_for_locale() {
    local locale=$1
    acore_log_info "Generating screenshots for locale: $locale"

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

# Process arguments
if [ "$1" == "--all" ]; then
    acore_log_info "Starting screenshot generation for ${#LOCALES[@]} locales..."
    for locale in "${LOCALES[@]}"; do
        run_for_locale "$locale"
    done
    acore_log_success "All screenshots generated successfully!"
elif [ -n "$1" ]; then
    # Check if locale is supported
    SUPPORTED=false
    if [[ " ${LOCALES[*]} " == *" $1 "* ]]; then
        SUPPORTED=true
    fi

    if [ "$SUPPORTED" = true ]; then
        run_for_locale "$1"
    else
        acore_log_error "Locale '$1' is not supported."
        acore_log_info "Supported locales: ${LOCALES[*]}"
        exit 1
    fi
else
    acore_log_warning "Usage:"
    acore_log_info "  ./generate_screenshots.sh --all        # Generate for all locales"
    acore_log_info "  ./generate_screenshots.sh <locale>     # Generate for a specific locale (e.g., tr)"
    exit 1
fi
