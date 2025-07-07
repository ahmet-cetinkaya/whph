#!/bin/bash

# WHPH - Double Build Reproducibility Test
# This script builds the same APK twice and compares their hashes
# Usage: ./test_local_reproducibility.sh

set -e

echo "🔄 WHPH Local Reproducibility Test"
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

# Test directory
TEST_DIR="reproducibility_test"
mkdir -p "$TEST_DIR"

print_status $BLUE "🔍 Testing Local Build Reproducibility..."
echo "  Test directory: $TEST_DIR"
echo "  Timestamp: $(date)"
echo ""

# Build 1
print_status $YELLOW "🏗️  Building APK #1..."
echo "  Using reproducible build script..."
bash scripts/reproducible_build.sh

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "$TEST_DIR/build1.apk"
    BUILD1_HASH=$(sha256sum "$TEST_DIR/build1.apk" | cut -d' ' -f1)
    BUILD1_SIZE=$(stat -c%s "$TEST_DIR/build1.apk")
    print_status $GREEN "✅ Build #1 completed"
    echo "  Hash: $BUILD1_HASH"
    echo "  Size: $BUILD1_SIZE bytes"
else
    print_status $RED "❌ Build #1 failed - APK not found"
    exit 1
fi

echo ""
print_status $YELLOW "⏱️  Waiting 5 seconds before second build..."
sleep 5

# Build 2
print_status $YELLOW "🏗️  Building APK #2..."
echo "  Using reproducible build script..."
bash scripts/reproducible_build.sh

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "$TEST_DIR/build2.apk"
    BUILD2_HASH=$(sha256sum "$TEST_DIR/build2.apk" | cut -d' ' -f1)
    BUILD2_SIZE=$(stat -c%s "$TEST_DIR/build2.apk")
    print_status $GREEN "✅ Build #2 completed"
    echo "  Hash: $BUILD2_HASH"
    echo "  Size: $BUILD2_SIZE bytes"
else
    print_status $RED "❌ Build #2 failed - APK not found"
    exit 1
fi

echo ""
print_status $BLUE "📊 Reproducibility Test Results:"
echo "  Build #1 Hash: $BUILD1_HASH"
echo "  Build #2 Hash: $BUILD2_HASH"
echo "  Build #1 Size: $BUILD1_SIZE bytes"
echo "  Build #2 Size: $BUILD2_SIZE bytes"
echo ""

# Compare results
if [ "$BUILD1_HASH" = "$BUILD2_HASH" ]; then
    print_status $GREEN "🎉 SUCCESS: Local builds are reproducible!"
    echo "  ✅ Hash match: Both builds produced identical APKs"
    echo "  ✅ Size match: $([ "$BUILD1_SIZE" = "$BUILD2_SIZE" ] && echo "Yes" || echo "No")"
    echo ""
    print_status $GREEN "🔧 Your reproducible build configuration is working correctly!"
    echo "  → Local environment produces consistent builds"
    echo "  → Ready for CI comparison"
else
    print_status $RED "❌ FAILURE: Local builds are NOT reproducible!"
    echo "  🔍 Hash mismatch indicates non-deterministic build"
    echo "  📏 Size difference: $((BUILD2_SIZE - BUILD1_SIZE)) bytes"
    echo ""
    print_status $YELLOW "🔧 Troubleshooting:"
    echo "  1. Check if timestamps are being embedded"
    echo "  2. Verify SOURCE_DATE_EPOCH is working"
    echo "  3. Look for random/time-based components"
    echo "  4. Check environment variables consistency"
    echo ""
    
    # Detailed comparison
    print_status $BLUE "🔍 Detailed APK Analysis:"
    echo "  Running detailed comparison..."
    
    # Extract and compare APK contents
    if command -v unzip &> /dev/null; then
        mkdir -p "$TEST_DIR/extract1" "$TEST_DIR/extract2"
        unzip -q "$TEST_DIR/build1.apk" -d "$TEST_DIR/extract1"
        unzip -q "$TEST_DIR/build2.apk" -d "$TEST_DIR/extract2"
        
        echo "  📁 Comparing APK contents..."
        if command -v diff &> /dev/null; then
            diff -r "$TEST_DIR/extract1" "$TEST_DIR/extract2" > "$TEST_DIR/diff.txt" 2>&1 || true
            if [ -s "$TEST_DIR/diff.txt" ]; then
                echo "  📄 Differences found - saved to $TEST_DIR/diff.txt"
                echo "  First 10 lines of differences:"
                head -10 "$TEST_DIR/diff.txt" | while read line; do
                    echo "    $line"
                done
            else
                echo "  🤔 No file differences found, but hashes differ"
                echo "  This may indicate binary-level differences"
            fi
        fi
    fi
fi

echo ""
print_status $GREEN "📋 Test Summary:"
echo "  Test files saved in: $TEST_DIR/"
echo "  Build #1 APK: $TEST_DIR/build1.apk"
echo "  Build #2 APK: $TEST_DIR/build2.apk"
if [ -f "$TEST_DIR/diff.txt" ]; then
    echo "  Differences: $TEST_DIR/diff.txt"
fi
echo ""

print_status $GREEN "✅ Reproducibility test completed!"
