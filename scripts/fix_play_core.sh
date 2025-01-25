#!/bin/bash

set -e
cd "$(dirname "$0")/.."

# Update app's build.gradle to include Play Core dependencies
APP_GRADLE="android/app/build.gradle"
if ! grep -q "play-core" "$APP_GRADLE"; then
    sed -i '/dependencies {/a \    implementation "com.google.android.play:core:1.10.3"' "$APP_GRADLE"
    sed -i '/dependencies {/a \    implementation "com.google.android.play:core-ktx:1.8.1"' "$APP_GRADLE"
fi

# Add Play Core ProGuard rules
PROGUARD_FILE="android/app/proguard-rules.pro"

cat >> "$PROGUARD_FILE" << 'EOL'

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**
EOL

echo "Play Core dependencies and ProGuard rules have been added"
