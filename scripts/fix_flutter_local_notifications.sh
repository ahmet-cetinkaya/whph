#!/bin/bash

set -e
cd "$(dirname "$0")/.."

PUB_CACHE="${HOME}/.pub-cache"
PLUGIN_PATH="${PUB_CACHE}/hosted/pub.dev/flutter_local_notifications-19.2.1"

# Check if package exists
if [ ! -d "$PLUGIN_PATH" ]; then
    echo "Error: flutter_local_notifications package not found at $PLUGIN_PATH"
    exit 1
fi

# Keep the original fix for completeness
NOTIFICATIONS_PATH="${PLUGIN_PATH}/android/src/main/java/com/dexterous/flutterlocalnotifications/FlutterLocalNotificationsPlugin.java"

if [ -f "$NOTIFICATIONS_PATH" ]; then
    # Create backup
    cp "$NOTIFICATIONS_PATH" "${NOTIFICATIONS_PATH}.bak"
    
    # Replace the ambiguous bigLargeIcon call with the Bitmap version
    sed -i 's/bigPictureStyle.bigLargeIcon(null);/bigPictureStyle.bigLargeIcon((Bitmap) null);/' "$NOTIFICATIONS_PATH"
    echo "Successfully modified FlutterLocalNotificationsPlugin.java"
else
    echo "FlutterLocalNotificationsPlugin.java not found at $NOTIFICATIONS_PATH"
    # Don't exit here, as the main fix might have worked
fi
