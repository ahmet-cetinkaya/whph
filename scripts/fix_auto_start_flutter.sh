#!/bin/bash

set -e
cd "$(dirname "$0")/.."

PUB_CACHE="${HOME}/.pub-cache"
AUTO_START_PATH="${PUB_CACHE}/hosted/pub.dev/auto_start_flutter-0.1.3"
JAVA_FILE="${AUTO_START_PATH}/android/src/main/java/co/techFlow/auto_start_flutter/AutoStartFlutterPlugin.java"

# Check if file exists
if [ ! -f "$JAVA_FILE" ]; then
    echo "Error: AutoStartFlutterPlugin.java not found"
    exit 1
fi

# Create backup
cp "$JAVA_FILE" "${JAVA_FILE}.backup"

# Update the file to fix deprecation warnings
cat > "$JAVA_FILE" << 'EOL'
package co.techFlow.auto_start_flutter;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public class AutoStartFlutterPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "auto_start_flutter");
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("getAutoStartSettings")) {
            try {
                Intent intent = new Intent();
                String manufacturer = Build.MANUFACTURER;
                switch (manufacturer.toLowerCase()) {
                    case "xiaomi":
                        intent.setComponent(new ComponentName("com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity"));
                        break;
                    case "oppo":
                        intent.setComponent(new ComponentName("com.coloros.safecenter",
                                "com.coloros.safecenter.permission.startup.StartupAppListActivity"));
                        break;
                    case "vivo":
                        intent.setComponent(new ComponentName("com.vivo.permissionmanager",
                                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"));
                        break;
                    default:
                        result.success(false);
                        return;
                }
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                result.success(true);
            } catch (Exception e) {
                result.success(false);
            }
        } else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
EOL

echo "AutoStartFlutterPlugin.java has been updated and original file backed up as .backup"

# Fix build.gradle
GRADLE_FILE="${AUTO_START_PATH}/android/build.gradle"

# Check if gradle file exists
if [ ! -f "$GRADLE_FILE" ]; then
    echo "Error: build.gradle not found"
    exit 1
fi

# Create backup of build.gradle
cp "$GRADLE_FILE" "${GRADLE_FILE}.backup"

# Update build.gradle with correct configuration
cat > "$GRADLE_FILE" << 'EOL'
group 'co.techFlow.auto_start_flutter'
version '1.0'

buildscript {
    repositories {
        google()
        jcenter()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
    }
}

rootProject.allprojects {
    repositories {
        google()
        jcenter()
    }
}

apply plugin: 'com.android.library'

android {
    compileSdkVersion 33
    
    namespace "co.techFlow.auto_start_flutter"
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    defaultConfig {
        minSdkVersion 16
    }
    
    lintOptions {
        disable 'InvalidPackage'
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    implementation 'androidx.appcompat:appcompat:1.4.1'
}
EOL

echo "build.gradle has been updated and original file backed up as .backup"

# Fix R8/ProGuard rules
PROGUARD_FILE="android/app/proguard-rules.pro"

# Create or append to proguard-rules.pro
cat >> "$PROGUARD_FILE" << 'EOL'

# Keep auto_start_flutter classes
-keep class co.techFlow.auto_start_flutter.** { *; }
-keepclassmembers class co.techFlow.auto_start_flutter.** { *; }

# General Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
EOL

# Update app/build.gradle to ensure R8 uses the proguard rules
APP_GRADLE="android/app/build.gradle"
if ! grep -q "proguardFiles" "$APP_GRADLE"; then
    sed -i '/buildTypes {/,/}/ s/minifyEnabled true/minifyEnabled true\n            proguardFiles getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro"/' "$APP_GRADLE"
fi

# Call fix_play_core.sh
bash "$(dirname "$0")/fix_play_core.sh"

echo "AutoStartFlutterPlugin.java and Play Core dependencies have been updated"
echo "ProGuard rules have been updated"
