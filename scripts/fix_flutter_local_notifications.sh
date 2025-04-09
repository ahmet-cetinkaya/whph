#!/bin/bash

set -e
cd "$(dirname "$0")/.."

PUB_CACHE="${HOME}/.pub-cache"
PLUGIN_PATH="${PUB_CACHE}/hosted/pub.dev/flutter_local_notifications-19.0.0"

# Check if package exists
if [ ! -d "$PLUGIN_PATH" ]; then
    echo "Error: flutter_local_notifications package not found at $PLUGIN_PATH"
    exit 1
fi

# Path to the mobile_notification_service.dart file in your project
NOTIFICATION_SERVICE_PATH="lib/infrastructure/features/notification/mobile_notification_service.dart"

if [ -f "$NOTIFICATION_SERVICE_PATH" ]; then
    # Create backup
    cp "$NOTIFICATION_SERVICE_PATH" "${NOTIFICATION_SERVICE_PATH}.bak"
    
    # Replace the incorrect method name with the correct one
    sed -i 's/requestPermission()/requestNotificationsPermission()/' "$NOTIFICATION_SERVICE_PATH"
    echo "Successfully updated mobile_notification_service.dart - Changed requestPermission() to requestNotificationsPermission()"
else
    echo "mobile_notification_service.dart not found at $NOTIFICATION_SERVICE_PATH"
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
