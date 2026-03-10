package me.ahmetcetinkaya.whph

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AppUsageAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    Log.d(TAG, "onReceive called with action: ${intent.action}")

    when (intent.action) {
      ACTION_COLLECT_APP_USAGE -> {
        // Collect app usage data
        collectAppUsageData(context)
        // Schedule the next alarm
        scheduleNextAlarm(context)
      }
    }
  }

  /** Collects app usage data by setting a flag that MainActivity will check */
  private fun collectAppUsageData(context: Context) {
    try {
      Log.d(TAG, "Setting app usage collection flag")

      // Set a flag in SharedPreferences that MainActivity will check
      val sharedPreferences = context.getSharedPreferences(SHARED_PREFS_NAME, Context.MODE_PRIVATE)
      sharedPreferences
        .edit()
        .putBoolean("should_collect_usage", true)
        .putLong("collection_timestamp", System.currentTimeMillis())
        .apply()

      Log.d(TAG, "App usage collection flag set successfully")
    } catch (e: Exception) {
      Log.e(TAG, "Error setting app usage collection flag", e)
    }
  }

  companion object {
    private const val TAG = "AppUsageAlarmReceiver"
    private const val ACTION_COLLECT_APP_USAGE = "me.ahmetcetinkaya.whph.COLLECT_APP_USAGE"
    private const val REQUEST_CODE = 1001
    private const val SHARED_PREFS_NAME = "app_usage_alarm"

    /**
     * Schedules periodic app usage data collection using AlarmManager
     *
     * @param context Application context
     * @param intervalMinutes Interval between collections in minutes (default: 30)
     */
    fun schedulePeriodicCollection(context: Context, intervalMinutes: Long = 30) {
      try {
        Log.d(
          TAG,
          "Scheduling periodic app usage collection with interval: $intervalMinutes minutes",
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent =
          Intent(context, AppUsageAlarmReceiver::class.java).apply {
            action = ACTION_COLLECT_APP_USAGE
          }

        val pendingIntent =
          PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
          )

        val triggerTime = System.currentTimeMillis() + (intervalMinutes * 60 * 1000)

        // Use appropriate alarm method based on Android version
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerTime,
            pendingIntent,
          )
        } else {
          alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }

        Log.d(TAG, "Alarm scheduled successfully for ${java.util.Date(triggerTime)}")
      } catch (e: Exception) {
        Log.e(TAG, "Error scheduling periodic collection", e)
      }
    }

    /**
     * Schedules the next alarm for app usage collection
     *
     * @param context Application context
     */
    private fun scheduleNextAlarm(context: Context) {
      schedulePeriodicCollection(context, 30) // Every 30 minutes
    }

    /**
     * Cancels the periodic app usage collection alarm
     *
     * @param context Application context
     */
    fun cancelPeriodicCollection(context: Context) {
      try {
        Log.d(TAG, "Cancelling periodic app usage collection")

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AppUsageAlarmReceiver::class.java)
        val pendingIntent =
          PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
          )
        alarmManager.cancel(pendingIntent)

        Log.d(TAG, "Periodic collection cancelled successfully")
      } catch (e: Exception) {
        Log.e(TAG, "Error cancelling periodic collection", e)
      }
    }

    /**
     * Checks if periodic collection is currently scheduled
     *
     * @param context Application context
     * @return true if alarm is scheduled, false otherwise
     */
    fun isCollectionScheduled(context: Context): Boolean =
      try {
        val intent = Intent(context, AppUsageAlarmReceiver::class.java)
        val pendingIntent =
          PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
          )
        pendingIntent != null
      } catch (e: Exception) {
        Log.e(TAG, "Error checking if collection is scheduled", e)
        false
      }
  }
}
