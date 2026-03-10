package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import me.ahmetcetinkaya.whph.AppUsageStatsHandler

/**
 * Handler for App Usage Stats method channel operations. Provides methods for checking permissions,
 * opening settings, and retrieving usage statistics.
 */
class AppUsageStatsMethodHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "AppUsageStatsMethodHandler"
  private val usageHandler by lazy { AppUsageStatsHandler(context) }

  /**
   * Check if the app has usage stats permission.
   *
   * @return true if permission is granted, false otherwise
   */
  fun checkUsageStatsPermission(): Boolean =
    try {
      val appOpsManager =
        context.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
      val mode =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          appOpsManager.unsafeCheckOpNoThrow(
            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName,
          )
        } else {
          @Suppress("DEPRECATION")
          appOpsManager.checkOpNoThrow(
            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName,
          )
        }

      val hasPermission = mode == android.app.AppOpsManager.MODE_ALLOWED
      val usageStatsPermission =
        context.checkCallingOrSelfPermission("android.permission.PACKAGE_USAGE_STATS")
      val hasDirectPermission =
        usageStatsPermission == android.content.pm.PackageManager.PERMISSION_GRANTED

      Log.d(
        TAG,
        "Usage stats mode: $mode, Has permission: $hasPermission, Direct permission: $hasDirectPermission",
      )

      hasPermission || hasDirectPermission
    } catch (e: Exception) {
      Log.e(TAG, "Error checking usage stats permission: ${e.message}", e)
      false
    }

  /**
   * Open the usage access settings page.
   *
   * @return true if settings were opened successfully, false otherwise
   */
  fun openUsageAccessSettings(): Boolean =
    try {
      val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      context.startActivity(intent)
      true
    } catch (e: Exception) {
      Log.e(TAG, "Error opening usage access settings: ${e.message}", e)
      false
    }

  /**
   * Get accurate foreground usage for a specific time range.
   *
   * @param startTime Start time in milliseconds
   * @param endTime End time in milliseconds
   * @return Map of package names to usage data
   */
  fun getAccurateForegroundUsage(startTime: Long, endTime: Long): Map<String, Any>? =
    try {
      Log.d(TAG, "Getting accurate foreground usage from $startTime to $endTime")

      val usageMap = usageHandler.getAccurateForegroundUsage(startTime, endTime)

      // Convert to Flutter-compatible format
      val resultMap = mutableMapOf<String, Any>()
      usageMap.forEach { (packageName, usageTimeMs) ->
        resultMap[packageName] =
          mapOf(
            "packageName" to packageName,
            "appName" to usageHandler.getAppDisplayName(packageName),
            "usageTimeSeconds" to (usageTimeMs / 1000).toInt(),
            "usageTimeMs" to usageTimeMs,
          )
      }

      Log.d(TAG, "Returning ${resultMap.size} apps with accurate usage data")
      resultMap
    } catch (e: Exception) {
      Log.e(TAG, "Error getting accurate foreground usage: ${e.message}", e)
      null
    }

  /**
   * Get today's foreground usage with Digital Wellbeing precision.
   *
   * @return Map of package names to usage data with metadata
   */
  fun getTodayForegroundUsage(): Map<String, Any>? =
    try {
      Log.d(TAG, "Getting today's foreground usage (PRECISION Digital Wellbeing compatible)")

      val usageMap = usageHandler.getTodayForegroundUsage()

      // Convert to Flutter-compatible format with precision metadata
      val resultMap = mutableMapOf<String, Any>()
      var totalUsageSeconds = 0

      usageMap.forEach { (packageName, usageTimeMs) ->
        val usageSeconds = (usageTimeMs / 1000).toInt()
        totalUsageSeconds += usageSeconds

        resultMap[packageName] =
          mapOf(
            "packageName" to packageName,
            "appName" to usageHandler.getAppDisplayName(packageName),
            "usageTimeSeconds" to usageSeconds,
            "usageTimeMs" to usageTimeMs,
            "precisionMode" to true,
            "digitalWellbeingCompatible" to true,
          )
      }

      // Add metadata for debugging precision
      resultMap["_metadata"] =
        mapOf(
          "totalApps" to resultMap.size,
          "totalUsageSeconds" to totalUsageSeconds,
          "totalUsageMinutes" to (totalUsageSeconds / 60),
          "precisionAlgorithm" to "DigitalWellbeingExact",
          "timestamp" to System.currentTimeMillis(),
        )

      Log.d(TAG, "PRECISION RESULT: ${resultMap.size - 1} apps, ${totalUsageSeconds / 60}m total")
      resultMap
    } catch (e: Exception) {
      Log.e(TAG, "Error getting precision today's usage: ${e.message}", e)
      null
    }
}
