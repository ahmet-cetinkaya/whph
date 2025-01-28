package me.ahmetcetinkaya.whph

// Required imports for Android functionality
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Main activity class that serves as the entry point for the Flutter application
class MainActivity : FlutterActivity() {
    // Channel names for communication between Flutter and Android
    private val CHANNEL_APP_INFO = "me.ahmetcetinkaya.whph/app_info"
    private val CHANNEL_BACKGROUND_SERVICE = "whph/background_service"
    private val CHANNEL_APP_INSTALLER = "me.ahmetcetinkaya.whph/app_installer"

    // Configure Flutter engine and set up method channels
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel for getting app information
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_APP_INFO).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppName" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val appName = AppInfo().getAppNameFromPackageName(packageName)

                        if (appName != null) {
                            result.success(appName)
                        } else {
                            result.error("UNAVAILABLE", "App name not found.", null)
                        }
                    } else {
                        result.error("ERROR", "Package name is null.", null)
                    }
                }
                "getInstalledApps" -> {
                    val installedApps = AppInfo().getInstalledAppNames()
                    result.success(installedApps)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Channel for managing background service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BACKGROUND_SERVICE).setMethodCallHandler { call, result ->
            if (call.method == "startBackgroundService") {
                val serviceIntent = Intent(this, AppUsageBackgroundService::class.java)
                startService(serviceIntent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Channel for handling APK installation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_APP_INSTALLER).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                try {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                        return@setMethodCallHandler
                    }

                    val file = File(filePath)
                    val uri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        file
                    )

                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Inner class to handle app information related operations
    inner class AppInfo {
        // Retrieve application name using its package name
        // Returns null if the app is not found or there's an error
        fun getAppNameFromPackageName(packageName: String): String? {
            return try {
                val packageManager: PackageManager = applicationContext.packageManager
                val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
                packageManager.getApplicationLabel(applicationInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        }

        // Retrieve a list of all installed applications
        // Returns a list of maps containing app names and package names
        fun getInstalledAppNames(): List<Map<String, String>> {
            val packageManager: PackageManager = applicationContext.packageManager
            val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            val appList = mutableListOf<Map<String, String>>()

            for (appInfo in installedApps) {
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                val packageName = appInfo.packageName
                appList.add(mapOf("appName" to appName, "packageName" to packageName))
            }

            return appList
        }
    }
}
