#!/bin/bash

# WHPH - Build Environment Analysis Script
# This script analyzes differences between local and CI build environments
# Usage: ./analyze_build_environment.sh

set -e

echo "🔍 WHPH Build Environment Analysis"
echo "================================="
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

# Check if running in CI
IS_CI=${CI:-false}
if [ "$GITHUB_ACTIONS" = "true" ]; then
    IS_CI=true
fi

print_status $BLUE "Environment: $([ "$IS_CI" = "true" ] && echo "CI (GitHub Actions)" || echo "Local Development")"
echo ""

# System Information
print_status $YELLOW "🖥️  System Information:"
echo "  OS: $(uname -s) $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Hostname: $(hostname 2>/dev/null || echo 'unknown')"
echo "  User: $(whoami)"
echo "  Working Directory: $(pwd)"
echo "  Date: $(date)"
echo "  Timezone: $(date +%Z)"
echo ""

# Environment Variables (reproducible build related)
print_status $YELLOW "🌍 Environment Variables:"
echo "  HOME: ${HOME:-'unset'}"
echo "  USER: ${USER:-'unset'}"
echo "  PATH length: ${#PATH} characters"
echo "  LANG: ${LANG:-'unset'}"
echo "  LC_ALL: ${LC_ALL:-'unset'}"
echo "  TZ: ${TZ:-'unset'}"
echo "  SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH:-'unset'}"
echo ""

# Flutter Information
print_status $YELLOW "🐦 Flutter Information:"
if command -v flutter &> /dev/null; then
    flutter --version
    echo "  Flutter Path: $(which flutter)"
    echo "  Flutter SDK: ${FLUTTER_ROOT:-'unset'}"
    echo "  Flutter Cache: ${FLUTTER_STORAGE_BASE_URL:-'default'}"
else
    echo "  ❌ Flutter not found in PATH"
fi
echo ""

# Dart Information
print_status $YELLOW "🎯 Dart Information:"
if command -v dart &> /dev/null; then
    dart --version
    echo "  Dart Path: $(which dart)"
else
    echo "  ❌ Dart not found in PATH"
fi
echo ""

# Java Information
print_status $YELLOW "☕ Java Information:"
if command -v java &> /dev/null; then
    java -version 2>&1 | head -3
    echo "  Java Path: $(which java)"
    echo "  JAVA_HOME: ${JAVA_HOME:-'unset'}"
else
    echo "  ❌ Java not found in PATH"
fi
echo ""

# Android SDK Information
print_status $YELLOW "🤖 Android SDK Information:"
ANDROID_HOME=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-'unset'}}
echo "  ANDROID_HOME: $ANDROID_HOME"
echo "  ANDROID_SDK_ROOT: ${ANDROID_SDK_ROOT:-'unset'}"

if [ -d "$ANDROID_HOME" ]; then
    echo "  ✅ Android SDK exists"
    if [ -f "$ANDROID_HOME/tools/bin/sdkmanager" ]; then
        echo "  SDK Manager: Available"
    elif [ -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
        echo "  SDK Manager: Available (cmdline-tools)"
    else
        echo "  SDK Manager: Not found"
    fi
else
    echo "  ❌ Android SDK not found"
fi
echo ""

# Gradle Information
print_status $YELLOW "🏗️  Gradle Information:"
if command -v gradle &> /dev/null; then
    gradle --version | head -5
    echo "  Gradle Path: $(which gradle)"
else
    echo "  ❌ Gradle not found in PATH"
fi

# Check gradle wrapper
if [ -f "./android/gradlew" ]; then
    echo "  Gradle Wrapper: Available"
    echo "  Gradle Wrapper Version: $(./android/gradlew --version | head -2)"
else
    echo "  ❌ Gradle Wrapper not found"
fi
echo ""

# Git Information
print_status $YELLOW "📦 Git Information:"
if command -v git &> /dev/null; then
    echo "  Git Version: $(git --version)"
    echo "  Repository: $(git remote get-url origin 2>/dev/null || echo 'Unknown')"
    echo "  Branch: $(git branch --show-current 2>/dev/null || echo 'Unknown')"
    echo "  Last Commit: $(git log -1 --format='%H %ct %s' 2>/dev/null || echo 'Unknown')"
    echo "  Working Directory Clean: $(git diff --quiet && echo 'Yes' || echo 'No')"
else
    echo "  ❌ Git not found in PATH"
fi
echo ""

# Build Files Check
print_status $YELLOW "📋 Build Files Check:"
echo "  pubspec.yaml: $([ -f "pubspec.yaml" ] && echo "✅ Exists" || echo "❌ Missing")"
echo "  pubspec.lock: $([ -f "pubspec.lock" ] && echo "✅ Exists" || echo "❌ Missing")"
echo "  android/local.properties: $([ -f "android/local.properties" ] && echo "✅ Exists" || echo "❌ Missing")"
echo "  android/key.properties: $([ -f "android/key.properties" ] && echo "✅ Exists" || echo "❌ Missing")"
echo "  android/app/build.gradle: $([ -f "android/app/build.gradle" ] && echo "✅ Exists" || echo "❌ Missing")"
echo ""

# Dependency Analysis
print_status $YELLOW "🔗 Dependency Analysis:"
if [ -f "pubspec.lock" ]; then
    echo "  pubspec.lock hash: $(sha256sum pubspec.lock | cut -d' ' -f1)"
    echo "  Dependencies count: $(grep -c "^  " pubspec.lock || echo "0")"
else
    echo "  ❌ pubspec.lock not found"
fi
echo ""

# Previous Build Analysis
print_status $YELLOW "🔍 Previous Build Analysis:"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    echo "  Previous APK: ✅ Exists"
    echo "  APK Size: $(stat -c%s "$APK_PATH") bytes"
    echo "  APK Hash: $(sha256sum "$APK_PATH" | cut -d' ' -f1)"
    echo "  APK Modified: $(stat -c%y "$APK_PATH")"
else
    echo "  Previous APK: ❌ Not found"
fi
echo ""

# Recommendations
print_status $GREEN "💡 Recommendations:"
echo ""

if [ "$IS_CI" = "true" ]; then
    echo "  🤖 Running in CI environment"
    echo "  → Ensure local environment matches CI exactly"
    echo "  → Check environment variables and tool versions"
else
    echo "  🖥️  Running in local environment"
    echo "  → Compare this output with CI environment"
    echo "  → Ensure all tool versions match CI"
fi

echo ""
echo "  📝 Common reproducible build issues:"
echo "     • Different Flutter/Dart SDK versions"
echo "     • Different Java/JDK versions"
echo "     • Different Android SDK/NDK versions"
echo "     • Different Gradle versions"
echo "     • Different system locales/timezones"
echo "     • Different PATH or environment variables"
echo "     • Different dependency versions (pubspec.lock)"
echo ""

print_status $BLUE "🔧 Next Steps:"
echo "  1. Run this script in both local and CI environments"
echo "  2. Compare the outputs to identify differences"
echo "  3. Align the environments to match exactly"
echo "  4. Use SOURCE_DATE_EPOCH for deterministic timestamps"
echo "  5. Ensure pubspec.lock is identical in both environments"
echo ""

print_status $GREEN "✅ Environment analysis completed!"
