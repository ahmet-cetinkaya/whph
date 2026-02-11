package me.ahmetcetinkaya.whph

/** Constants used throughout the application */
object Constants {
  // Package & Application Info
  const val PACKAGE_NAME = "me.ahmetcetinkaya.whph"

  // Method Channel Names
  object Channels {
    const val APP_INFO = "$PACKAGE_NAME/app_info"

    const val BATTERY_OPTIMIZATION = "$PACKAGE_NAME/battery_optimization"
    const val EXACT_ALARM = "$PACKAGE_NAME/exact_alarm"
    const val NOTIFICATION = "$PACKAGE_NAME/notification"
    const val APP_USAGE_STATS = "$PACKAGE_NAME/app_usage_stats"
    const val BOOT_COMPLETED = "$PACKAGE_NAME/boot_completed"
    const val WORK_MANAGER = "$PACKAGE_NAME/work_manager"
    const val SYNC = "$PACKAGE_NAME/sync"
    const val SHARE = "$PACKAGE_NAME/share"
  }

  // WorkManager
  object WorkManager {
    const val SYNC_WORK_NAME = "periodic_sync_work"
    const val SYNC_WORKER_TAG = "sync_worker"
  }

  // Notification Channels
  object NotificationChannels {
    // Task Reminders
    const val TASK_CHANNEL_ID = "whph_task_reminders"
    const val TASK_CHANNEL_NAME = "Task Reminders"

    // Habit Reminders
    const val HABIT_CHANNEL_ID = "whph_habit_reminders"
    const val HABIT_CHANNEL_NAME = "Habit Reminders"
  }

  // Intent Actions
  object IntentActions {
    const val NOTIFICATION_CLICKED = "$PACKAGE_NAME.NOTIFICATION_CLICKED"
    const val NOTIFICATION_CLICK = "$PACKAGE_NAME.NOTIFICATION_CLICK"
    const val ALARM_TRIGGERED = "$PACKAGE_NAME.ALARM_TRIGGERED"
    const val TASK_COMPLETE_ACTION = "$PACKAGE_NAME.TASK_COMPLETE"
    const val TASK_COMPLETE_BROADCAST = "$PACKAGE_NAME.TASK_COMPLETE_BROADCAST"
    const val HABIT_COMPLETE_ACTION = "$PACKAGE_NAME.HABIT_COMPLETE"
    const val HABIT_COMPLETE_BROADCAST = "$PACKAGE_NAME.HABIT_COMPLETE_BROADCAST"
  }

  // Intent Extras
  object IntentExtras {
    const val NOTIFICATION_ID = "notification_id"
    const val NOTIFICATION_PAYLOAD = "notification_payload"
    const val PAYLOAD = "payload"
    const val TITLE = "title"
    const val BODY = "body"
    const val TASK_ID = "task_id"
    const val HABIT_ID = "habit_id"
    const val ACTION_BUTTON_TEXT = "action_button_text"
  }
}
