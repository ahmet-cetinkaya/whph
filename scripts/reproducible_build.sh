#!/bin/bash

# WHPH - Reproducible Build Script
# This script ensures consistent reproducible builds across local and CI environments
# Usage: ./reproducible_build.sh

set -e

echo "🔨 WHPH Reproducible Build"
echo "========================="
echo "Timestamp: $(date)"
echo "Working directory: $(pwd)"
echo "User: $(whoami)"
echo "Hostname: $(hostname 2>/dev/null || echo 'unknown')"
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

# Detect environment
IS_CI=${CI:-false}
IS_GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}
IS_ACT=${ACT:-false}

print_status $BLUE "🔍 Environment Detection:"
echo "  CI: $IS_CI"
echo "  GitHub Actions: $IS_GITHUB_ACTIONS"
echo "  Act: $IS_ACT"
echo ""

# Set up reproducible build environment
print_status $BLUE "⚙️  Setting up reproducible build environment..."

# Determine the correct working directory
if [ -n "$GITHUB_WORKSPACE" ]; then
    WORK_DIR="$GITHUB_WORKSPACE"
    print_status $YELLOW "Using GitHub workspace: $WORK_DIR"
else
    WORK_DIR="$(pwd)"
    print_status $YELLOW "Using current directory: $WORK_DIR"
fi

# Ensure we're in the correct directory
cd "$WORK_DIR"

# Set environment variables for reproducible builds
export PUB_CACHE="$WORK_DIR/.pub-cache"
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
export TZ=UTC
export LC_ALL=C
export LANG=C

# Additional environment variables for consistency
export HOME=${HOME:-/tmp/home}
export USER=${USER:-builder}

print_status $GREEN "✅ Environment variables set:"
echo "  PUB_CACHE: $PUB_CACHE"
echo "  SOURCE_DATE_EPOCH: $SOURCE_DATE_EPOCH"
echo "  FLUTTER_STORAGE_BASE_URL: $FLUTTER_STORAGE_BASE_URL"
echo "  TZ: $TZ"
echo "  LC_ALL: $LC_ALL"
echo "  LANG: $LANG"
echo "  HOME: $HOME"
echo "  USER: $USER"
echo ""

# Git information for debugging
print_status $BLUE "📋 Git Information:"
echo "  Repository: $(git remote get-url origin 2>/dev/null || echo 'Unknown')"
echo "  Branch: $(git branch --show-current 2>/dev/null || echo 'Unknown')"
echo "  Last commit: $(git log -1 --format='%H %ct %s' 2>/dev/null || echo 'Unknown')"
echo "  SOURCE_DATE_EPOCH: $SOURCE_DATE_EPOCH"
echo ""

# Flutter information
print_status $BLUE "🐦 Flutter Information:"
flutter --version | head -3
echo ""

# Clean build environment
print_status $YELLOW "🧹 Cleaning build environment..."
flutter clean

# Remove any existing local cache to ensure fresh state
if [ -d "$PUB_CACHE" ]; then
    print_status $YELLOW "Removing existing local pub cache..."
    rm -rf "$PUB_CACHE"
fi

# Create pub cache directory
mkdir -p "$PUB_CACHE"

# Get dependencies
print_status $BLUE "📦 Getting dependencies..."
flutter packages pub get

# Run security validation
print_status $BLUE "🔒 Running security validation..."
if [ "$IS_CI" = "true" ] || [ "$IS_GITHUB_ACTIONS" = "true" ] || [ "$IS_ACT" = "true" ]; then
    bash scripts/security_validation.sh --ci
else
    bash scripts/security_validation.sh
fi

# Build APK
print_status $BLUE "🔨 Building APK..."
flutter build apk --release \
    --build-name=0.9.10 \
    --build-number=47 \
    --split-debug-info=build/app/outputs/symbols \
    --tree-shake-icons \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --target-platform=android-arm64,android-arm,android-x64

# Verify build output
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(stat -c%s "$APK_PATH")
    APK_HASH=$(sha256sum "$APK_PATH" | cut -d' ' -f1)
    
    print_status $GREEN "✅ Build completed successfully!"
    echo ""
    echo "📦 Build Output:"
    echo "  Path: $APK_PATH"
    echo "  Size: $APK_SIZE bytes ($(awk "BEGIN {printf \"%.2f\", $APK_SIZE / 1024 / 1024}") MB)"
    echo "  SHA256: $APK_HASH"
    echo "  Modified: $(stat -c%y "$APK_PATH")"
    echo ""
    
    # Additional verification
    print_status $BLUE "🔍 Build Verification:"
    echo "  Environment: $([ "$IS_CI" = "true" ] && echo "CI" || echo "Local")"
    echo "  Timestamp: $(date)"
    echo "  Git commit: $(git log -1 --format='%H')"
    echo "  SOURCE_DATE_EPOCH: $SOURCE_DATE_EPOCH"
    echo ""
    
    # Create build info file for debugging
    {
        echo "=== Reproducible Build Info ==="
        echo "Generated: $(date)"
        echo "Environment: $([ "$IS_CI" = "true" ] && echo "CI" || echo "Local")"
        echo "Working directory: $WORK_DIR"
        echo "Git commit: $(git log -1 --format='%H %ct %s')"
        echo "SOURCE_DATE_EPOCH: $SOURCE_DATE_EPOCH"
        echo "APK path: $APK_PATH"
        echo "APK size: $APK_SIZE"
        echo "APK hash: $APK_HASH"
        echo "Flutter version: $(flutter --version | head -1)"
        echo "Build command: flutter build apk --release --build-name=0.9.10 --build-number=47 --split-debug-info=build/app/outputs/symbols --tree-shake-icons --dart-define=FLUTTER_WEB_USE_SKIA=true --target-platform=android-arm64,android-arm,android-x64"
    } > "build_info_$(date +%Y%m%d_%H%M%S).txt"
    
else
    print_status $RED "❌ Build failed - APK not found at $APK_PATH"
    exit 1
fi

print_status $GREEN "🎉 Reproducible build completed successfully!"
