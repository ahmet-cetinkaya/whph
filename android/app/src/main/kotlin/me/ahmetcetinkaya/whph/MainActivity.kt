package me.ahmetcetinkaya.whph

// Required imports for Android functionality
import android.app.PendingIntent
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Build
import android.provider.Settings
import android.app.AlarmManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Main activity class that serves as the entry point for the Flutter application
class MainActivity : FlutterActivity() {

    // Store the initial notification payload
    private var initialNotificationPayload: String? = null
    private val TAG = "MainActivity"
    private val NOTIFICATION_HANDLER_DELAY_MS = 1000L // Wait 1 second before trying to send payload to Flutter

    // Create a single instance of the ReminderTracker
    private val reminderTracker by lazy { ReminderTracker(context) }

    // Define constants for notification actions
    companion object {
        const val ACTION_NOTIFICATION_CLICK = "${Constants.PACKAGE_NAME}.NOTIFICATION_CLICK"
        const val ACTION_SELECT_NOTIFICATION = "SELECT_NOTIFICATION" // Standard action from FlutterLocalNotifications
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "onCreate called with intent action: ${intent?.action}")
        Log.d(TAG, "Intent extras: ${intent?.extras?.keySet()?.joinToString()}")
        
        // Store the initial intent to process after super.onCreate
        val startIntent = intent
        
        super.onCreate(savedInstanceState)
        
        // Process the intent that started this activity
        processIntent(startIntent)
    }

    override fun onNewIntent(intent: Intent) {
        Log.d(TAG, "onNewIntent called with intent action: ${intent.action}")
        Log.d(TAG, "Intent extras: ${intent.extras?.keySet()?.joinToString()}")
        
        super.onNewIntent(intent)

        // Set the new intent as the current intent
        setIntent(intent)

        // Process the new intent
        processIntent(intent)
    }

    /**
     * Process an intent to extract and handle notification payload
     */
    private fun processIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "processIntent: Intent is null")
            return
        }

        Log.d(TAG, "Processing intent with action: ${intent.action}")
        
        // Extract payload based on the action
        val payload = when (intent.action) {
            // Handle our custom notification action
            ACTION_NOTIFICATION_CLICK -> {
                Log.d(TAG, "Processing custom notification intent")
                intent.getStringExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)
            }
            // Handle SELECT_NOTIFICATION action from FlutterLocalNotifications
            ACTION_SELECT_NOTIFICATION -> {
                Log.d(TAG, "Processing SELECT_NOTIFICATION intent")
                intent.getStringExtra("payload")
            }
            // For any other intent, check if it has our payload extra
            else -> {
                if (intent.hasExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)) {
                    Log.d(TAG, "Found payload in non-notification intent")
                    intent.getStringExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)
                } else if (intent.hasExtra("payload")) {
                    Log.d(TAG, "Found standard payload in non-notification intent")
                    intent.getStringExtra("payload")
                } else {
                    null
                }
            }
        }
        
        Log.d(TAG, "Extracted notification payload: $payload")

        if (payload != null) {
            // Store the payload for later use if Flutter engine is not ready yet
            initialNotificationPayload = payload
            Log.d(TAG, "Stored initialNotificationPayload: $payload")

            // Check if Flutter engine is ready before attempting to send the payload
            if (flutterEngine != null) {
                Log.d(TAG, "Flutter engine is ready, sending payload immediately")
                notifyFlutterOfPayload(payload)
            } else {
                Log.d(TAG, "Flutter engine not ready, payload will be sent when engine is configured")
                // We'll handle this when configureFlutterEngine is called
            }
        } else {
            Log.d(TAG, "No payload found in intent. Intent extras: ${intent.extras?.keySet()?.joinToString()}")
        }
    }

    private fun notifyFlutterOfPayload(payload: String) {
        try {
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    if (flutterEngine != null) {
                        Log.d(TAG, "Sending notification payload to Flutter: $payload")
                        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, Constants.Channels.NOTIFICATION)
                            .invokeMethod("onNotificationClicked", payload)
                        Log.d(TAG, "Successfully sent notification payload to Flutter")
                    } else {
                        Log.e(TAG, "Flutter engine is null, can't send payload")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending notification payload to Flutter: ${e.message}", e)
                }
            }, NOTIFICATION_HANDLER_DELAY_MS) // Short delay to ensure Flutter is ready
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up delayed payload delivery: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    // Configure Flutter engine and set up method channels
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called, initialNotificationPayload: $initialNotificationPayload")

        // Check if we have a pending notification payload to process
        if (initialNotificationPayload != null) {
            // Wait to ensure Flutter is fully initialized
            Log.d(TAG, "Scheduling payload delivery with delay: $initialNotificationPayload")
            notifyFlutterOfPayload(initialNotificationPayload!!)
        } else {
            Log.d(TAG, "No initial notification payload to deliver")
        }

        // Channel for getting app information
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.APP_INFO).setMethodCallHandler { call, result ->
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.BACKGROUND_SERVICE).setMethodCallHandler { call, result ->
            if (call.method == "startBackgroundService") {
                val serviceIntent = Intent(this, AppUsageBackgroundService::class.java)
                startService(serviceIntent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Channel for handling APK installation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.APP_INSTALLER).setMethodCallHandler { call, result ->
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
                        "${Constants.PACKAGE_NAME}.fileprovider",
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

        // Channel for checking battery optimization status
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.BATTERY_OPTIMIZATION).setMethodCallHandler { call, result ->
            if (call.method == "isIgnoringBatteryOptimizations") {
                try {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val packageName = context.packageName

                    // Check if the app is ignoring battery optimizations
                    val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)

                    result.success(isIgnoring)
                } catch (e: Exception) {
                    Log.e("BatteryOptimization", "Error checking battery optimization: ${e.message}", e)
                    result.error("CHECK_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Channel for checking and requesting exact alarm permission
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.EXACT_ALARM).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    try {
                        // Only check on Android 12 (API 31) and above
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

                            // Check if the permission is actually granted
                            val permissionStatus = context.checkCallingOrSelfPermission(android.Manifest.permission.SCHEDULE_EXACT_ALARM)
                            val hasPermission = permissionStatus == PackageManager.PERMISSION_GRANTED

                            // Also check using the AlarmManager API
                            val alarmManagerCheck = alarmManager.canScheduleExactAlarms()

                            // Consider permission granted if either check passes
                            val canSchedule = hasPermission || alarmManagerCheck

                            result.success(canSchedule)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e("ExactAlarm", "Error checking exact alarm permission: ${e.message}", e)
                        result.error("CHECK_ERROR", e.message, null)
                    }
                }

                "checkExactAlarmPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val permissionStatus = context.checkCallingOrSelfPermission(android.Manifest.permission.SCHEDULE_EXACT_ALARM)
                            result.success(permissionStatus)
                        } else {
                            result.success(PackageManager.PERMISSION_GRANTED)
                        }
                    } catch (e: Exception) {
                        Log.e("ExactAlarm", "Error checking direct permission: ${e.message}", e)
                        result.error("CHECK_ERROR", e.message, null)
                    }
                }

                "testExactAlarmPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

                            // First check the permission directly
                            val permissionStatus = context.checkCallingOrSelfPermission(android.Manifest.permission.SCHEDULE_EXACT_ALARM)
                            val hasDirectPermission = permissionStatus == PackageManager.PERMISSION_GRANTED

                            // Also check using the AlarmManager API
                            val canScheduleExactAlarms = alarmManager.canScheduleExactAlarms()

                            // If we already know we don't have permission, don't try to set test alarm
                            if (!hasDirectPermission && !canScheduleExactAlarms) {
                                Log.d("ExactAlarm", "No exact alarm permission detected, skipping test alarm")
                                result.success(false)
                                return@setMethodCallHandler
                            }

                            // Try to create a test alarm to verify permission only if we think we have permission
                            if (Build.VERSION.SDK_INT >= 31) {
                                // Create a test PendingIntent
                                val intent = Intent(context, MainActivity::class.java)
                                intent.action = "TEST_EXACT_ALARM_PERMISSION"
                                val pendingIntent = PendingIntent.getBroadcast(
                                    context,
                                    0,
                                    intent,
                                    PendingIntent.FLAG_IMMUTABLE
                                )

                                // Get current time
                                val currentTimeMillis = System.currentTimeMillis()

                                try {
                                    // Actually try to set the alarm - this is the most reliable test
                                    alarmManager.setExactAndAllowWhileIdle(
                                        AlarmManager.RTC_WAKEUP,
                                        currentTimeMillis + 3600000, // 1 hour in the future
                                        pendingIntent
                                    )

                                    // Immediately cancel the alarm
                                    alarmManager.cancel(pendingIntent)
                                    Log.d("ExactAlarm", "Test alarm successfully created and canceled")
                                    result.success(true)
                                } catch (e: SecurityException) {
                                    // Handle security exception specifically to avoid scary logs
                                    Log.d("ExactAlarm", "Test alarm failed due to security restriction (expected if permission not granted)")
                                    result.success(false)
                                } catch (e: Exception) {
                                    Log.e("ExactAlarm", "Unexpected error setting test alarm: ${e.message}", e)
                                    result.success(hasDirectPermission || canScheduleExactAlarms)
                                }
                            } else {
                                val canSchedule = alarmManager.canScheduleExactAlarms()
                                result.success(canSchedule)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e("ExactAlarm", "Error testing exact alarm permission: ${e.message}", e)
                        result.error("TEST_ERROR", e.message, null)
                    }
                }

                "openExactAlarmsSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            // Open the exact alarm permission settings
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            intent.data = Uri.parse("package:${context.packageName}")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)

                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e("ExactAlarm", "Error opening exact alarm settings: ${e.message}", e)
                        result.error("OPEN_SETTINGS_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Channel for direct notification handling
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.NOTIFICATION).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialNotificationPayload" -> {
                    Log.d(TAG, "Flutter requested initial payload, returning: $initialNotificationPayload")
                    result.success(initialNotificationPayload)
                }
                "acknowledgePayload" -> {
                    val payload = call.arguments as String?
                    Log.d(TAG, "Flutter acknowledged payload: $payload")

                    if (payload == initialNotificationPayload) {
                        initialNotificationPayload = null
                        Log.d(TAG, "Cleared initial notification payload")
                    }

                    result.success(true)
                }
                "showDirectNotification" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "Notification"
                        val body = call.argument<String>("body") ?: "You have a notification"
                        val payload = call.argument<String>("payload")

                        val notificationHelper = NotificationHelper(context)
                        notificationHelper.showNotification(id, title, body, payload)

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error showing direct notification: ${e.message}", e)
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                "scheduleDirectNotification" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "Reminder"
                        val body = call.argument<String>("body") ?: "You have a reminder"
                        val payload = call.argument<String>("payload")
                        val delaySeconds = call.argument<Int>("delaySeconds") ?: 10

                        val intent = Intent(context, NotificationReceiver::class.java).apply {
                            action = Constants.IntentActions.ALARM_TRIGGERED
                            putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
                            putExtra(Constants.IntentExtras.TITLE, title)
                            putExtra(Constants.IntentExtras.BODY, body)
                            putExtra(Constants.IntentExtras.PAYLOAD, payload)
                        }

                        val pendingIntent = PendingIntent.getBroadcast(
                            context,
                            id,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val triggerTimeMillis = System.currentTimeMillis() + (delaySeconds * 1000)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                triggerTimeMillis,
                                pendingIntent
                            )
                        } else {
                            alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                triggerTimeMillis,
                                pendingIntent
                            )
                        }
                        
                        // Track the reminder for pattern-based cancellation
                        // Extract the reminderId from the payload if present
                        var reminderId: String? = null
                        var metadata: String? = null
                        
                        try {
                            if (payload != null) {
                                val payloadObj = org.json.JSONObject(payload)
                                // Try to extract reminderId or any unique identifier from the payload
                                reminderId = payloadObj.optString("reminderId", null)
                                
                                // Extract relevant metadata for filtering (taskId, habitId, etc.)
                                if (payloadObj.has("arguments")) {
                                    val args = payloadObj.getJSONObject("arguments")
                                    if (args.has("taskId")) {
                                        metadata = "taskId:${args.getString("taskId")}"
                                    } else if (args.has("habitId")) {
                                        metadata = "habitId:${args.getString("habitId")}"
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.d("MainActivity", "Non-JSON payload or error parsing: ${e.message}")
                        }
                        
                        // Use the ReminderTracker to store this reminder
                        reminderTracker.trackReminder(id, reminderId, metadata)

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error scheduling direct notification: ${e.message}", e)
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }
                "cancelNotification" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        
                        // Get the alarm manager
                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        
                        // Create a matching PendingIntent to cancel
                        val intent = Intent(context, NotificationReceiver::class.java).apply {
                            action = Constants.IntentActions.ALARM_TRIGGERED
                            putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
                        }
                        
                        val pendingIntent = PendingIntent.getBroadcast(
                            context,
                            id,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        
                        // Cancel the alarm
                        alarmManager.cancel(pendingIntent)
                        
                        // Also cancel any displayed notification
                        val notificationManager = NotificationManagerCompat.from(context)
                        notificationManager.cancel(id)
                        
                        Log.d("MainActivity", "Successfully canceled notification with ID: $id")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error canceling notification: ${e.message}", e)
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "cancelAllNotifications" -> {
                    try {
                        // Get all tracked reminder IDs
                        val reminderIds = reminderTracker.getReminderIds()
                        
                        // Cancel all alarms related to notifications
                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        
                        // Cancel each tracked reminder
                        if (reminderIds.isNotEmpty()) {
                            Log.d("MainActivity", "Found ${reminderIds.size} reminders to cancel")
                            
                            for (idStr in reminderIds) {
                                try {
                                    val id = idStr.toInt()
                                    
                                    // Create a matching PendingIntent to cancel
                                    val intent = Intent(context, NotificationReceiver::class.java).apply {
                                        action = Constants.IntentActions.ALARM_TRIGGERED
                                        putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
                                    }
                                    
                                    val pendingIntent = PendingIntent.getBroadcast(
                                        context,
                                        id,
                                        intent,
                                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                    )
                                    
                                    // Cancel the alarm
                                    alarmManager.cancel(pendingIntent)
                                    
                                    Log.d("MainActivity", "Canceled alarm for reminder ID: $id")
                                } catch (e: Exception) {
                                    Log.e("MainActivity", "Error canceling specific alarm $idStr: ${e.message}")
                                }
                            }
                        }
                        
                        // Cancel all displayed notifications
                        val notificationManager = NotificationManagerCompat.from(context)
                        notificationManager.cancelAll()
                        
                        // Clear all tracked reminders
                        reminderTracker.clearAll()
                        
                        Log.d("MainActivity", "Successfully canceled all notifications and alarms")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error canceling all notifications: ${e.message}", e)
                        result.error("CANCEL_ALL_ERROR", e.message, null)
                    }
                }
                "cancelNotificationsWithPattern" -> {
                    try {
                        val startsWith = call.argument<String>("startsWith")
                        val contains = call.argument<String>("contains")
                        
                        // Use our ReminderTracker to find matching reminders
                        val matchingIds = reminderTracker.findRemindersByPattern(startsWith, contains)
                        
                        if (matchingIds.isNotEmpty()) {
                            Log.d("MainActivity", "Found ${matchingIds.size} reminders matching pattern")
                            
                            // Get necessary services
                            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            val notificationManager = NotificationManagerCompat.from(context)
                            
                            // Cancel each matching reminder
                            for (id in matchingIds) {
                                try {
                                    // Create a matching PendingIntent to cancel
                                    val intent = Intent(context, NotificationReceiver::class.java).apply {
                                        action = Constants.IntentActions.ALARM_TRIGGERED
                                        putExtra(Constants.IntentExtras.NOTIFICATION_ID, id)
                                    }
                                    
                                    val pendingIntent = PendingIntent.getBroadcast(
                                        context,
                                        id,
                                        intent,
                                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                    )
                                    
                                    // Cancel the alarm
                                    alarmManager.cancel(pendingIntent)
                                    
                                    // Also cancel any displayed notification
                                    notificationManager.cancel(id)
                                    
                                    // Remove from tracking
                                    reminderTracker.untrackReminder(id)
                                    
                                    Log.d("MainActivity", "Canceled reminder with ID: $id")
                                } catch (e: Exception) {
                                    Log.e("MainActivity", "Error canceling specific reminder $id: ${e.message}")
                                }
                            }
                            
                            result.success(true)
                        } else {
                            Log.d("MainActivity", "No reminders matched the pattern")
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error canceling notifications with pattern: ${e.message}", e)
                        result.error("CANCEL_PATTERN_ERROR", e.message, null)
                    }
                }
                "getActiveNotificationIds" -> {
                    try {
                        // Get list of active notification IDs through NotificationManager
                        val activeNotificationIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            notificationManager.activeNotifications.map { notification -> notification.id.toString() }
                        } else {
                            // On older Android versions, we don't have a reliable way to get active notifications
                            emptyList<String>()
                        }
                        
                        Log.d("MainActivity", "Active notification IDs: $activeNotificationIds")
                        result.success(activeNotificationIds)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error getting active notification IDs: ${e.message}", e)
                        result.error("GET_ACTIVE_IDS_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Channel for App Usage Stats permission checking
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.APP_USAGE_STATS).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    try {
                        val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
                        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            appOpsManager.unsafeCheckOpNoThrow(
                                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                                android.os.Process.myUid(),
                                packageName
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            appOpsManager.checkOpNoThrow(
                                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                                android.os.Process.myUid(),
                                packageName
                            )
                        }
                        
                        val hasPermission = mode == android.app.AppOpsManager.MODE_ALLOWED
                        
                        // Additional check for permission
                        val usageStatsPermission = context.checkCallingOrSelfPermission("android.permission.PACKAGE_USAGE_STATS")
                        val hasDirectPermission = usageStatsPermission == PackageManager.PERMISSION_GRANTED
                        
                        // Log permission status
                        Log.d("AppUsageStats", "Usage stats mode: $mode, Has permission: $hasPermission, Direct permission: $hasDirectPermission")
                        
                        // Consider permission granted if either check passes
                        result.success(hasPermission || hasDirectPermission)
                    } catch (e: Exception) {
                        Log.e("AppUsageStats", "Error checking usage stats permission: ${e.message}", e)
                        result.error("CHECK_ERROR", e.message, null)
                    }
                }
                "openUsageAccessSettings" -> {
                    try {
                        // Open Usage Access settings
                        val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("AppUsageStats", "Error opening usage access settings: ${e.message}", e)
                        result.error("OPEN_SETTINGS_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Inner class to handle app information related operations
    inner class AppInfo {
        fun getAppNameFromPackageName(packageName: String): String? {
            return try {
                val packageManager: PackageManager = applicationContext.packageManager
                val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
                packageManager.getApplicationLabel(applicationInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        }

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
