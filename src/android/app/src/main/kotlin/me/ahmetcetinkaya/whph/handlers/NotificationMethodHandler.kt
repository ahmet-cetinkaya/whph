package me.ahmetcetinkaya.whph.handlers

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import me.ahmetcetinkaya.whph.Constants
import me.ahmetcetinkaya.whph.NotificationHelper
import me.ahmetcetinkaya.whph.NotificationReceiver
import me.ahmetcetinkaya.whph.ReminderTracker

/**
 * Handler for notification-related method channel operations. Provides methods for showing,
 * scheduling, canceling notifications, and managing completions.
 */
class NotificationMethodHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "NotificationMethodHandler"
  private val reminderTracker by lazy { ReminderTracker(context) }

  // Store the initial notification payload
  var initialNotificationPayload: String? = null
    private set

  /**
   * Acknowledge that the notification payload has been processed.
   *
   * @param payload The payload to acknowledge
   * @return true if the payload matched and was cleared, false otherwise
   */
  fun acknowledgePayload(payload: String?): Boolean {
    Log.d(TAG, "Acknowledging payload: $payload")
    if (payload == initialNotificationPayload) {
      initialNotificationPayload = null
      Log.d(TAG, "Cleared initial notification payload")
      return true
    }
    Log.d(TAG, "Payload did not match, acknowledgement failed")
    return false
  }

  /** Set the initial notification payload (used by IntentProcessor). */
  fun setInitialNotificationPayload(payload: String?) {
    initialNotificationPayload = payload
    Log.d(TAG, "Set initial notification payload: $payload")
  }

  /** Show a direct notification. */
  fun showDirectNotification(
    id: Int,
    title: String,
    body: String,
    payload: String?,
    actionButtonText: String?,
  ): Boolean =
    try {
      val notificationHelper = NotificationHelper(context)
      notificationHelper.showNotification(id, title, body, payload, actionButtonText)
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error showing direct notification: ${e.message}", e)
      false
    }

  /** Schedule a direct notification with an alarm. */
  fun scheduleDirectNotification(
    id: Int,
    title: String,
    body: String,
    payload: String?,
    delaySeconds: Int,
    actionButtonText: String?,
  ): Boolean {
    return try {
      val intent =
        Intent(context, NotificationReceiver::class.java).apply {
          action = Constants.IntentActions.ALARM_TRIGGERED
          putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
          putExtra(Constants.IntentExtras.TITLE, title)
          putExtra(Constants.IntentExtras.BODY, body)
          putExtra(Constants.IntentExtras.PAYLOAD, payload)
          if (actionButtonText != null) {
            putExtra(Constants.IntentExtras.ACTION_BUTTON_TEXT, actionButtonText)
          }
        }

      val pendingIntent =
        PendingIntent.getBroadcast(
          context,
          id,
          intent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

      val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      val currentTimeMillis = System.currentTimeMillis()
      val triggerTimeMillis = currentTimeMillis + (delaySeconds * 1000L)

      // Extract the reminderId from the payload if present (needed for logging)
      var reminderId: String? = null
      try {
        if (payload != null) {
          val payloadObj = org.json.JSONObject(payload)
          reminderId = payloadObj.optString("reminderId", null)
        }
      } catch (e: Exception) {
        // Ignore parsing errors for logging
      }

      // Log scheduling details for debugging
      Log.d(TAG, "📅 Scheduling notification with ID: $id")
      Log.d(TAG, "  - Current time: ${java.util.Date(currentTimeMillis)}")
      Log.d(TAG, "  - Delay seconds: $delaySeconds")
      Log.d(TAG, "  - Trigger time: ${java.util.Date(triggerTimeMillis)}")
      Log.d(TAG, "  - Reminder ID: $reminderId")

      // Validate that trigger time is in the future
      if (triggerTimeMillis <= currentTimeMillis) {
        Log.e(
          TAG,
          "ERROR: Trigger time is not in the future! triggerTime=$triggerTimeMillis, currentTime=$currentTimeMillis",
        )
        return false
      }

      // Check exact alarm permission for Android 12+
      val canScheduleExactAlarms =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
          alarmManager.canScheduleExactAlarms()
        } else {
          true
        }

      Log.d(TAG, "  - Can schedule exact alarms: $canScheduleExactAlarms")

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        if (canScheduleExactAlarms) {
          alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerTimeMillis,
            pendingIntent,
          )
          Log.d(TAG, "  - Used: setExactAndAllowWhileIdle")
        } else {
          // Fallback for devices without exact alarm permission
          alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerTimeMillis,
            pendingIntent,
          )
          Log.d(TAG, "  - Used: setAndAllowWhileIdle (fallback)")
        }
      } else {
        alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
        Log.d(TAG, "  - Used: setExact")
      }

      // Track the reminder for pattern-based cancellation
      // Extract metadata from the payload if present
      var metadata: String? = null

      try {
        if (payload != null) {
          val payloadObj = org.json.JSONObject(payload)

          // Extract relevant metadata for filtering (taskId, habitId, etc.)
          if (payloadObj.has("arguments")) {
            val args = payloadObj.getJSONObject("arguments")
            if (args.has("taskId")) {
              metadata = "taskId:${args.getString("taskId")}"
            } else if (args.has("habitId")) {
              metadata = "habitId:${args.getString("habitId")}"
            }
          }
        }
      } catch (e: Exception) {
        Log.d(TAG, "Non-JSON payload or error parsing: ${e.message}")
      }

      // Use the enhanced notification tracking method
      reminderTracker.trackNotification(
        id = id,
        title = title,
        body = body,
        payload = payload,
        triggerTime = triggerTimeMillis,
        reminderId = reminderId,
        metadata = metadata,
      )

      true
    } catch (e: Exception) {
      Log.e(TAG, "Error scheduling direct notification: ${e.message}", e)
      false
    }
  }

  /** Cancel a notification by ID. */
  fun cancelNotification(id: Int): Boolean =
    try {
      // Get the alarm manager
      val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

      // Create a matching PendingIntent to cancel
      val intent =
        Intent(context, NotificationReceiver::class.java).apply {
          action = Constants.IntentActions.ALARM_TRIGGERED
          putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
        }

      val pendingIntent =
        PendingIntent.getBroadcast(
          context,
          id,
          intent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

      // Cancel the alarm
      alarmManager.cancel(pendingIntent)

      // Also cancel any displayed notification
      val notificationManager = NotificationManagerCompat.from(context)
      notificationManager.cancel(id)

      Log.d(TAG, "Successfully canceled notification with ID: $id")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error canceling notification: ${e.message}", e)
      false
    }

  /** Cancel all notifications. */
  fun cancelAllNotifications(): Boolean =
    try {
      // Get all tracked reminder IDs
      val reminderIds = reminderTracker.getReminderIds()

      // Cancel all alarms related to notifications
      val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

      // Cancel each tracked reminder
      if (reminderIds.isNotEmpty()) {
        Log.d(TAG, "Found ${reminderIds.size} reminders to cancel")

        for (idStr in reminderIds) {
          try {
            val id = idStr.toInt()

            // Create a matching PendingIntent to cancel
            val intent =
              Intent(context, NotificationReceiver::class.java).apply {
                action = Constants.IntentActions.ALARM_TRIGGERED
                putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
              }

            val pendingIntent =
              PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
              )

            // Cancel the alarm
            alarmManager.cancel(pendingIntent)

            Log.d(TAG, "Canceled alarm for reminder ID: $id")
          } catch (e: Exception) {
            Log.e(TAG, "Error canceling specific alarm $idStr: ${e.message}")
          }
        }
      }

      // Cancel all displayed notifications
      val notificationManager = NotificationManagerCompat.from(context)
      notificationManager.cancelAll()

      // Clear all tracked reminders
      reminderTracker.clearAll()

      Log.d(TAG, "Successfully canceled all notifications and alarms")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error canceling all notifications: ${e.message}", e)
      false
    }

  /** Cancel notifications matching a pattern. */
  fun cancelNotificationsWithPattern(startsWith: String?, contains: String?): Boolean =
    try {
      // Use our ReminderTracker to find matching reminders
      val matchingIds = reminderTracker.findRemindersByPattern(startsWith, contains)

      if (matchingIds.isNotEmpty()) {
        Log.d(TAG, "Found ${matchingIds.size} reminders matching pattern")

        // Get necessary services
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val notificationManager = NotificationManagerCompat.from(context)

        // Cancel each matching reminder
        for (id in matchingIds) {
          try {
            // Create a matching PendingIntent to cancel
            val intent =
              Intent(context, NotificationReceiver::class.java).apply {
                action = Constants.IntentActions.ALARM_TRIGGERED
                putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
              }

            val pendingIntent =
              PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
              )

            // Cancel the alarm
            alarmManager.cancel(pendingIntent)

            // Also cancel any displayed notification
            notificationManager.cancel(id)

            // Remove from tracking
            reminderTracker.untrackReminder(id)

            Log.d(TAG, "Canceled reminder with ID: $id")
          } catch (e: Exception) {
            Log.e(TAG, "Error canceling specific reminder $id: ${e.message}")
          }
        }

        true
      } else {
        Log.d(TAG, "No reminders matched the pattern")
        false
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error canceling notifications with pattern: ${e.message}", e)
      false
    }

  /** Get active notification IDs. */
  fun getActiveNotificationIds(): List<String> =
    try {
      val activeNotificationIds =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
          notificationManager.activeNotifications.map { notification -> notification.id.toString() }
        } else {
          // On older Android versions, we don't have a reliable way to get active notifications
          emptyList<String>()
        }

      Log.d(TAG, "Active notification IDs: $activeNotificationIds")
      activeNotificationIds
    } catch (e: Exception) {
      Log.e(TAG, "Error getting active notification IDs: ${e.message}", e)
      emptyList()
    }

  /** Get pending task completions. */
  fun getPendingTaskCompletions(): List<String> = getPendingCompletions("complete_task_", "Task")

  /** Clear a pending task completion. */
  fun clearPendingTaskCompletion(taskId: String): Boolean =
    clearPendingCompletion("complete_task_", "Task", "taskId", taskId)

  /** Get pending habit completions. */
  fun getPendingHabitCompletions(): List<String> = getPendingCompletions("complete_habit_", "Habit")

  /** Clear a pending habit completion. */
  fun clearPendingHabitCompletion(habitId: String): Boolean =
    clearPendingCompletion("complete_habit_", "Habit", "habitId", habitId)

  /** Get retry count for a pending completion. */
  fun getRetryCount(key: String): Int =
    try {
      val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
      prefs.getInt(key, 0)
    } catch (e: Exception) {
      Log.e(TAG, "Error getting retry count: ${e.message}", e)
      0
    }

  /** Set retry count for a pending completion. */
  fun setRetryCount(key: String, count: Int): Boolean =
    try {
      val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
      prefs.edit().putInt(key, count).apply()
      Log.d(TAG, "Set retry count: $key = $count")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error setting retry count: ${e.message}", e)
      false
    }

  /** Clear retry count for a pending completion. */
  fun clearRetryCount(key: String): Boolean =
    try {
      val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
      prefs.edit().remove(key).apply()
      Log.d(TAG, "Cleared retry count: $key")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error clearing retry count: ${e.message}", e)
      false
    }

  // Private helper methods

  private fun getPendingCompletions(pendingPrefix: String, entityName: String): List<String> =
    try {
      val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
      val allKeys = prefs.all.keys.filter { it.startsWith(pendingPrefix) }
      val entityIds = allKeys.map { it.removePrefix(pendingPrefix) }
      Log.d(TAG, "Found ${entityIds.size} pending $entityName completions: $entityIds")
      entityIds
    } catch (e: Exception) {
      Log.e(TAG, "Error getting pending $entityName completions: ${e.message}", e)
      emptyList()
    }

  private fun clearPendingCompletion(
    pendingPrefix: String,
    entityName: String,
    idParamName: String,
    entityId: String,
  ): Boolean =
    try {
      val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
      prefs.edit().remove("$pendingPrefix$entityId").apply()
      Log.d(TAG, "Cleared pending $entityName completion: $entityId")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error clearing pending $entityName completion: ${e.message}", e)
      false
    }
}
