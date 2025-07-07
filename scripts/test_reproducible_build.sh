#!/bin/bash

# Test script to verify reproducible builds
# This script should produce the same APK as the CI build

set -e

echo "Starting reproducible build test..."

# Clean everything first
flutter clean
flutter pub get

# Set up the exact same environment as CI
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
export TZ=UTC
export LC_ALL=C
export LANG=C

echo "Build environment:"
echo "  SOURCE_DATE_EPOCH: $SOURCE_DATE_EPOCH"
echo "  FLUTTER_STORAGE_BASE_URL: $FLUTTER_STORAGE_BASE_URL"
echo "  TZ: $TZ"
echo "  LC_ALL: $LC_ALL"
echo "  LANG: $LANG"

# Run security validation
bash scripts/security_validation.sh

# Build the APK with the same flags as CI
flutter build apk --release --build-name=0.9.10 --build-number=47 --no-obfuscate --no-shrink

# Calculate and display the hash
echo ""
echo "=== Local Build Output Verification ==="

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
  echo "✅ APK file exists: $APK_PATH"
  
  # Get file size
  FILE_SIZE=$(stat -c%s "$APK_PATH")
  FILE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE / 1024 / 1024}")
  echo "📦 File size: $FILE_SIZE bytes ($FILE_SIZE_MB MB)"
  
  # Calculate SHA256
  SHA256=$(sha256sum "$APK_PATH" | cut -d' ' -f1)
  echo "🔐 SHA256: $SHA256"
  
  # Get file modification time
  MODIFIED=$(stat -c%y "$APK_PATH")
  echo "⏰ Modified: $MODIFIED"
else
  echo "❌ ERROR: APK file not found at $APK_PATH"
  exit 1
fi

echo ""
echo "=== App Version Info ==="
bash scripts/get_app_version.sh

echo ""
echo "=== Build Output Summary ==="
echo "Path: $APK_PATH"
echo "Size: $FILE_SIZE_MB MB"
echo "Hash: $SHA256"
echo ""
echo "This hash should match the CI build output."
