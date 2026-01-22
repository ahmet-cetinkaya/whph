package me.ahmetcetinkaya.whph.handlers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * Handler for exact alarm permission related operations. Provides methods to check, test, and
 * request exact alarm permission on Android 12+.
 */
class ExactAlarmHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "ExactAlarmHandler"

  /**
   * Check if the app can schedule exact alarms. On Android 12 (API 31) and above, this uses
   * AlarmManager.canScheduleExactAlarms(). On earlier versions, returns true since exact alarm
   * permission is not required.
   *
   * @return true if exact alarms can be scheduled, false otherwise
   */
  fun canScheduleExactAlarms(): Boolean =
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // The SCHEDULE_EXACT_ALARM permission is a normal permission that's automatically
        // granted if declared in the manifest. The real permission we need to check is
        // whether the user has granted the "Alarms & reminders" permission in system
        // settings.
        // Only AlarmManager.canScheduleExactAlarms() can reliably check this.
        val canSchedule = alarmManager.canScheduleExactAlarms()

        Log.d(TAG, "Android SDK: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "Package: ${context.packageName}")
        Log.d(TAG, "Target SDK: ${context.applicationInfo.targetSdkVersion}")
        Log.d(TAG, "canScheduleExactAlarms: $canSchedule")

        canSchedule
      } else {
        Log.d(TAG, "Android SDK < 31, exact alarm permission not required")
        true
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error checking exact alarm permission: ${e.message}", e)
      false
    }

  /**
   * Check exact alarm permission and return permission status code. Returns
   * PackageManager.PERMISSION_GRANTED (0) if granted, PackageManager.PERMISSION_DENIED (-1) if not.
   *
   * @return Permission status code
   */
  fun checkExactAlarmPermission(): Int =
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canSchedule = alarmManager.canScheduleExactAlarms()

        // Return 0 (PERMISSION_GRANTED) if granted, -1 (PERMISSION_DENIED) if not
        val permissionStatus =
          if (canSchedule) {
            android.content.pm.PackageManager.PERMISSION_GRANTED
          } else {
            android.content.pm.PackageManager.PERMISSION_DENIED
          }

        Log.d(TAG, "checkExactAlarmPermission: $permissionStatus (canSchedule: $canSchedule)")
        permissionStatus
      } else {
        android.content.pm.PackageManager.PERMISSION_GRANTED
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error checking direct permission: ${e.message}", e)
      android.content.pm.PackageManager.PERMISSION_DENIED
    }

  /**
   * Test exact alarm permission by attempting to schedule and cancel a test alarm. This is the most
   * reliable way to verify exact alarm permission.
   *
   * @return true if permission is granted, false otherwise
   */
  fun testExactAlarmPermission(): Boolean {
    return try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Only check using the AlarmManager API - this is the most reliable test
        val canScheduleExactAlarms = alarmManager.canScheduleExactAlarms()

        // If we don't have permission, return false immediately
        if (!canScheduleExactAlarms) {
          Log.d(TAG, "No exact alarm permission detected via AlarmManager API")
          return false
        }

        // Try to create a test alarm to verify permission
        try {
          // Create a test PendingIntent
          val testIntent =
            Intent(context, Context::class.java).apply { action = "TEST_EXACT_ALARM_PERMISSION" }
          val pendingIntent =
            PendingIntent.getBroadcast(
              context,
              999999, // Use a unique ID for test
              testIntent,
              PendingIntent.FLAG_IMMUTABLE,
            )

          // Get current time
          val currentTimeMillis = System.currentTimeMillis()

          // Actually try to set the alarm - this is the most reliable test
          alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            currentTimeMillis + 3600000, // 1 hour in the future
            pendingIntent,
          )

          // Immediately cancel the alarm
          alarmManager.cancel(pendingIntent)
          Log.d(TAG, "Test alarm successfully created and canceled")
          true
        } catch (e: SecurityException) {
          // Handle security exception specifically to avoid scary logs
          Log.d(
            TAG,
            "Test alarm failed due to security restriction (expected if permission not granted)",
          )
          false
        } catch (e: Exception) {
          Log.e(TAG, "Unexpected error setting test alarm: ${e.message}", e)
          // Fall back to the AlarmManager API check
          canScheduleExactAlarms
        }
      } else {
        true
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error testing exact alarm permission: ${e.message}", e)
      false
    }
  }

  /**
   * Open the exact alarm permission settings page. This allows the user to grant the "Alarms &
   * reminders" permission.
   *
   * @return true if settings were opened successfully, false otherwise
   */
  fun openExactAlarmsSettings(): Boolean =
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        // First, check current permission status
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val currentStatus = alarmManager.canScheduleExactAlarms()
        Log.d(TAG, "Current permission status before opening settings: $currentStatus")

        // Open the exact alarm permission settings
        val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
        intent.data = Uri.parse("package:${context.packageName}")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        Log.d(TAG, "Opening exact alarm settings for package: ${context.packageName}")
        context.startActivity(intent)

        true
      } else {
        Log.d(TAG, "Android version < 12, exact alarm permission not needed")
        true
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error opening exact alarm settings: ${e.message}", e)
      false
    }
}
