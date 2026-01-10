package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

class SyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

  override fun doWork(): Result {
    return try {
      Log.d(TAG, "Starting background sync operation...")

      // Send broadcast to trigger sync in MainActivity
      val intent = Intent("${Constants.PACKAGE_NAME}.SYNC_TRIGGER")
      intent.setPackage(Constants.PACKAGE_NAME)
      applicationContext.sendBroadcast(intent)

      Log.d(TAG, "Sync broadcast sent successfully")
      Result.success()
    } catch (e: Exception) {
      Log.e(TAG, "Error in sync worker", e)
      // Retry up to 3 times before giving up
      if (runAttemptCount < 3) {
        Result.retry()
      } else {
        Result.failure()
      }
    }
  }

  companion object {
    private const val WORK_NAME = Constants.WorkManager.SYNC_WORK_NAME
    private const val TAG = "SyncWorker"

    // Default interval: 30 minutes
    private const val DEFAULT_INTERVAL_MINUTES = 30L

    /** Schedules periodic work for sync operation Default interval: Every 30 minutes */
    fun schedulePeriodicWork(context: Context, intervalMinutes: Long? = null) {
      val actualInterval = intervalMinutes ?: DEFAULT_INTERVAL_MINUTES
      Log.d(TAG, "Scheduling periodic sync work with interval: $actualInterval minutes")

      val constraints =
        Constraints.Builder()
          .setRequiredNetworkType(NetworkType.CONNECTED) // Require network for sync
          .setRequiresBatteryNotLow(false)
          .setRequiresCharging(false)
          .setRequiresDeviceIdle(false)
          .build()

      val periodicWorkRequest =
        PeriodicWorkRequestBuilder<SyncWorker>(actualInterval, TimeUnit.MINUTES)
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

      Log.d(TAG, "Periodic sync work scheduled successfully")
    }

    fun cancelPeriodicWork(context: Context) {
      Log.d(TAG, "Cancelling periodic sync work")
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
