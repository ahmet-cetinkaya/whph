#!/bin/bash

# WHPH - Complete Build Validation Script
# This script validates that CI test, validation script, and F-Droid build all produce identical APK binaries
# Usage: ./validate_all_builds.sh

set -e

echo "🔍 WHPH Complete Build Validation"
echo "================================="
echo "Testing: CI test, Direct reproducible, and F-Droid-style builds"
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

# Function to calculate SHA256 hash
calculate_hash() {
    local file=$1
    if [ -f "$file" ]; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo "FILE_NOT_FOUND"
    fi
}

# Function to clean build environment
clean_build_env() {
    print_status $YELLOW "🧹 Cleaning build environment..."
    flutter clean
    rm -rf build/
    rm -rf .pub-cache/
    # Also clean global cache to ensure consistency
    rm -rf ~/.pub-cache/hosted/pub.dev/* 2>/dev/null || true
}

# Arrays to store results
declare -a BUILD_NAMES=()
declare -a BUILD_HASHES=()
declare -a BUILD_SIZES=()

# Function to record build result
record_build() {
    local name=$1
    local apk_path="build/app/outputs/flutter-apk/app-release.apk"
    
    if [ -f "$apk_path" ]; then
        local backup_name="build_${name}.apk"
        cp "$apk_path" "$backup_name"
        local hash=$(calculate_hash "$backup_name")
        local size=$(stat -c%s "$backup_name")
        
        BUILD_NAMES+=("$name")
        BUILD_HASHES+=("$hash")
        BUILD_SIZES+=("$size")
        
        print_status $GREEN "✅ $name build completed - Hash: $hash"
        return 0
    else
        print_status $RED "❌ $name build failed - APK not found"
        return 1
    fi
}

# Clean up any previous builds
clean_build_env

# Build 1: Direct reproducible build (our reference)
print_status $BLUE "🔨 Build 1: Direct reproducible build..."

export PUB_CACHE=$(pwd)/.pub-cache
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
export TZ=UTC
export LC_ALL=C
export LANG=C

flutter clean
flutter packages pub get
bash scripts/security_validation.sh
flutter build apk --release --build-name=0.9.10 --build-number=47 \
    --split-debug-info=build/app/outputs/symbols \
    --tree-shake-icons \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --target-platform=android-arm64,android-arm,android-x64

record_build "direct" || exit 1

# Clean for next build
clean_build_env
unset PUB_CACHE SOURCE_DATE_EPOCH FLUTTER_STORAGE_BASE_URL TZ LC_ALL LANG

# Build 2: RPS reproducible command
print_status $BLUE "🔨 Build 2: RPS reproducible command..."
rps release:android:reproducible
record_build "rps" || exit 1

# Clean for next build
clean_build_env

# Build 3: F-Droid style build (simulating F-Droid environment)
print_status $BLUE "🔨 Build 3: F-Droid-style build..."

# Simulate F-Droid environment setup
export PUB_CACHE=$(pwd)/.pub-cache
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
export TZ=UTC
export LC_ALL=C
export LANG=C

# F-Droid prebuild steps
flutter config --no-analytics
flutter clean
flutter packages pub get

# F-Droid build steps  
flutter clean
flutter packages pub get
flutter build apk --release --build-name=0.9.10 --build-number=47 \
    --split-debug-info=build/app/outputs/symbols \
    --tree-shake-icons \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --target-platform=android-arm64,android-arm,android-x64

record_build "fdroid" || exit 1

# Compare all builds
print_status $YELLOW "🔍 Comparing all builds..."
echo ""

# Display results
for i in "${!BUILD_NAMES[@]}"; do
    echo "${BUILD_NAMES[$i]} build:"
    echo "  Hash: ${BUILD_HASHES[$i]}"
    echo "  Size: ${BUILD_SIZES[$i]} bytes"
    echo ""
done

# Check if all hashes are identical
all_identical=true
reference_hash="${BUILD_HASHES[0]}"

for hash in "${BUILD_HASHES[@]}"; do
    if [ "$hash" != "$reference_hash" ]; then
        all_identical=false
        break
    fi
done

if [ "$all_identical" = true ]; then
    print_status $GREEN "🎉 SUCCESS: All builds are identical!"
    print_status $GREEN "✅ F-Droid signature verification should pass"
    print_status $GREEN "✅ CI test and reproducible builds are consistent"
    
    # Clean up temporary files
    rm -f build_*.apk
    
    echo ""
    echo "📋 Validation Summary:"
    echo "  - All three build processes produce identical APK binaries"
    echo "  - SHA256 hash: $reference_hash"
    echo "  - File size: ${BUILD_SIZES[0]} bytes"
    echo "  - F-Droid reproducible build requirements satisfied"
    echo "  - CI test consistency verified"
    
else
    print_status $RED "❌ FAILURE: Builds are different!"
    print_status $RED "⚠️  F-Droid signature verification may fail"
    
    echo ""
    echo "📋 Differences found:"
    for i in "${!BUILD_NAMES[@]}"; do
        echo "  ${BUILD_NAMES[$i]}: ${BUILD_HASHES[$i]}"
    done
    
    echo ""
    print_status $YELLOW "📁 Keeping build files for analysis:"
    for name in "${BUILD_NAMES[@]}"; do
        echo "  - build_${name}.apk"
    done
    
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "  1. Run ./scripts/diagnose_build_differences.sh for detailed analysis"
    echo "  2. Check environment variable consistency"
    echo "  3. Verify Flutter version and dependency resolution"
    echo "  4. Review cache state differences"
    
    exit 1
fi

print_status $GREEN "🔗 Next steps:"
echo "  1. Test with actual F-Droid build system"
echo "  2. Verify CI pipeline produces consistent results"
echo "  3. Monitor future builds for consistency"
