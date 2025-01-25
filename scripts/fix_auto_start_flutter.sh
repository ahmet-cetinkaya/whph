#!/bin/bash

# Find the auto_start_flutter package in pub cache
PLUGIN_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "auto_start_flutter*" -type d | head -n 1)

if [ -z "$PLUGIN_PATH" ]; then
    echo "auto_start_flutter plugin not found"
    exit 1
fi

# Fix build.gradle
BUILD_GRADLE="${PLUGIN_PATH}/android/build.gradle"
if [ ! -f "$BUILD_GRADLE" ]; then
    echo "build.gradle not found at $BUILD_GRADLE"
    exit 1
fi

if ! grep -q "namespace" "$BUILD_GRADLE"; then
    temp_file=$(mktemp)
    awk '/android {/{ print; print "    namespace \"co.techflow.auto_start_flutter\""; next }1' "$BUILD_GRADLE" > "$temp_file"
    mv "$temp_file" "$BUILD_GRADLE"
    echo "Added namespace to $BUILD_GRADLE"
fi

# Fix AndroidManifest.xml
MANIFEST="${PLUGIN_PATH}/android/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
    echo "AndroidManifest.xml not found at $MANIFEST"
    exit 1
fi

# Create backup
cp "$MANIFEST" "${MANIFEST}.bak"

# Create new manifest content
cat > "$MANIFEST" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
</manifest>
EOF

echo "Updated AndroidManifest.xml with proper structure"
