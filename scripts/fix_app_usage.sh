#!/bin/bash

set -e
cd "$(dirname "$0")/.."

PUB_CACHE="${HOME}/.pub-cache"
APP_USAGE_PATH="${PUB_CACHE}/hosted/pub.dev/app_usage-3.0.1"

# Check if package exists
if [ ! -d "$APP_USAGE_PATH" ]; then
    echo "Error: app_usage package not found at $APP_USAGE_PATH"
    exit 1
fi

# Fix build.gradle configurations
ANDROID_BUILD_GRADLE="${APP_USAGE_PATH}/android/build.gradle"
if [ -f "$ANDROID_BUILD_GRADLE" ]; then
    # Create backup
    cp "$ANDROID_BUILD_GRADLE" "${ANDROID_BUILD_GRADLE}.bak"
    
    sed -i 's/^    compileSdkVersion .*$/    compileSdkVersion 33/' "$ANDROID_BUILD_GRADLE"
    sed -i '/^android {/a \ \ namespace "dk.cachet.app_usage"' "$ANDROID_BUILD_GRADLE"
    sed -i '/^android {/a \ \ compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17; }' "$ANDROID_BUILD_GRADLE"
    sed -i '/^android {/a \ \ kotlinOptions { jvmTarget = "17" }' "$ANDROID_BUILD_GRADLE"
    echo "Successfully modified app_usage build.gradle"
else
    echo "build.gradle not found at $ANDROID_BUILD_GRADLE"
    exit 1
fi

# Fix Stats.java deprecation warnings
STATS_PATH="${APP_USAGE_PATH}/android/src/main/kotlin/dk/cachet/app_usage/Stats.java"
if [ -f "$STATS_PATH" ]; then
    # Create backup
    cp "$STATS_PATH" "${STATS_PATH}.bak"
    
    # Add @SuppressWarnings annotation if it doesn't exist
    if ! grep -q "@SuppressWarnings" "$STATS_PATH"; then
        sed -i '1i@SuppressWarnings("deprecation")' "$STATS_PATH"
        echo "Successfully modified Stats.java"
    fi
else
    echo "Stats.java not found at $STATS_PATH"
    exit 1
fi
