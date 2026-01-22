package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.content.pm.PackageManager
import android.os.UserManager
import android.util.Log

/**
 * Handler for app information related operations. Provides methods to get app names, installed
 * apps, and check work profile status.
 */
class AppInfoHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "AppInfoHandler"

  /**
   * Get the display name of an app from its package name.
   *
   * @param packageName The package name of the app
   * @return The app's display name, or null if not found
   */
  fun getAppName(packageName: String): String? =
    try {
      val packageManager: PackageManager = context.packageManager
      val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
      packageManager.getApplicationLabel(applicationInfo).toString()
    } catch (e: PackageManager.NameNotFoundException) {
      Log.w(TAG, "App not found: $packageName")
      null
    } catch (e: Exception) {
      Log.e(TAG, "Error getting app name for $packageName: ${e.message}", e)
      null
    }

  /**
   * Get a list of all installed apps with their names and package names.
   *
   * @return A list of maps containing appName and packageName for each installed app
   */
  fun getInstalledApps(): List<Map<String, String>> =
    try {
      val packageManager: PackageManager = context.packageManager
      val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
      val appList = mutableListOf<Map<String, String>>()

      for (appInfo in installedApps) {
        val appName = packageManager.getApplicationLabel(appInfo).toString()
        val packageName = appInfo.packageName
        appList.add(mapOf("appName" to appName, "packageName" to packageName))
      }

      Log.d(TAG, "Found ${appList.size} installed apps")
      appList
    } catch (e: Exception) {
      Log.e(TAG, "Error getting installed apps: ${e.message}", e)
      emptyList()
    }

  /**
   * Check if the app is running in a work profile. Uses UserManager to check if the current user is
   * a managed profile.
   *
   * @return true if running in a work profile, false otherwise
   */
  fun isRunningInWorkProfile(): Boolean =
    try {
      val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager

      // Use UserManager's isManagedProfile property to check if current user is a managed profile
      // This property is available from API 21+ and checks the current user context
      val isWorkProfile = userManager.isManagedProfile

      Log.d(TAG, "Is running in work profile: $isWorkProfile")
      isWorkProfile
    } catch (e: Exception) {
      Log.e(TAG, "Error detecting work profile: ${e.message}", e)
      false
    }
}
