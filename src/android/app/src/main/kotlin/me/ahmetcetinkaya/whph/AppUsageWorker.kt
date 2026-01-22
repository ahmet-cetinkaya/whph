package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class AppUsageWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
  private val sharedPreferences: SharedPreferences =
    context.getSharedPreferences("app_usage_worker", Context.MODE_PRIVATE)

  override fun doWork(): Result =
    try {
      Log.d("AppUsageWorker", "Starting app usage data collection...")

      // Set a flag to collect app usage data
      // MainActivity will check this flag and trigger the data collection process
      sharedPreferences
        .edit()
        .putBoolean("should_collect_usage", true)
        .putLong("collection_timestamp", System.currentTimeMillis())
        .apply()

      Log.d("AppUsageWorker", "App usage collection flag set successfully")
      Result.success()
    } catch (e: Exception) {
      Log.e("AppUsageWorker", "Error in app usage worker", e)
      // Retry up to 3 times before giving up
      if (runAttemptCount < 3) {
        Result.retry()
      } else {
        Result.failure()
      }
    }

  companion object {
    private const val WORK_NAME = "app_usage_periodic_work"
    private const val TAG = "AppUsageWorker"

    // Default interval: 60 minutes (1 hour)
    private const val DEFAULT_INTERVAL_MINUTES = 60L

    /** Schedules periodic work for app usage collection Default interval: Every 1 hour */
    fun schedulePeriodicWork(context: Context, intervalMinutes: Long? = null) {
      val actualInterval = intervalMinutes ?: DEFAULT_INTERVAL_MINUTES
      Log.d(TAG, "Scheduling periodic app usage work with interval: $actualInterval minutes")

      val constraints =
        Constraints.Builder()
          .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
          .setRequiresBatteryNotLow(false)
          .setRequiresCharging(false)
          .setRequiresDeviceIdle(false)
          .build()

      val periodicWorkRequest =
        PeriodicWorkRequestBuilder<AppUsageWorker>(actualInterval, TimeUnit.MINUTES)
          .setConstraints(constraints)
          .setBackoffCriteria(
            BackoffPolicy.LINEAR,
            WorkRequest.MIN_BACKOFF_MILLIS,
            TimeUnit.MILLISECONDS,
          )
          .build()

      WorkManager.getInstance(context)
        .enqueueUniquePeriodicWork(
          WORK_NAME,
          ExistingPeriodicWorkPolicy.REPLACE,
          periodicWorkRequest,
        )

      Log.d(TAG, "Periodic work scheduled successfully")
    }

    fun cancelPeriodicWork(context: Context) {
      Log.d(TAG, "Cancelling periodic app usage work")
      WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    fun isWorkScheduled(context: Context): Boolean {
      val workInfos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(WORK_NAME).get()

      return workInfos.any { workInfo ->
        workInfo.state == WorkInfo.State.ENQUEUED || workInfo.state == WorkInfo.State.RUNNING
      }
    }
  }
}
