package me.ahmetcetinkaya.whph

import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "me.ahmetcetinkaya.whph/app_info"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
    }

    // AppInfo sınıfını MainActivity içinde tanımlıyoruz
    inner class AppInfo {
        // Belirli bir packageName ile uygulama adını alma
        fun getAppNameFromPackageName(packageName: String): String? {
            return try {
                val packageManager: PackageManager = applicationContext.packageManager
                val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
                packageManager.getApplicationLabel(applicationInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        }

        // Cihazda yüklü tüm uygulamaların isimlerini ve packageName'lerini döndüren metod
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
