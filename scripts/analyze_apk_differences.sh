#!/bin/bash

# WHPH - APK Differences Analysis Script
# This script analyzes the differences between APK files to identify why they have different hashes/sizes
# Usage: ./analyze_apk_differences.sh <apk1> <apk2>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <apk1> <apk2>"
    echo "Example: $0 build_local.apk build_act.apk"
    exit 1
fi

APK1="$1"
APK2="$2"

echo "🔍 APK Differences Analysis"
echo "=========================="
echo "APK 1: $APK1"
echo "APK 2: $APK2"
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

# Check if APK files exist
if [ ! -f "$APK1" ]; then
    print_status $RED "❌ APK 1 not found: $APK1"
    exit 1
fi

if [ ! -f "$APK2" ]; then
    print_status $RED "❌ APK 2 not found: $APK2"
    exit 1
fi

# Create analysis directory
ANALYSIS_DIR="apk_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$ANALYSIS_DIR"

print_status $BLUE "📋 Basic APK Information"

# Get basic file information
APK1_SIZE=$(stat -c%s "$APK1")
APK2_SIZE=$(stat -c%s "$APK2")
APK1_HASH=$(sha256sum "$APK1" | cut -d' ' -f1)
APK2_HASH=$(sha256sum "$APK2" | cut -d' ' -f1)

echo "APK 1:"
echo "  Size: $APK1_SIZE bytes"
echo "  Hash: $APK1_HASH"
echo ""
echo "APK 2:"
echo "  Size: $APK2_SIZE bytes"
echo "  Hash: $APK2_HASH"
echo ""

SIZE_DIFF=$((APK2_SIZE - APK1_SIZE))
echo "Size difference: $SIZE_DIFF bytes"

if [ "$APK1_HASH" = "$APK2_HASH" ]; then
    print_status $GREEN "✅ APKs are identical!"
    exit 0
else
    print_status $YELLOW "⚠️  APKs are different, analyzing..."
fi

# Check if unzip is available
if ! command -v unzip > /dev/null 2>&1; then
    print_status $RED "❌ unzip command not found. Please install unzip to analyze APK contents."
    exit 1
fi

print_status $BLUE "📦 Extracting APK contents..."

# Extract APKs
mkdir -p "$ANALYSIS_DIR/apk1_contents"
mkdir -p "$ANALYSIS_DIR/apk2_contents"

unzip -q "$APK1" -d "$ANALYSIS_DIR/apk1_contents"
unzip -q "$APK2" -d "$ANALYSIS_DIR/apk2_contents"

print_status $GREEN "✅ APKs extracted"

# Compare directory structures
print_status $BLUE "📁 Comparing directory structures..."

cd "$ANALYSIS_DIR"

# Generate file lists
find apk1_contents -type f | sort > apk1_files.txt
find apk2_contents -type f | sort > apk2_files.txt

# Compare file lists
echo "Files only in APK 1:"
comm -23 apk1_files.txt apk2_files.txt | head -20
echo ""

echo "Files only in APK 2:"
comm -13 apk1_files.txt apk2_files.txt | head -20
echo ""

echo "Common files:"
COMMON_FILES=$(comm -12 apk1_files.txt apk2_files.txt | wc -l)
echo "  Count: $COMMON_FILES"

# Analyze file size differences for common files
print_status $BLUE "📊 Analyzing file size differences..."

{
    echo "=== File Size Comparison ==="
    echo "File,APK1_Size,APK2_Size,Difference"
    
    while IFS= read -r file; do
        if [ -f "apk1_contents/$file" ] && [ -f "apk2_contents/$file" ]; then
            size1=$(stat -c%s "apk1_contents/$file")
            size2=$(stat -c%s "apk2_contents/$file")
            diff=$((size2 - size1))
            if [ $diff -ne 0 ]; then
                echo "$file,$size1,$size2,$diff"
            fi
        fi
    done < apk1_files.txt
} > file_size_differences.csv

# Show largest differences
echo "Largest file size differences:"
sort -t',' -k4 -nr file_size_differences.csv | head -10
echo ""

# Analyze specific file types
print_status $BLUE "🔍 Analyzing specific file types..."

echo "Native libraries (.so files):"
find apk1_contents -name "*.so" | while read -r file; do
    rel_path=${file#apk1_contents/}
    if [ -f "apk2_contents/$rel_path" ]; then
        size1=$(stat -c%s "$file")
        size2=$(stat -c%s "apk2_contents/$rel_path")
        hash1=$(sha256sum "$file" | cut -d' ' -f1)
        hash2=$(sha256sum "apk2_contents/$rel_path" | cut -d' ' -f1)
        if [ "$hash1" != "$hash2" ]; then
            echo "  $rel_path: $size1 vs $size2 bytes (DIFFERENT)"
        else
            echo "  $rel_path: $size1 bytes (IDENTICAL)"
        fi
    else
        echo "  $rel_path: Only in APK1"
    fi
done
echo ""

echo "Flutter assets:"
find apk1_contents -path "*/flutter_assets/*" | while read -r file; do
    rel_path=${file#apk1_contents/}
    if [ -f "apk2_contents/$rel_path" ]; then
        size1=$(stat -c%s "$file")
        size2=$(stat -c%s "apk2_contents/$rel_path")
        hash1=$(sha256sum "$file" | cut -d' ' -f1)
        hash2=$(sha256sum "apk2_contents/$rel_path" | cut -d' ' -f1)
        if [ "$hash1" != "$hash2" ]; then
            echo "  $rel_path: $size1 vs $size2 bytes (DIFFERENT)"
        fi
    fi
done | head -10
echo ""

# Check META-INF differences (signatures, manifests)
print_status $BLUE "📋 Checking META-INF differences..."

echo "META-INF files in APK1:"
find apk1_contents/META-INF -type f 2>/dev/null | sort || echo "No META-INF directory"
echo ""

echo "META-INF files in APK2:"
find apk2_contents/META-INF -type f 2>/dev/null | sort || echo "No META-INF directory"
echo ""

# Compare AndroidManifest.xml
if [ -f "apk1_contents/AndroidManifest.xml" ] && [ -f "apk2_contents/AndroidManifest.xml" ]; then
    print_status $BLUE "📱 Comparing AndroidManifest.xml..."
    if cmp -s "apk1_contents/AndroidManifest.xml" "apk2_contents/AndroidManifest.xml"; then
        echo "AndroidManifest.xml: IDENTICAL"
    else
        echo "AndroidManifest.xml: DIFFERENT"
        # Try to show differences if aapt is available
        if command -v aapt > /dev/null 2>&1; then
            echo "Manifest differences (if readable):"
            diff <(aapt dump xmltree "$APK1" AndroidManifest.xml 2>/dev/null || echo "Cannot read") \
                 <(aapt dump xmltree "$APK2" AndroidManifest.xml 2>/dev/null || echo "Cannot read") || true
        fi
    fi
fi

# Generate summary report
{
    echo "=== APK Analysis Summary ==="
    echo "Generated: $(date)"
    echo "APK 1: $APK1 ($APK1_SIZE bytes, $APK1_HASH)"
    echo "APK 2: $APK2 ($APK2_SIZE bytes, $APK2_HASH)"
    echo "Size difference: $SIZE_DIFF bytes"
    echo ""
    echo "Files only in APK 1: $(comm -23 apk1_files.txt apk2_files.txt | wc -l)"
    echo "Files only in APK 2: $(comm -13 apk1_files.txt apk2_files.txt | wc -l)"
    echo "Common files: $COMMON_FILES"
    echo "Files with size differences: $(tail -n +2 file_size_differences.csv | wc -l)"
    echo ""
    echo "Analysis files generated:"
    echo "  - apk1_files.txt: File list for APK 1"
    echo "  - apk2_files.txt: File list for APK 2"
    echo "  - file_size_differences.csv: Size differences for common files"
    echo "  - apk1_contents/: Extracted contents of APK 1"
    echo "  - apk2_contents/: Extracted contents of APK 2"
} > analysis_summary.txt

cd ..

print_status $GREEN "✅ Analysis complete!"
print_status $BLUE "📁 Analysis results saved in: $ANALYSIS_DIR/"
print_status $YELLOW "📋 Key findings:"
echo "  - Size difference: $SIZE_DIFF bytes"
echo "  - Check $ANALYSIS_DIR/analysis_summary.txt for detailed summary"
echo "  - Check $ANALYSIS_DIR/file_size_differences.csv for file-level differences"

print_status $BLUE "🔧 Recommended next steps:"
echo "  1. Review the largest file size differences"
echo "  2. Check for native library (.so) differences"
echo "  3. Examine Flutter asset differences"
echo "  4. Look for META-INF or manifest differences"
