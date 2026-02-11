#!/bin/bash

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
    echo "📸 Generating screenshots for locale: $locale"

    # Clear app data to reset demo data for fresh locale
    adb shell pm clear me.ahmetcetinkaya.whph 2>/dev/null || true

    # Run flutter drive with locale via both env var and dart-define
    SCREENSHOT_LOCALE=$locale fvm flutter drive \
        --driver=test/integration/screenshot_grabbing/test_driver.dart \
        --target=test/integration/screenshot_grabbing/screenshot_capture.dart \
        --dart-define=DEMO_MODE=true \
        --dart-define=SCREENSHOT_LOCALE="$locale"

    echo "✅ Completed screenshots for locale: $locale"

    # If it was English, copy to en-GB
    if [ "$locale" == "en" ]; then
        copy_en_to_gb
    fi
    echo ""
}

# Function to copy English screenshots to en-GB
copy_en_to_gb() {
    echo "📋 Copying English screenshots to en-GB..."
    EN_US_DIR="../../../../fastlane/metadata/android/en-US/images/phoneScreenshots"
    EN_GB_DIR="../../../../fastlane/metadata/android/en-GB/images/phoneScreenshots"
    mkdir -p "$EN_GB_DIR"
    if [ -d "$EN_US_DIR" ] && [ "$(ls -A $EN_US_DIR 2>/dev/null)" ]; then
        cp -r "$EN_US_DIR"/* "$EN_GB_DIR/"
        echo "✅ Copied English screenshots to en-GB"
    else
        echo "⚠️ No English screenshots found to copy"
    fi
}

# Process arguments
if [ "$1" == "--all" ]; then
    echo "🚀 Starting screenshot generation for ${#LOCALES[@]} locales..."
    echo ""
    for locale in "${LOCALES[@]}"; do
        run_for_locale "$locale"
    done
    echo "🎉 All screenshots generated successfully!"
elif [ -n "$1" ]; then
    # Check if locale is supported
    SUPPORTED=false
    if [[ " ${LOCALES[*]} " == *" $1 "* ]]; then
        SUPPORTED=true
    fi

    if [ "$SUPPORTED" = true ]; then
        run_for_locale "$1"
    else
        echo "❌ Error: Locale '$1' is not supported."
        echo "Supported locales: ${LOCALES[*]}"
        exit 1
    fi
else
    echo "Usage:"
    echo "  ./generate_screenshots.sh --all        # Generate for all locales"
    echo "  ./generate_screenshots.sh <locale>     # Generate for a specific locale (e.g., tr)"
    exit 1
fi
