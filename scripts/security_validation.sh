#!/bin/bash

# WHPH - Build Security and Validation Script
# This script performs security checks and validates the build environment
# Usage: ./security_validation.sh [--ci]
#   --ci: Run in CI mode with relaxed checks for missing build artifacts

set -e

# Parse command line arguments
CI_MODE=false
for arg in "$@"; do
    case $arg in
        --ci)
            CI_MODE=true
            shift
            ;;
        *)
            # Unknown option
            ;;
    esac
done

echo "🔒 WHPH Build Security Validation"
echo "================================="
if [ "$CI_MODE" = true ]; then
    echo "🤖 Running in CI mode"
fi
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 1. Validate Gradle Wrapper
print_status $YELLOW "📋 Checking Gradle Wrapper..."

# Check if we're in a CI environment
IS_CI=${CI:-$CI_MODE}
GRADLE_WRAPPER_JAR="android/gradle/wrapper/gradle-wrapper.jar"
GRADLE_WRAPPER_PROPS="android/gradle/wrapper/gradle-wrapper.properties"

# First check if wrapper properties exist (this should always be in version control)
if [ -f "$GRADLE_WRAPPER_PROPS" ]; then
    print_status $GREEN "✅ Gradle wrapper properties exist"
    
    # Check wrapper properties
    if grep -q "gradle-8.4" "$GRADLE_WRAPPER_PROPS"; then
        print_status $GREEN "✅ Gradle version is pinned to 8.4"
    else
        print_status $RED "❌ Gradle version should be pinned to 8.4"
        exit 1
    fi
    
    # Check HTTPS distribution URL
    if grep -q "services.gradle.org" "$GRADLE_WRAPPER_PROPS" && grep -q "https" "$GRADLE_WRAPPER_PROPS"; then
        print_status $GREEN "✅ Using HTTPS for Gradle distribution"
    else
        print_status $RED "❌ Gradle distribution should use HTTPS"
        exit 1
    fi
else
    print_status $RED "❌ Gradle wrapper properties not found"
    exit 1
fi

# Check for Gradle wrapper JAR (may not exist in CI until gradle tasks are run)
if [ -f "$GRADLE_WRAPPER_JAR" ]; then
    print_status $GREEN "✅ Gradle wrapper JAR exists"
elif [ "$IS_CI" = "true" ]; then
    print_status $YELLOW "⚠️  Gradle wrapper JAR not found in CI - will be downloaded on first gradle execution"
    
    # Try to generate the wrapper JAR if gradle is available
    if command -v gradle > /dev/null 2>&1; then
        print_status $YELLOW "🔄 Attempting to generate Gradle wrapper..."
        cd android && gradle wrapper --gradle-version 8.4 && cd ..
        if [ -f "$GRADLE_WRAPPER_JAR" ]; then
            print_status $GREEN "✅ Gradle wrapper JAR generated successfully"
        fi
    elif [ -f "android/gradlew" ]; then
        print_status $YELLOW "🔄 Gradle wrapper script exists, JAR will be downloaded on first use"
    fi
else
    print_status $RED "❌ Gradle wrapper JAR not found"
    exit 1
fi

# 2. Check for pinned dependency versions
print_status $YELLOW "📦 Checking dependency versions..."
if grep -r "implementation.*+" android/app/build.gradle > /dev/null 2>&1; then
    print_status $YELLOW "⚠️  Dynamic dependency versions detected - consider pinning for reproducible builds"
else
    print_status $GREEN "✅ No dynamic dependency versions found"
fi

# 3. Validate pubspec.lock exists
print_status $YELLOW "🔒 Checking Flutter dependency lock..."
if [ -f "pubspec.lock" ]; then
    print_status $GREEN "✅ pubspec.lock exists - dependencies are locked"
else
    print_status $RED "❌ pubspec.lock not found - run 'flutter pub get'"
    exit 1
fi

# 4. Check for security-sensitive files
print_status $YELLOW "🔐 Checking for sensitive files..."
SENSITIVE_FILES=("android/key.properties" "android/whph-release.keystore")
for file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status $YELLOW "⚠️  Sensitive file found: $file (ensure it's not in version control)"
    fi
done

# 5. Validate build configuration
print_status $YELLOW "⚙️  Validating build configuration..."
if grep -q "minifyEnabled true" android/app/build.gradle; then
    print_status $GREEN "✅ Code minification enabled for release"
else
    print_status $YELLOW "⚠️  Consider enabling minification for release builds"
fi

if grep -q "debuggable false" android/app/build.gradle; then
    print_status $GREEN "✅ Debug disabled for release builds"
else
    print_status $YELLOW "⚠️  Ensure debug is disabled for release builds"
fi

# 6. Clean build recommendation
print_status $YELLOW "🧹 Build recommendations..."
if [ "$IS_CI" = true ]; then
    echo "CI Environment detected. Recommended build commands:"
    echo "  flutter clean"
    echo "  flutter pub get"
    echo "  flutter pub deps  # Verify dependency resolution"
    echo "  flutter build apk --release --split-debug-info=build/app/outputs/symbols"
else
    echo "For reproducible builds, consider running:"
    echo "  flutter clean"
    echo "  flutter pub get"
    echo "  flutter build apk --release --split-debug-info=build/app/outputs/symbols"
fi

print_status $GREEN "🎉 Security validation completed!"
echo ""
echo "📋 Summary:"
echo "  - Gradle wrapper security: Validated"
echo "  - Dependency management: Checked"
echo "  - Build configuration: Reviewed"
echo "  - Sensitive files: Scanned"
if [ "$IS_CI" = true ]; then
    echo "  - CI mode: Enabled (relaxed checks for build artifacts)"
fi
echo ""
echo "🔗 For more information on reproducible builds:"
echo "  https://reproducible-builds.org/"
echo "  https://flutter.dev/docs/deployment/android#building-the-app-for-release"
