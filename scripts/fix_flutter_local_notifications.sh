#!/bin/bash

# This script fixes the ambiguous method call in FlutterLocalNotificationsPlugin
# Specifically, it resolves the ambiguity between bigLargeIcon(Bitmap) and bigLargeIcon(Icon)
# by explicitly casting null to Bitmap

PUB_CACHE="${HOME}/.pub-cache"
NOTIFICATIONS_PATH="${PUB_CACHE}/hosted/pub.dev/flutter_local_notifications-15.1.3/android/src/main/java/com/dexterous/flutterlocalnotifications/FlutterLocalNotificationsPlugin.java"

if [ -f "$NOTIFICATIONS_PATH" ]; then
    # Replace the ambiguous bigLargeIcon call with the Bitmap version
    sed -i 's/bigPictureStyle.bigLargeIcon(null);/bigPictureStyle.bigLargeIcon((Bitmap) null);/' "$NOTIFICATIONS_PATH"
    echo "Successfully modified FlutterLocalNotificationsPlugin.java"
else
    echo "FlutterLocalNotificationsPlugin.java not found. Please check the package path."
    exit 1
fi
