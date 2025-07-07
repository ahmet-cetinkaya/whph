#!/bin/bash

# WHPH - APK Hash Comparison Script
# This script compares APK hashes between local and CI builds
# Usage: ./compare_apk_hashes.sh [local_apk_path] [ci_apk_path]

set -e

echo "🔍 WHPH APK Hash Comparison"
echo "============================"
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

# Default APK paths
LOCAL_APK_PATH=${1:-"build/app/outputs/flutter-apk/app-release.apk"}
CI_APK_PATH=${2:-"ci_build/app-release.apk"}

print_status $BLUE "🔍 Analyzing APK Files:"
echo "  Local APK: $LOCAL_APK_PATH"
echo "  CI APK: $CI_APK_PATH"
echo ""

# Function to analyze APK
analyze_apk() {
    local apk_path=$1
    local label=$2
    
    print_status $YELLOW "📱 $label APK Analysis:"
    
    if [ ! -f "$apk_path" ]; then
        print_status $RED "  ❌ APK not found: $apk_path"
        return 1
    fi
    
    # Basic file info
    local file_size=$(stat -c%s "$apk_path")
    local file_size_mb=$(awk "BEGIN {printf \"%.2f\", $file_size / 1024 / 1024}")
    local file_hash=$(sha256sum "$apk_path" | cut -d' ' -f1)
    local file_modified=$(stat -c%y "$apk_path")
    
    echo "  ✅ File exists: $apk_path"
    echo "  📏 Size: $file_size bytes ($file_size_mb MB)"
    echo "  🔐 SHA256: $file_hash"
    echo "  📅 Modified: $file_modified"
    
    # APK structure analysis using unzip
    echo "  📦 APK Structure:"
    if command -v unzip &> /dev/null; then
        local temp_dir=$(mktemp -d)
        unzip -q "$apk_path" -d "$temp_dir"
        
        # Count files
        local file_count=$(find "$temp_dir" -type f | wc -l)
        echo "     Files count: $file_count"
        
        # Key files analysis
        if [ -f "$temp_dir/classes.dex" ]; then
            local dex_size=$(stat -c%s "$temp_dir/classes.dex")
            local dex_hash=$(sha256sum "$temp_dir/classes.dex" | cut -d' ' -f1)
            echo "     classes.dex: $dex_size bytes, hash: ${dex_hash:0:16}..."
        fi
        
        if [ -f "$temp_dir/resources.arsc" ]; then
            local arsc_size=$(stat -c%s "$temp_dir/resources.arsc")
            local arsc_hash=$(sha256sum "$temp_dir/resources.arsc" | cut -d' ' -f1)
            echo "     resources.arsc: $arsc_size bytes, hash: ${arsc_hash:0:16}..."
        fi
        
        if [ -f "$temp_dir/AndroidManifest.xml" ]; then
            local manifest_size=$(stat -c%s "$temp_dir/AndroidManifest.xml")
            local manifest_hash=$(sha256sum "$temp_dir/AndroidManifest.xml" | cut -d' ' -f1)
            echo "     AndroidManifest.xml: $manifest_size bytes, hash: ${manifest_hash:0:16}..."
        fi
        
        # Flutter assets
        if [ -d "$temp_dir/assets/flutter_assets" ]; then
            local flutter_assets_count=$(find "$temp_dir/assets/flutter_assets" -type f | wc -l)
            echo "     Flutter assets: $flutter_assets_count files"
        fi
        
        # Native libraries
        if [ -d "$temp_dir/lib" ]; then
            local lib_count=$(find "$temp_dir/lib" -name "*.so" | wc -l)
            echo "     Native libraries: $lib_count files"
            
            # List architectures
            local archs=$(find "$temp_dir/lib" -maxdepth 1 -type d -exec basename {} \; | grep -v "^lib$" | sort | tr '\n' ' ')
            echo "     Architectures: $archs"
        fi
        
        # META-INF analysis
        if [ -d "$temp_dir/META-INF" ]; then
            echo "     META-INF files:"
            find "$temp_dir/META-INF" -type f -exec basename {} \; | sort | while read file; do
                echo "       - $file"
            done
        fi
        
        # Clean up
        rm -rf "$temp_dir"
    else
        echo "     ❌ unzip not available for structure analysis"
    fi
    
    echo ""
    
    # Return hash for comparison
    echo "$file_hash"
}

# Analyze both APKs
print_status $BLUE "🔍 Starting APK Analysis..."
echo ""

if [ -f "$LOCAL_APK_PATH" ] && [ -f "$CI_APK_PATH" ]; then
    local_hash=$(analyze_apk "$LOCAL_APK_PATH" "Local")
    ci_hash=$(analyze_apk "$CI_APK_PATH" "CI")
    
    print_status $BLUE "📊 Comparison Results:"
    echo "  Local Hash:  $local_hash"
    echo "  CI Hash:     $ci_hash"
    echo ""
    
    if [ "$local_hash" = "$ci_hash" ]; then
        print_status $GREEN "🎉 SUCCESS: APK hashes match!"
        echo "  ✅ Reproducible build achieved"
    else
        print_status $RED "❌ FAILURE: APK hashes differ!"
        echo "  🔍 This indicates non-deterministic build"
        echo ""
        print_status $YELLOW "🔧 Troubleshooting Steps:"
        echo "  1. Check build environment differences"
        echo "  2. Verify Flutter/Dart SDK versions"
        echo "  3. Check Android SDK/NDK versions"
        echo "  4. Verify pubspec.lock is identical"
        echo "  5. Check SOURCE_DATE_EPOCH usage"
        echo "  6. Verify Gradle deterministic settings"
        echo "  7. Check for timestamp-based differences"
        echo ""
    fi
else
    if [ ! -f "$LOCAL_APK_PATH" ]; then
        print_status $RED "❌ Local APK not found: $LOCAL_APK_PATH"
    fi
    if [ ! -f "$CI_APK_PATH" ]; then
        print_status $RED "❌ CI APK not found: $CI_APK_PATH"
    fi
    echo "  💡 Build APKs first using the reproducible build script"
fi

print_status $GREEN "✅ APK analysis completed!"
