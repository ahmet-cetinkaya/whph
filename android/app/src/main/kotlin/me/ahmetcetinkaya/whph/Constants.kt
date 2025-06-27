package me.ahmetcetinkaya.whph

/**
 * Constants used throughout the application
 */
object Constants {
    // Package & Application Info
    const val PACKAGE_NAME = "me.ahmetcetinkaya.whph"
    
    // Method Channel Names
    object Channels {
        const val APP_INFO = "$PACKAGE_NAME/app_info"
        const val BACKGROUND_SERVICE = "$PACKAGE_NAME/background_service"
        const val BATTERY_OPTIMIZATION = "$PACKAGE_NAME/battery_optimization"
        const val EXACT_ALARM = "$PACKAGE_NAME/exact_alarm"
        const val NOTIFICATION = "$PACKAGE_NAME/notification"
        const val APP_USAGE_STATS = "$PACKAGE_NAME/app_usage_stats"
        const val BOOT_COMPLETED = "$PACKAGE_NAME/boot_completed"
    }

    // Notification Channels
    object NotificationChannels {
        // Task Reminders
        const val TASK_CHANNEL_ID = "whph_task_reminders"
        const val TASK_CHANNEL_NAME = "Task Reminders"
        
        // Habit Reminders
        const val HABIT_CHANNEL_ID = "whph_habit_reminders"
        const val HABIT_CHANNEL_NAME = "Habit Reminders"
        
        // Background Service
        const val SERVICE_CHANNEL_ID = "whph_background_service"
        const val SERVICE_CHANNEL_NAME = "System Tray"
    }

    // Intent Actions
    object IntentActions {
        const val NOTIFICATION_CLICKED = "$PACKAGE_NAME.NOTIFICATION_CLICKED"
        const val NOTIFICATION_CLICK = "$PACKAGE_NAME.NOTIFICATION_CLICK"
        const val ALARM_TRIGGERED = "$PACKAGE_NAME.ALARM_TRIGGERED"
    }

    // Intent Extras
    object IntentExtras {
        const val NOTIFICATION_ID = "notification_id"
        const val NOTIFICATION_PAYLOAD = "notification_payload"
        const val PAYLOAD = "payload"
        const val TITLE = "title"
        const val BODY = "body"
    }
}