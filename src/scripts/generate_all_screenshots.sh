#!/bin/bash

# Generate screenshots for all supported locales
#
# This script runs the screenshot integration test for each locale
# and saves screenshots to the appropriate fastlane folder.

set -e

cd "$(dirname "$0")/.."

# All supported locales
LOCALES=(
    "cs"
    "da"
    "de"
    "el"
    "en"
    "es"
    "fi"
    "fr"
    "it"
    "ja"
    "ko"
    "nl"
    "nb"
    "pl"
    "pt"
    "ro"
    "ru"
    "sl"
    "sv"
    "tr"
    "uk"
    "zh"
)

echo "🚀 Starting screenshot generation for ${#LOCALES[@]} locales..."
echo ""

for locale in "${LOCALES[@]}"; do
    echo "📸 Generating screenshots for locale: $locale"

    # Clear app data to reset demo data for fresh locale
    adb shell pm clear me.ahmetcetinkaya.whph 2>/dev/null || true

    # Run flutter drive with locale via both env var and dart-define
    SCREENSHOT_LOCALE=$locale fvm flutter drive \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/screenshot_test.dart \
        --dart-define=DEMO_MODE=true \
        --dart-define=SCREENSHOT_LOCALE="$locale"

    echo "✅ Completed screenshots for locale: $locale"
    echo ""
done

# Copy English screenshots to en-GB folder
echo "📋 Copying English screenshots to en-GB..."
EN_US_DIR="../fastlane/metadata/android/en-US/images/phoneScreenshots"
EN_GB_DIR="../fastlane/metadata/android/en-GB/images/phoneScreenshots"
mkdir -p "$EN_GB_DIR"
if [ -d "$EN_US_DIR" ] && [ "$(ls -A $EN_US_DIR 2>/dev/null)" ]; then
    cp -r "$EN_US_DIR"/* "$EN_GB_DIR/"
    echo "✅ Copied English screenshots to en-GB"
else
    echo "⚠️ No English screenshots found to copy"
fi

echo ""
echo "🎉 All screenshots generated successfully!"
echo ""
echo "Screenshots saved to: ../fastlane/metadata/android/*/images/phoneScreenshots/"
