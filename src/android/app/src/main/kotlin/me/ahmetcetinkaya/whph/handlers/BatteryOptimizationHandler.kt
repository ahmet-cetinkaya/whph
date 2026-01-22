package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.os.PowerManager
import android.util.Log

/**
 * Handler for battery optimization related operations. Provides methods to check if the app is
 * ignoring battery optimizations.
 */
class BatteryOptimizationHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "BatteryOptimizationHandler"

  /**
   * Check if the app is ignoring battery optimizations.
   *
   * @return true if the app is ignoring battery optimizations, false otherwise
   */
  fun isIgnoringBatteryOptimizations(): Boolean =
    try {
      val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
      val packageName = context.packageName

      // Check if the app is ignoring battery optimizations
      val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)

      Log.d(TAG, "Battery optimization check for $packageName: ignoring=$isIgnoring")
      isIgnoring
    } catch (e: Exception) {
      Log.e(TAG, "Error checking battery optimization: ${e.message}", e)
      false
    }
}
