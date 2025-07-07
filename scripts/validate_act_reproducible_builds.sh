#!/bin/bash

# WHPH - Act Tool Reproducible Build Validation Script
# This script validates that act tool execution produces identical APK binaries as direct execution
# Usage: ./validate_act_reproducible_builds.sh

set -e

echo "🔍 Act Tool Reproducible Build Validation"
echo "========================================="
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
    # Clean any previous test files
    rm -f build_*.apk build_info_*.txt act_diagnostic_*.txt
}

# Check if act is available
if ! command -v act > /dev/null 2>&1; then
    print_status $RED "❌ Act tool not found"
    print_status $YELLOW "Please install act: https://github.com/nektos/act"
    print_status $YELLOW "Or use: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
    exit 1
fi

print_status $GREEN "✅ Act tool found: $(act --version)"
echo ""

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
        
        print_status $GREEN "✅ $name build completed - Hash: $hash, Size: $size bytes"
        return 0
    else
        print_status $RED "❌ $name build failed - APK not found"
        return 1
    fi
}

# Clean up any previous builds
clean_build_env

# Build 1: Direct reproducible build (reference)
print_status $BLUE "🔨 Build 1: Direct reproducible build..."
bash scripts/reproducible_build.sh
record_build "direct" || exit 1

# Clean for next build
clean_build_env

# Build 2: RPS reproducible command (should be identical to direct)
print_status $BLUE "🔨 Build 2: RPS reproducible command..."
rps release:android:reproducible
record_build "rps" || exit 1

# Clean for next build
clean_build_env

# Build 3: Act tool execution
print_status $BLUE "🔨 Build 3: Act tool execution..."
print_status $YELLOW "This may take several minutes as act downloads Docker images..."

# Run act with the Android workflow
if act -W .github/workflows/flutter-ci.android.yml -j build --secret-file .secrets; then
    record_build "act" || exit 1
else
    print_status $YELLOW "⚠️  Act execution completed with warnings, checking for APK..."
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        record_build "act" || exit 1
    else
        print_status $RED "❌ Act build failed - no APK produced"
        exit 1
    fi
fi

# Compare all builds
print_status $YELLOW "🔍 Comparing all builds..."
echo ""

# Display results
for i in "${!BUILD_NAMES[@]}"; do
    echo "${BUILD_NAMES[$i]} build:"
    echo "  Hash: ${BUILD_HASHES[$i]}"
    echo "  Size: ${BUILD_SIZES[$i]} bytes ($(awk "BEGIN {printf \"%.2f\", ${BUILD_SIZES[$i]} / 1024 / 1024}") MB)"
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
    print_status $GREEN "✅ Act tool produces reproducible builds"
    print_status $GREEN "✅ F-Droid signature verification should pass"
    
    # Clean up temporary files
    rm -f build_*.apk
    
    echo ""
    echo "📋 Validation Summary:"
    echo "  - All three build processes produce identical APK binaries"
    echo "  - SHA256 hash: $reference_hash"
    echo "  - File size: ${BUILD_SIZES[0]} bytes"
    echo "  - Act tool configuration is working correctly"
    echo "  - CI test and F-Droid builds should be consistent"
    
else
    print_status $RED "❌ FAILURE: Builds are different!"
    print_status $RED "⚠️  Act tool configuration needs further adjustment"
    
    echo ""
    echo "📋 Differences found:"
    for i in "${!BUILD_NAMES[@]}"; do
        echo "  ${BUILD_NAMES[$i]}: ${BUILD_HASHES[$i]} (${BUILD_SIZES[$i]} bytes)"
    done
    
    echo ""
    print_status $YELLOW "📁 Keeping build files for analysis:"
    for name in "${BUILD_NAMES[@]}"; do
        echo "  - build_${name}.apk"
    done
    
    echo ""
    print_status $BLUE "🔧 Troubleshooting steps:"
    echo "  1. Run ./scripts/analyze_apk_differences.sh build_direct.apk build_act.apk"
    echo "  2. Check act_diagnostic_*.txt files for environment differences"
    echo "  3. Review .actrc configuration"
    echo "  4. Compare build_info_*.txt files for build parameter differences"
    
    # Check if we have diagnostic files
    if ls act_diagnostic_*.txt 1> /dev/null 2>&1; then
        print_status $YELLOW "📋 Act diagnostic files found:"
        ls -la act_diagnostic_*.txt
    fi
    
    if ls build_info_*.txt 1> /dev/null 2>&1; then
        print_status $YELLOW "📋 Build info files found:"
        ls -la build_info_*.txt
    fi
    
    exit 1
fi

print_status $GREEN "🔗 Next steps:"
echo "  1. Test with actual F-Droid build system"
echo "  2. Verify CI pipeline produces consistent results"
echo "  3. Monitor future builds for consistency"
echo "  4. Remove diagnostic steps from CI workflow once confirmed working"
