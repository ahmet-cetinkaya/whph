package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.AppUsageWorker

/**
 * Handler for WorkManager app usage tracking operations. Delegates to AppUsageWorker for scheduling
 * and managing periodic app usage collection.
 */
class WorkManagerHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "WorkManagerHandler"
  private val sharedPrefs: SharedPreferences =
    context.getSharedPreferences("app_usage_worker", Context.MODE_PRIVATE)

  /**
   * Start periodic app usage collection work.
   *
   * @param intervalMinutes Optional interval in minutes (default is 60 minutes)
   * @return true if work was scheduled successfully, false otherwise
   */
  fun startPeriodicAppUsageWork(intervalMinutes: Long? = null): Boolean =
    try {
      AppUsageWorker.schedulePeriodicWork(context, intervalMinutes)
      Log.d(TAG, "Started periodic app usage work with interval: ${intervalMinutes ?: 60} minutes")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error starting periodic work: ${e.message}", e)
      false
    }

  /**
   * Stop periodic app usage collection work.
   *
   * @return true if work was canceled successfully, false otherwise
   */
  fun stopPeriodicAppUsageWork(): Boolean =
    try {
      AppUsageWorker.cancelPeriodicWork(context)
      Log.d(TAG, "Stopped periodic app usage work")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping periodic work: ${e.message}", e)
      false
    }

  /**
   * Check if app usage collection work is currently scheduled.
   *
   * @return true if work is scheduled, false otherwise
   */
  fun isWorkScheduled(): Boolean =
    try {
      val isScheduled = AppUsageWorker.isWorkScheduled(context)
      Log.d(TAG, "Work scheduled status: $isScheduled")
      isScheduled
    } catch (e: Exception) {
      Log.e(TAG, "Error checking work status: ${e.message}", e)
      false
    }

  /**
   * Check for pending app usage collection and trigger it if needed. Uses SharedPreferences to
   * communicate with AppUsageWorker.
   *
   * @param binaryMessenger The binary messenger to invoke Flutter method channel
   * @return true if collection was triggered, false otherwise
   */
  fun checkPendingCollection(binaryMessenger: io.flutter.plugin.common.BinaryMessenger?): Boolean =
    try {
      val shouldCollect = sharedPrefs.getBoolean("should_collect_usage", false)

      if (shouldCollect) {
        Log.d(TAG, "Pending app usage collection detected, triggering collection")

        // Clear the flag
        sharedPrefs.edit().putBoolean("should_collect_usage", false).apply()

        // Trigger collection via method channel to Flutter
        if (binaryMessenger != null) {
          val channel =
            MethodChannel(
              binaryMessenger,
              me.ahmetcetinkaya.whph.Constants.Channels.APP_USAGE_STATS,
            )
          channel.invokeMethod("triggerCollection", null)
          Log.d(TAG, "Triggered collection via method channel")
        } else {
          Log.w(TAG, "BinaryMessenger is null, cannot trigger collection")
        }
      }

      shouldCollect
    } catch (e: Exception) {
      Log.e(TAG, "Error checking pending collection: ${e.message}", e)
      false
    }

  /**
   * Get the SharedPreferences for app usage worker. Used by MainActivity to check for pending
   * collection.
   */
  fun getSharedPreferences(): SharedPreferences = sharedPrefs
}
