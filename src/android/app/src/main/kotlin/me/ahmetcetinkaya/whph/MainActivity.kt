package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Simplified MainActivity using handler-provided method call handlers. Each handler knows how to
 * handle its own method channel calls.
 */
class MainActivity : FlutterActivity() {

  private val TAG = "MainActivity"

  // All handlers
  private val handlers by lazy {
    mapOf(
      "appInfo" to me.ahmetcetinkaya.whph.handlers.AppInfoHandler(context),
      "battery" to me.ahmetcetinkaya.whph.handlers.BatteryOptimizationHandler(context),
      "alarm" to me.ahmetcetinkaya.whph.handlers.ExactAlarmHandler(context),
      "notification" to me.ahmetcetinkaya.whph.handlers.NotificationMethodHandler(context),
      "workManager" to me.ahmetcetinkaya.whph.handlers.WorkManagerHandler(context),
      "sync" to me.ahmetcetinkaya.whph.handlers.SyncWorkManagerHandler(context),
      "share" to me.ahmetcetinkaya.whph.handlers.ShareIntentHandler(context),
      "boot" to me.ahmetcetinkaya.whph.handlers.BootCompletedHandler(context),
      "usage" to me.ahmetcetinkaya.whph.handlers.AppUsageStatsMethodHandler(context),
    )
  }

  private lateinit var intentProcessor: me.ahmetcetinkaya.whph.intent.IntentProcessor
  private val pendingCollectionHandler = android.os.Handler(android.os.Looper.getMainLooper())

  // Broadcast receivers
  private val receivers by lazy {
    mapOf(
      "sync" to me.ahmetcetinkaya.whph.receivers.SyncTriggerReceiver(),
      "task" to me.ahmetcetinkaya.whph.receivers.TaskCompletionReceiver(),
      "habit" to me.ahmetcetinkaya.whph.receivers.HabitCompletionReceiver(),
    )
  }

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    val startIntent = intent
    super.onCreate(savedInstanceState)

    intentProcessor =
      me.ahmetcetinkaya.whph.intent.IntentProcessor(
        context,
        handlers["notification"] as? me.ahmetcetinkaya.whph.handlers.NotificationMethodHandler
          ?: throw IllegalStateException("NotificationMethodHandler not found"),
        handlers["share"] as? me.ahmetcetinkaya.whph.handlers.ShareIntentHandler
          ?: throw IllegalStateException("ShareIntentHandler not found"),
        handlers["boot"] as? me.ahmetcetinkaya.whph.handlers.BootCompletedHandler
          ?: throw IllegalStateException("BootCompletedHandler not found"),
      )

    registerReceivers()
    intentProcessor.processIntent(startIntent)
    startPendingCollectionCheck()
  }

  override fun onNewIntent(intent: android.content.Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    intentProcessor.processIntent(intent, flutterEngine)
  }

  override fun configureFlutterEngine(
    @NonNull flutterEngine: io.flutter.embedding.engine.FlutterEngine
  ) {
    super.configureFlutterEngine(flutterEngine)

    // Update Flutter engine in receivers
    me.ahmetcetinkaya.whph.receivers.SyncTriggerReceiver.setFlutterEngine(flutterEngine)
    me.ahmetcetinkaya.whph.receivers.TaskCompletionReceiver.setFlutterEngine(flutterEngine)
    me.ahmetcetinkaya.whph.receivers.HabitCompletionReceiver.setFlutterEngine(flutterEngine)

    // Deliver pending payloads
    val notificationHandler =
      handlers["notification"] as? me.ahmetcetinkaya.whph.handlers.NotificationMethodHandler
        ?: throw IllegalStateException("NotificationMethodHandler not found")
    val shareHandler =
      handlers["share"] as? me.ahmetcetinkaya.whph.handlers.ShareIntentHandler
        ?: throw IllegalStateException("ShareIntentHandler not found")

    notificationHandler.initialNotificationPayload?.let {
      intentProcessor.notifyFlutterOfPayload(it, flutterEngine.dartExecutor.binaryMessenger)
    }

    shareHandler.initialShareText?.let {
      intentProcessor.notifyFlutterOfShare(
        it,
        shareHandler.initialShareSubject,
        flutterEngine.dartExecutor.binaryMessenger,
      )
    }

    // Setup all channels
    setupChannels(flutterEngine)
  }

  override fun onDestroy() {
    unregisterReceivers()
    // Clear static FlutterEngine references to prevent memory leaks
    me.ahmetcetinkaya.whph.receivers.SyncTriggerReceiver.setFlutterEngine(null)
    me.ahmetcetinkaya.whph.receivers.TaskCompletionReceiver.setFlutterEngine(null)
    me.ahmetcetinkaya.whph.receivers.HabitCompletionReceiver.setFlutterEngine(null)
    // Stop pending collection checks to prevent Handler leaks
    pendingCollectionHandler.removeCallbacksAndMessages(null)
    try {
      (getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager).cancel(
        PENDING_NOTIFICATION_ID
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error cancelling notification: ${e.message}")
    }
    super.onDestroy()
  }

  private fun setupChannels(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
    val m = flutterEngine.dartExecutor.binaryMessenger

    // App Info
    MethodChannel(m, Constants.Channels.APP_INFO).setMethodCallHandler { call, result ->
      val h =
        handlers["appInfo"] as? me.ahmetcetinkaya.whph.handlers.AppInfoHandler
          ?: run {
            result.error("INTERNAL_ERROR", "AppInfoHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "getAppName" ->
          result.success(
            h.getAppName(
              call.argument("packageName")
                ?: return@setMethodCallHandler result.error("ERROR", "packageName is null", null)
            )
          )
        "getInstalledApps" -> result.success(h.getInstalledApps())
        "isRunningInWorkProfile" -> result.success(h.isRunningInWorkProfile())
        else -> result.notImplemented()
      }
    }

    // Battery
    MethodChannel(m, Constants.Channels.BATTERY_OPTIMIZATION).setMethodCallHandler { call, result ->
      val h =
        handlers["battery"] as? me.ahmetcetinkaya.whph.handlers.BatteryOptimizationHandler
          ?: run {
            result.error("INTERNAL_ERROR", "BatteryOptimizationHandler not found", null)
            return@setMethodCallHandler
          }
      if (call.method == "isIgnoringBatteryOptimizations")
        result.success(h.isIgnoringBatteryOptimizations())
      else result.notImplemented()
    }

    // Exact Alarm
    MethodChannel(m, Constants.Channels.EXACT_ALARM).setMethodCallHandler { call, result ->
      val h =
        handlers["alarm"] as? me.ahmetcetinkaya.whph.handlers.ExactAlarmHandler
          ?: run {
            result.error("INTERNAL_ERROR", "ExactAlarmHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "canScheduleExactAlarms" -> result.success(h.canScheduleExactAlarms())
        "checkExactAlarmPermission" -> result.success(h.checkExactAlarmPermission())
        "testExactAlarmPermission" -> result.success(h.testExactAlarmPermission())
        "openExactAlarmsSettings" -> result.success(h.openExactAlarmsSettings())
        else -> result.notImplemented()
      }
    }

    // Boot Completed
    MethodChannel(m, Constants.Channels.BOOT_COMPLETED).setMethodCallHandler { call, result ->
      when (call.method) {
        "onBootCompleted" -> result.success(true)
        else -> result.notImplemented()
      }
    }

    // Notification (large handler - inline for compactness)
    MethodChannel(m, Constants.Channels.NOTIFICATION).setMethodCallHandler { call, result ->
      val h =
        handlers["notification"] as? me.ahmetcetinkaya.whph.handlers.NotificationMethodHandler
          ?: run {
            result.error("INTERNAL_ERROR", "NotificationMethodHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "getInitialNotificationPayload" -> result.success(h.initialNotificationPayload)
        "acknowledgePayload" -> result.success(h.acknowledgePayload(call.arguments as? String))
        "showDirectNotification" -> {
          val success =
            h.showDirectNotification(
              call.argument("id") ?: 0,
              call.argument("title") ?: "Notification",
              call.argument("body") ?: "You have a notification",
              call.argument("payload"),
              call.argument("actionButtonText"),
            )
          result.success(success)
        }
        "scheduleDirectNotification" -> {
          val success =
            h.scheduleDirectNotification(
              call.argument("id") ?: 0,
              call.argument("title") ?: "Reminder",
              call.argument("body") ?: "You have a reminder",
              call.argument("payload"),
              call.argument("delaySeconds") ?: 10,
              call.argument("actionButtonText"),
            )
          result.success(success)
        }
        "cancelNotification" -> result.success(h.cancelNotification(call.argument("id") ?: 0))
        "cancelAllNotifications" -> result.success(h.cancelAllNotifications())
        "cancelNotificationsWithPattern" ->
          result.success(
            h.cancelNotificationsWithPattern(call.argument("startsWith"), call.argument("contains"))
          )
        "getActiveNotificationIds" -> result.success(h.getActiveNotificationIds())
        "completeTask",
        "completeHabit" -> result.success(null)
        "getPendingTaskCompletions" -> result.success(h.getPendingTaskCompletions())
        "clearPendingTaskCompletion" ->
          result.success(
            h.clearPendingTaskCompletion(
              call.arguments as? String
                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "id is required", null)
            )
          )
        "getPendingHabitCompletions" -> result.success(h.getPendingHabitCompletions())
        "clearPendingHabitCompletion" ->
          result.success(
            h.clearPendingHabitCompletion(
              call.arguments as? String
                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "id is required", null)
            )
          )
        "getRetryCount" ->
          result.success(
            h.getRetryCount(
              call.arguments as? String
                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "key is required", null)
            )
          )
        "setRetryCount" -> {
          @Suppress("UNCHECKED_CAST")
          val args =
            call.arguments as? Map<String, Any>
              ?: return@setMethodCallHandler result.error("INVALID_ARGS", "args is required", null)
          result.success(
            h.setRetryCount(
              args["key"] as? String
                ?: return@setMethodCallHandler result.error(
                  "INVALID_ARGS",
                  "key is required",
                  null,
                ),
              args["count"] as? Int
                ?: return@setMethodCallHandler result.error(
                  "INVALID_ARGS",
                  "count is required",
                  null,
                ),
            )
          )
        }
        "clearRetryCount" ->
          result.success(
            h.clearRetryCount(
              call.arguments as? String
                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "key is required", null)
            )
          )
        else -> result.notImplemented()
      }
    }

    // App Usage Stats
    MethodChannel(m, Constants.Channels.APP_USAGE_STATS).setMethodCallHandler { call, result ->
      val h =
        handlers["usage"] as? me.ahmetcetinkaya.whph.handlers.AppUsageStatsMethodHandler
          ?: run {
            result.error("INTERNAL_ERROR", "AppUsageStatsMethodHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "checkUsageStatsPermission" -> result.success(h.checkUsageStatsPermission())
        "openUsageAccessSettings" -> result.success(h.openUsageAccessSettings())
        "getAccurateForegroundUsage" -> {
          val data =
            h.getAccurateForegroundUsage(
              call.argument("startTime")
                ?: return@setMethodCallHandler result.error(
                  "INVALID_ARGS",
                  "startTime is required",
                  null,
                ),
              call.argument("endTime")
                ?: return@setMethodCallHandler result.error(
                  "INVALID_ARGS",
                  "endTime is required",
                  null,
                ),
            )
          if (data != null) result.success(data)
          else result.error("USAGE_ERROR", "Failed to get usage data", null)
        }
        "getTodayForegroundUsage" -> {
          val data = h.getTodayForegroundUsage()
          if (data != null) result.success(data)
          else result.error("PRECISION_USAGE_ERROR", "Failed to get today's usage", null)
        }
        else -> result.notImplemented()
      }
    }

    // Work Manager
    MethodChannel(m, Constants.Channels.WORK_MANAGER).setMethodCallHandler { call, result ->
      val h =
        handlers["workManager"] as? me.ahmetcetinkaya.whph.handlers.WorkManagerHandler
          ?: run {
            result.error("INTERNAL_ERROR", "WorkManagerHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "startPeriodicAppUsageWork" ->
          result.success(
            h.startPeriodicAppUsageWork(call.argument<Int>("intervalMinutes")?.toLong())
          )
        "stopPeriodicAppUsageWork" -> result.success(h.stopPeriodicAppUsageWork())
        "isWorkScheduled" -> result.success(h.isWorkScheduled())
        "checkPendingCollection" -> result.success(h.checkPendingCollection(m))
        else -> result.notImplemented()
      }
    }

    // Sync
    MethodChannel(m, Constants.Channels.SYNC).setMethodCallHandler { call, result ->
      val h =
        handlers["sync"] as? me.ahmetcetinkaya.whph.handlers.SyncWorkManagerHandler
          ?: run {
            result.error("INTERNAL_ERROR", "SyncWorkManagerHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "startPeriodicSyncWork" ->
          result.success(h.startPeriodicSyncWork(call.argument<Int>("intervalMinutes")?.toLong()))
        "stopPeriodicSyncWork" -> result.success(h.stopPeriodicSyncWork())
        "isSyncWorkScheduled" -> result.success(h.isSyncWorkScheduled())
        "checkPendingSync" -> result.success(h.checkPendingSync())
        else -> result.notImplemented()
      }
    }

    // Share
    MethodChannel(m, Constants.Channels.SHARE).setMethodCallHandler { call, result ->
      val h =
        handlers["share"] as? me.ahmetcetinkaya.whph.handlers.ShareIntentHandler
          ?: run {
            result.error("INTERNAL_ERROR", "ShareIntentHandler not found", null)
            return@setMethodCallHandler
          }
      when (call.method) {
        "getInitialShareIntent" -> result.success(h.getInitialShareIntent())
        "acknowledgeShareIntent" -> {
          h.acknowledgeShareIntent()
          result.success(true)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun registerReceivers() {
    val hasTiramisu = android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU
    listOf(
        me.ahmetcetinkaya.whph.receivers.SyncTriggerReceiver.createIntentFilter() to
          receivers["sync"]!!,
        me.ahmetcetinkaya.whph.receivers.TaskCompletionReceiver.createIntentFilter() to
          receivers["task"]!!,
        me.ahmetcetinkaya.whph.receivers.HabitCompletionReceiver.createIntentFilter() to
          receivers["habit"]!!,
      )
      .forEach { (filter, receiver) ->
        if (hasTiramisu)
          registerReceiver(
            receiver as android.content.BroadcastReceiver,
            filter,
            Context.RECEIVER_NOT_EXPORTED,
          )
        else registerReceiver(receiver as android.content.BroadcastReceiver, filter)
      }
  }

  private fun unregisterReceivers() {
    receivers.values.forEach { receiver ->
      try {
        unregisterReceiver(receiver as android.content.BroadcastReceiver)
      } catch (e: Exception) {
        Log.e(TAG, "Error unregistering: ${e.message}")
      }
    }
  }

  private fun startPendingCollectionCheck() {
    pendingCollectionHandler.post(
      object : Runnable {
        override fun run() {
          try {
            val h = handlers["workManager"] as? me.ahmetcetinkaya.whph.handlers.WorkManagerHandler
            if (h != null) {
              h.checkPendingCollection(flutterEngine?.dartExecutor?.binaryMessenger)
            } else {
              Log.e(TAG, "WorkManagerHandler not found")
            }
          } catch (e: Exception) {
            Log.e(TAG, "Error in pending collection check: ${e.message}", e)
          }
          pendingCollectionHandler.postDelayed(this, PENDING_COLLECTION_CHECK_INTERVAL_MS)
        }
      }
    )
  }

  companion object {
    const val ACTION_NOTIFICATION_CLICK = "${Constants.PACKAGE_NAME}.NOTIFICATION_CLICK"
    const val ACTION_SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
    private const val PENDING_NOTIFICATION_ID = 888 // Notification ID for pending notifications
    private const val PENDING_COLLECTION_CHECK_INTERVAL_MS =
      30000L // Check interval in milliseconds
  }
}
