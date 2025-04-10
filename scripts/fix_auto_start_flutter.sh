#!/bin/bash

# Find the auto_start_flutter package in pub cache
PLUGIN_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "auto_start_flutter*" -type d | head -n 1)

if [ -z "$PLUGIN_PATH" ]; then
    echo "auto_start_flutter plugin not found"
    exit 1
fi

echo "Found plugin at $PLUGIN_PATH"

# Fix build.gradle
BUILD_GRADLE="${PLUGIN_PATH}/android/build.gradle"
if [ ! -f "$BUILD_GRADLE" ]; then
    echo "build.gradle not found at $BUILD_GRADLE"
    exit 1
fi

# Create backup of build.gradle
cp "$BUILD_GRADLE" "${BUILD_GRADLE}.bak"
echo "Created backup of build.gradle at ${BUILD_GRADLE}.bak"

# Create a properly structured build.gradle file
cat > "$BUILD_GRADLE" << 'EOF'
group 'co.techflow.auto_start_flutter'
version '1.0'

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'

android {
    namespace 'co.techflow.auto_start_flutter'
    compileSdkVersion 33
    
    defaultConfig {
        minSdkVersion 16
        targetSdkVersion 33
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
EOF

echo "Replaced build.gradle with proper structure"

# Fix AndroidManifest.xml
MANIFEST="${PLUGIN_PATH}/android/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
    echo "AndroidManifest.xml not found at $MANIFEST"
    exit 1
fi

# Create backup
cp "$MANIFEST" "${MANIFEST}.bak"
echo "Created backup of AndroidManifest.xml at ${MANIFEST}.bak"

# Create new manifest content
cat > "$MANIFEST" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
</manifest>
EOF

echo "Updated AndroidManifest.xml with proper structure"

# Update the gradle.properties if it exists
GRADLE_PROPS="${PLUGIN_PATH}/android/gradle.properties"
if [ -f "$GRADLE_PROPS" ]; then
    echo "android.useAndroidX=true" > "$GRADLE_PROPS"
    echo "android.enableJetifier=true" >> "$GRADLE_PROPS"
    echo "Updated gradle.properties with AndroidX settings"
fi

echo "Fix completed. You can now try building your application again."
