#!/bin/bash

# WHPH - Build Differences Diagnostic Script
# This script helps diagnose why CI test and reproducible builds produce different APK binaries

set -e

echo "🔍 WHPH Build Differences Diagnostic"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to capture environment state
capture_env_state() {
    local label=$1
    local output_file=$2
    
    echo "=== Environment State: $label ===" > "$output_file"
    echo "Timestamp: $(date)" >> "$output_file"
    echo "PWD: $(pwd)" >> "$output_file"
    echo "SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH:-'NOT_SET'}" >> "$output_file"
    echo "PUB_CACHE: ${PUB_CACHE:-'NOT_SET'}" >> "$output_file"
    echo "FLUTTER_STORAGE_BASE_URL: ${FLUTTER_STORAGE_BASE_URL:-'NOT_SET'}" >> "$output_file"
    echo "TZ: ${TZ:-'NOT_SET'}" >> "$output_file"
    echo "LC_ALL: ${LC_ALL:-'NOT_SET'}" >> "$output_file"
    echo "LANG: ${LANG:-'NOT_SET'}" >> "$output_file"
    echo "" >> "$output_file"
    
    echo "=== Git State ===" >> "$output_file"
    echo "Last commit: $(git log -1 --format='%H %ct %s')" >> "$output_file"
    echo "SOURCE_DATE_EPOCH calculation: $(git log -1 --format=%ct)" >> "$output_file"
    echo "" >> "$output_file"
    
    echo "=== Flutter State ===" >> "$output_file"
    flutter --version >> "$output_file" 2>&1 || echo "Flutter not available" >> "$output_file"
    echo "" >> "$output_file"
    
    echo "=== Cache State ===" >> "$output_file"
    echo "Global pub cache (~/.pub-cache):" >> "$output_file"
    if [ -d ~/.pub-cache ]; then
        echo "  Exists: Yes" >> "$output_file"
        echo "  Size: $(du -sh ~/.pub-cache 2>/dev/null | cut -f1)" >> "$output_file"
    else
        echo "  Exists: No" >> "$output_file"
    fi
    
    echo "Local pub cache (./.pub-cache):" >> "$output_file"
    if [ -d ./.pub-cache ]; then
        echo "  Exists: Yes" >> "$output_file"
        echo "  Size: $(du -sh ./.pub-cache 2>/dev/null | cut -f1)" >> "$output_file"
    else
        echo "  Exists: No" >> "$output_file"
    fi
    echo "" >> "$output_file"
    
    echo "=== Build Directory State ===" >> "$output_file"
    if [ -d build ]; then
        echo "Build directory exists" >> "$output_file"
        echo "Size: $(du -sh build 2>/dev/null | cut -f1)" >> "$output_file"
    else
        echo "Build directory does not exist" >> "$output_file"
    fi
    echo "" >> "$output_file"
}

# Clean up any previous diagnostic files
rm -f env_state_*.txt build_*.apk

print_status $YELLOW "🧹 Initial cleanup..."
flutter clean
rm -rf build/
rm -rf .pub-cache/

# Capture initial state
capture_env_state "Initial" "env_state_initial.txt"

print_status $BLUE "🔨 Test 1: Direct reproducible build..."

# Set environment variables exactly as in the RPS command
export PUB_CACHE=$(pwd)/.pub-cache
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
export TZ=UTC
export LC_ALL=C
export LANG=C

capture_env_state "Before Direct Build" "env_state_before_direct.txt"

# Run the exact same commands as in the RPS reproducible build
flutter clean
flutter packages pub get
bash scripts/security_validation.sh
flutter build apk --release --build-name=0.9.10 --build-number=47 \
    --split-debug-info=build/app/outputs/symbols \
    --tree-shake-icons \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --target-platform=android-arm64,android-arm,android-x64

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "build_direct.apk"
    DIRECT_HASH=$(sha256sum "build_direct.apk" | cut -d' ' -f1)
    DIRECT_SIZE=$(stat -c%s "build_direct.apk")
    print_status $GREEN "✅ Direct build completed - Hash: $DIRECT_HASH"
else
    print_status $RED "❌ Direct build failed"
    exit 1
fi

capture_env_state "After Direct Build" "env_state_after_direct.txt"

# Clean for CI-style build
print_status $YELLOW "🧹 Cleaning for CI-style build..."
flutter clean
rm -rf build/
rm -rf .pub-cache/

# Unset environment variables to simulate fresh CI environment
unset PUB_CACHE SOURCE_DATE_EPOCH FLUTTER_STORAGE_BASE_URL TZ LC_ALL LANG

print_status $BLUE "🔨 Test 2: CI-style build simulation..."

# Simulate CI workflow steps
flutter config --no-analytics
flutter pub get  # This populates global cache
rps clean        # This clears global cache but leaves local cache setup
rps security-check:ci

capture_env_state "Before CI-style Build" "env_state_before_ci.txt"

# Now run the reproducible build (which will set its own environment)
rps release:android:reproducible

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "build_ci_style.apk"
    CI_HASH=$(sha256sum "build_ci_style.apk" | cut -d' ' -f1)
    CI_SIZE=$(stat -c%s "build_ci_style.apk")
    print_status $GREEN "✅ CI-style build completed - Hash: $CI_HASH"
else
    print_status $RED "❌ CI-style build failed"
    exit 1
fi

capture_env_state "After CI-style Build" "env_state_after_ci.txt"

# Compare results
print_status $YELLOW "🔍 Comparing builds..."
echo ""
echo "Direct build:"
echo "  Hash: $DIRECT_HASH"
echo "  Size: $DIRECT_SIZE bytes"
echo ""
echo "CI-style build:"
echo "  Hash: $CI_HASH"
echo "  Size: $CI_SIZE bytes"
echo ""

if [ "$DIRECT_HASH" = "$CI_HASH" ]; then
    print_status $GREEN "🎉 SUCCESS: Both builds are identical!"
    rm -f build_direct.apk build_ci_style.apk
else
    print_status $RED "❌ FAILURE: Builds are different!"
    print_status $YELLOW "📁 Keeping build files and environment states for analysis:"
    echo "  - build_direct.apk (Direct build)"
    echo "  - build_ci_style.apk (CI-style build)"
    echo "  - env_state_*.txt (Environment states)"
    echo ""
    print_status $BLUE "🔍 Environment state files created:"
    ls -la env_state_*.txt
fi

print_status $BLUE "📋 Analysis complete. Check environment state files for differences."
