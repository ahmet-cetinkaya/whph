package me.ahmetcetinkaya.whph

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

class NotificationReceiver : BroadcastReceiver() {
  private val TAG = "NotificationReceiver"

  override fun onReceive(context: Context, intent: Intent) {
    Log.d(TAG, "Received intent with action: ${intent.action}")

    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED -> {
        Log.d(TAG, "Received BOOT_COMPLETED event - rescheduling notifications")
        try {
          // Initialize ReminderTracker and reschedule all notifications
          val reminderTracker = ReminderTracker(context)
          rescheduleAllNotifications(context, reminderTracker)

          // Notify Flutter about boot completed event if app is running
          notifyFlutterBootCompleted(context)
        } catch (e: Exception) {
          Log.e(TAG, "Error rescheduling notifications after boot: ${e.message}", e)
        }
      }
      Constants.IntentActions.NOTIFICATION_CLICKED -> {
        val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)
        val payload =
          intent.getStringExtra(Constants.IntentExtras.PAYLOAD)
            ?: intent.getStringExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)

        Log.d(TAG, "Notification clicked with ID: $notificationId, Payload: $payload")

        val launchIntent =
          Intent(context, MainActivity::class.java).apply {
            // Make sure we bring the app to foreground
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)

            // Set a debug action
            action = "${Constants.PACKAGE_NAME}.NOTIFICATION_CLICK"

            if (payload != null) {
              putExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD, payload)
            }
            putExtra(Constants.IntentExtras.NOTIFICATION_ID, notificationId)
          }

        try {
          Log.d(TAG, "Starting MainActivity with payload: $payload")
          context.startActivity(launchIntent)
        } catch (e: Exception) {
          Log.e(TAG, "Error starting MainActivity: ${e.message}")
        }
      }
      Constants.IntentActions.TASK_COMPLETE_ACTION -> {
        val taskId = intent.getStringExtra(Constants.IntentExtras.TASK_ID)
        val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)

        Log.d(TAG, "Task complete action: taskId=$taskId, notificationId=$notificationId")

        if (taskId != null) {
          handleTaskCompleteAction(context, taskId, notificationId)
        } else {
          Log.e(TAG, "Task ID is null in TASK_COMPLETE_ACTION")
        }
      }
      Constants.IntentActions.HABIT_COMPLETE_ACTION -> {
        val habitId = intent.getStringExtra(Constants.IntentExtras.HABIT_ID)
        val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)

        Log.d(TAG, "Habit complete action: habitId=$habitId, notificationId=$notificationId")

        if (habitId != null) {
          handleHabitCompleteAction(context, habitId, notificationId)
        } else {
          Log.e(TAG, "Habit ID is null in HABIT_COMPLETE_ACTION")
        }
      }
      Constants.IntentActions.ALARM_TRIGGERED -> {
        val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)
        val title = intent.getStringExtra(Constants.IntentExtras.TITLE) ?: "Reminder"
        val body = intent.getStringExtra(Constants.IntentExtras.BODY) ?: "You have a reminder"
        val payload = intent.getStringExtra(Constants.IntentExtras.PAYLOAD)
        val actionButtonText = intent.getStringExtra(Constants.IntentExtras.ACTION_BUTTON_TEXT)

        Log.d(TAG, "Alarm triggered for notification ID: $notificationId, payload: $payload")

        val notificationHelper = NotificationHelper(context)
        notificationHelper.showNotification(notificationId, title, body, payload, actionButtonText)
      }
      else -> {
        Log.d(TAG, "Received unhandled intent action: ${intent.action}")

        // Check if this is potentially a notification click with missing action
        if (intent.hasExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)) {
          val payload = intent.getStringExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)
          Log.d(TAG, "Found notification payload in intent without proper action: $payload")

          // Try to handle it anyway by forwarding to MainActivity
          val launchIntent =
            Intent(context, MainActivity::class.java).apply {
              addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                  Intent.FLAG_ACTIVITY_SINGLE_TOP or
                  Intent.FLAG_ACTIVITY_CLEAR_TOP
              )
              action = Constants.IntentActions.NOTIFICATION_CLICK
              putExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD, payload)
            }

          try {
            context.startActivity(launchIntent)
          } catch (e: Exception) {
            Log.e(TAG, "Error starting MainActivity for unhandled intent: ${e.message}")
          }
        }
      }
    }
  }

  /** Reschedule all stored notifications after device reboot */
  private fun rescheduleAllNotifications(context: Context, reminderTracker: ReminderTracker) {
    try {
      val allStoredNotifications = reminderTracker.getAllNotificationData()
      Log.d(TAG, "Found ${allStoredNotifications.size} notifications to reschedule")

      if (allStoredNotifications.isEmpty()) {
        Log.d(TAG, "No notifications to reschedule")
        return
      }

      val alarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager
      if (alarmManager == null) {
        Log.e(TAG, "AlarmManager not available")
        return
      }

      var rescheduledCount = 0
      val currentTime = System.currentTimeMillis()

      for (notificationData in allStoredNotifications) {
        try {
          // Skip notifications that are in the past
          if (notificationData.triggerTime <= currentTime) {
            Log.d(TAG, "Skipping past notification: ID=${notificationData.id}")
            // Remove expired notification from tracking
            reminderTracker.untrackReminder(notificationData.id)
            continue
          }

          // Create the intent for this notification
          val intent =
            android.content.Intent(context, NotificationReceiver::class.java).apply {
              action = Constants.IntentActions.ALARM_TRIGGERED
              putExtra(Constants.IntentExtras.NOTIFICATION_ID, notificationData.id)
              putExtra(Constants.IntentExtras.TITLE, notificationData.title)
              putExtra(Constants.IntentExtras.BODY, notificationData.body)
              putExtra(Constants.IntentExtras.PAYLOAD, notificationData.payload)
            }

          val pendingIntent =
            android.app.PendingIntent.getBroadcast(
              context,
              notificationData.id,
              intent,
              android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                android.app.PendingIntent.FLAG_IMMUTABLE,
            )

          // Reschedule the alarm
          if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
              android.app.AlarmManager.RTC_WAKEUP,
              notificationData.triggerTime,
              pendingIntent,
            )
          } else {
            alarmManager.setExact(
              android.app.AlarmManager.RTC_WAKEUP,
              notificationData.triggerTime,
              pendingIntent,
            )
          }

          rescheduledCount++
          Log.d(
            TAG,
            "Rescheduled notification: ID=${notificationData.id}, time=${java.util.Date(notificationData.triggerTime)}",
          )
        } catch (e: Exception) {
          Log.e(TAG, "Error rescheduling notification ID=${notificationData.id}: ${e.message}")
        }
      }

      Log.d(TAG, "Successfully rescheduled $rescheduledCount notifications")
    } catch (e: Exception) {
      Log.e(TAG, "Error in rescheduleAllNotifications: ${e.message}", e)
    }
  }

  /** Notify Flutter about boot completed event */
  private fun notifyFlutterBootCompleted(context: Context) {
    try {
      // Start MainActivity with a special flag to notify Flutter about boot completed
      val intent =
        android.content.Intent(context, MainActivity::class.java).apply {
          action = "BOOT_COMPLETED_NOTIFICATION"
          addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
          putExtra("boot_completed", true)
        }

      Log.d(TAG, "Sending boot completed notification to Flutter")
      context.startActivity(intent)
    } catch (e: Exception) {
      Log.e(TAG, "Error notifying Flutter about boot completed: ${e.message}")
    }
  }

  /** Handle task complete action from notification button */
  private fun handleTaskCompleteAction(context: Context, taskId: String, notificationId: Int) {
    handleCompleteAction(
      context = context,
      entityType = "Task",
      entityId = taskId,
      notificationId = notificationId,
      broadcastAction = Constants.IntentActions.TASK_COMPLETE_BROADCAST,
      extraKey = Constants.IntentExtras.TASK_ID,
      pendingPrefix = "complete_task_",
    )
  }

  /** Handle habit complete action from notification button */
  private fun handleHabitCompleteAction(context: Context, habitId: String, notificationId: Int) {
    handleCompleteAction(
      context = context,
      entityType = "Habit",
      entityId = habitId,
      notificationId = notificationId,
      broadcastAction = Constants.IntentActions.HABIT_COMPLETE_BROADCAST,
      extraKey = Constants.IntentExtras.HABIT_ID,
      pendingPrefix = "complete_habit_",
    )
  }

  /** Generic handler for complete actions (task or habit) */
  private fun handleCompleteAction(
    context: Context,
    entityType: String,
    entityId: String,
    notificationId: Int,
    broadcastAction: String,
    extraKey: String,
    pendingPrefix: String,
  ) {
    try {
      // Cancel the notification
      val notificationManager = NotificationManagerCompat.from(context)
      notificationManager.cancel(notificationId)

      Log.d(TAG, "$entityType completion triggered: $entityId")

      // Always store as pending first (in case broadcast fails or app not running)
      storePendingCompletion(context, entityId, pendingPrefix, entityType)

      // Send a broadcast to check if the app is running
      // MainActivity will handle this and send to Flutter, then clear the pending entry
      val broadcastIntent =
        Intent(broadcastAction).apply {
          putExtra(extraKey, entityId)
          setPackage(context.packageName) // Local broadcast within the app
        }

      context.sendBroadcast(broadcastIntent)
      Log.d(TAG, "Sent $entityType completion broadcast for: $entityId")
    } catch (e: Exception) {
      Log.e(TAG, "Error handling $entityType complete action: ${e.message}", e)
    }
  }

  /** Store task completion as pending for processing when app starts */
  private fun storePendingTaskCompletion(context: Context, taskId: String) {
    storePendingCompletion(context, taskId, "complete_task_", "Task")
  }

  /** Store habit completion as pending for processing when app starts */
  private fun storePendingHabitCompletion(context: Context, habitId: String) {
    storePendingCompletion(context, habitId, "complete_habit_", "Habit")
  }

  /** Generic method to store completion as pending for processing when app starts */
  private fun storePendingCompletion(
    context: Context,
    entityId: String,
    pendingPrefix: String,
    entityType: String,
  ) {
    try {
      val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
      prefs.edit().putString("$pendingPrefix$entityId", entityId).apply()
      Log.d(TAG, "Stored pending $entityType completion for processing on app startup: $entityId")
    } catch (e: Exception) {
      Log.e(TAG, "Error storing pending $entityType completion: ${e.message}", e)
    }
  }
}
