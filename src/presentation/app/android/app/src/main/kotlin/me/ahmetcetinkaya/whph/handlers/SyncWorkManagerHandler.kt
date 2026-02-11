package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.util.Log
import me.ahmetcetinkaya.whph.SyncWorker

/**
 * Handler for Sync WorkManager operations. Delegates to SyncWorker for scheduling and managing
 * periodic sync operations.
 */
class SyncWorkManagerHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "SyncWorkManagerHandler"

  /**
   * Start periodic sync work.
   *
   * @param intervalMinutes Optional interval in minutes (default is 30 minutes)
   * @return true if work was scheduled successfully, false otherwise
   */
  fun startPeriodicSyncWork(intervalMinutes: Long? = null): Boolean =
    try {
      SyncWorker.schedulePeriodicWork(context, intervalMinutes)
      Log.d(TAG, "Started periodic sync work with interval: ${intervalMinutes ?: 30} minutes")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error starting periodic sync work: ${e.message}", e)
      false
    }

  /**
   * Stop periodic sync work.
   *
   * @return true if work was canceled successfully, false otherwise
   */
  fun stopPeriodicSyncWork(): Boolean =
    try {
      SyncWorker.cancelPeriodicWork(context)
      Log.d(TAG, "Stopped periodic sync work")
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping periodic sync work: ${e.message}", e)
      false
    }

  /**
   * Check if sync work is currently scheduled.
   *
   * @return true if work is scheduled, false otherwise
   */
  fun isSyncWorkScheduled(): Boolean =
    try {
      val isScheduled = SyncWorker.isWorkScheduled(context)
      Log.d(TAG, "Sync work scheduled status: $isScheduled")
      isScheduled
    } catch (e: Exception) {
      Log.e(TAG, "Error checking sync work status: ${e.message}", e)
      false
    }

  /**
   * Check for pending sync. For broadcast-based sync, we don't need to check SharedPreferences.
   *
   * @return false since we're not using SharedPreferences for sync
   */
  fun checkPendingSync(): Boolean =
    try {
      // For broadcast-based sync, we don't need to check SharedPreferences
      // Return false since we're not using SharedPreferences anymore
      Log.d(TAG, "Pending sync check: not using SharedPreferences (broadcast-based)")
      false
    } catch (e: Exception) {
      Log.e(TAG, "Error checking pending sync: ${e.message}", e)
      false
    }
}
