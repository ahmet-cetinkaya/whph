#!/bin/bash

# This script fixes Android compilation issues for the app_usage plugin
# 1. Updates compileSdkVersion to 33
# 2. Adds namespace declaration
# 3. Sets Java and Kotlin compatibility to version 17
# 4. Adds @SuppressWarnings for deprecation warnings

PUB_CACHE="${HOME}/.pub-cache"
APP_USAGE_PATH="${PUB_CACHE}/hosted/pub.dev/app_usage-3.0.1"

# Fix build.gradle configurations
ANDROID_BUILD_GRADLE="${APP_USAGE_PATH}/android/build.gradle"
if [ -f "$ANDROID_BUILD_GRADLE" ]; then
    sed -i 's/^    compileSdkVersion .*$/    compileSdkVersion 33/' "$ANDROID_BUILD_GRADLE"
    sed -i '/^android {/a \ \ namespace "dk.cachet.app_usage"' "$ANDROID_BUILD_GRADLE"
    sed -i '/^android {/a \ \ compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17; }' "$APP_USAGE_PATH"
    sed -i '/^android {/a \ \ kotlinOptions { jvmTarget = "17" }' "$ANDROID_BUILD_GRADLE"
    echo "Successfully modified app_usage build.gradle"
else
    echo "build.gradle not found. Please check the package path."
    exit 1
fi

# Fix Stats.java deprecation warnings
STATS_PATH="${PUB_CACHE}/hosted/pub.dev/app_usage-3.0.1/android/src/main/kotlin/dk/cachet/app_usage/Stats.java"
if [ -f "$STATS_PATH" ]; then
    # Add @SuppressWarnings annotation
    sed -i '1i@SuppressWarnings("deprecation")' "$STATS_PATH"
    echo "Successfully modified Stats.java"
else
    echo "Stats.java not found. Please check the package path."
    exit 1
fi
