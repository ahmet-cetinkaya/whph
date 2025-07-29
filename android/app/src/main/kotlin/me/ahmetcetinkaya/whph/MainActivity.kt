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
import android.os.UserManager
import android.provider.Settings
import android.app.AlarmManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationManagerCompat

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

    // Handler for periodic pending collection checks
    private val pendingCollectionHandler = Handler(Looper.getMainLooper())
    
    // Broadcast receiver for sync triggers from WorkManager
    private val syncTriggerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "${Constants.PACKAGE_NAME}.SYNC_TRIGGER") {
                Log.d(TAG, "Sync trigger received from WorkManager")
                
                // Trigger sync via method channel to Flutter
                val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
                if (binaryMessenger != null) {
                    val channel = MethodChannel(binaryMessenger, Constants.Channels.SYNC)
                    channel.invokeMethod("triggerSync", null)
                } else {
                    Log.w(TAG, "Flutter engine not ready, cannot trigger sync")
                }
            }
        }
    }

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

        // Register broadcast receiver for sync triggers
        val filter = IntentFilter("${Constants.PACKAGE_NAME}.SYNC_TRIGGER")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(syncTriggerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(syncTriggerReceiver, filter)
        }
        Log.d(TAG, "Registered sync trigger broadcast receiver")

        // Process the intent that started this activity
        processIntent(startIntent)

        // Start periodic check for pending app usage collection
        startPendingCollectionCheck()
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
     * Process an intent to extract and handle notification payload or widget clicks
     */
    private fun processIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "processIntent: Intent is null")
            return
        }

        Log.d(TAG, "Processing intent with action: ${intent.action}")
        Log.d(TAG, "Intent data: ${intent.data}")

        // Check for widget clicks first
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            val uri = intent.data!!
            Log.d(TAG, "=== WIDGET CLICK DETECTED ===")
            Log.d(TAG, "Widget click URI: $uri")

            if (uri.scheme == "whph" && uri.host == "widget") {
                Log.d(TAG, "Valid widget click URI detected")
                handleWidgetClick(uri)
                return // Don't process as notification
            }
        }

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
            // Handle boot completed notification from NotificationReceiver
            "BOOT_COMPLETED_NOTIFICATION" -> {
                Log.d(TAG, "Processing boot completed notification")
                handleBootCompletedNotification()
                null // No payload for boot completed
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

    /**
     * Handle widget click by triggering the HomeWidget plugin's click mechanism
     */
    private fun handleWidgetClick(uri: Uri) {
        try {
            Log.d(TAG, "=== HANDLING WIDGET CLICK ===")
            Log.d(TAG, "Widget URI: $uri")

            // Use HomeWidget plugin to trigger the click event
            // This should trigger the widgetClicked stream in Flutter
            try {
                // Try to use HomeWidget plugin's triggerClick method
                val homeWidgetClass = Class.forName("es.antonborri.home_widget.HomeWidgetPlugin")
                val triggerClickMethod = homeWidgetClass.getDeclaredMethod("triggerClick", String::class.java)
                triggerClickMethod.isAccessible = true
                triggerClickMethod.invoke(null, uri.toString())
                Log.d(TAG, "Successfully triggered HomeWidget click via reflection")

            } catch (reflectionError: Exception) {
                Log.w(TAG, "Reflection method failed, trying alternative: $reflectionError")

                // Alternative approach: Try to access the plugin instance
                try {
                    val homeWidgetClass = Class.forName("es.antonborri.home_widget.HomeWidgetPlugin")
                    val instanceField = homeWidgetClass.getDeclaredField("instance")
                    instanceField.isAccessible = true
                    val pluginInstance = instanceField.get(null)

                    if (pluginInstance != null) {
                        val widgetClickedMethod = homeWidgetClass.getDeclaredMethod("widgetClicked", String::class.java)
                        widgetClickedMethod.isAccessible = true
                        widgetClickedMethod.invoke(pluginInstance, uri.toString())
                        Log.d(TAG, "Successfully triggered HomeWidget click via instance method")
                    } else {
                        Log.w(TAG, "HomeWidget plugin instance is null")
                        fallbackWidgetClick(uri)
                    }

                } catch (instanceError: Exception) {
                    Log.w(TAG, "Instance method failed: $instanceError")
                    fallbackWidgetClick(uri)
                }
            }

            Log.d(TAG, "=== WIDGET CLICK HANDLING COMPLETE ===")

        } catch (e: Exception) {
            Log.e(TAG, "Error handling widget click", e)
            fallbackWidgetClick(uri)
        }
    }

    /**
     * Fallback method to handle widget clicks when HomeWidget plugin methods fail
     */
    private fun fallbackWidgetClick(uri: Uri) {
        try {
            Log.d(TAG, "Using fallback widget click handling")

            // Send a broadcast that might be picked up by the HomeWidget plugin
            val broadcastIntent = Intent().apply {
                action = "es.antonborri.home_widget.WIDGET_CLICK"
                putExtra("url", uri.toString())
                setPackage(packageName)
            }
            sendBroadcast(broadcastIntent)
            Log.d(TAG, "Sent fallback broadcast for widget click")

        } catch (e: Exception) {
            Log.e(TAG, "Fallback widget click handling failed", e)
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
        Log.d(TAG, "onDestroy called - cleaning up persistent notifications")
        
        try {
            // Unregister broadcast receiver
            unregisterReceiver(syncTriggerReceiver)
            Log.d(TAG, "Unregistered sync trigger broadcast receiver")
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering sync trigger receiver: ${e.message}")
        }
        
        try {
            // Cancel the persistent system tray notification (ID 888)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(888) // System tray notification ID
            Log.d(TAG, "Cancelled persistent notification with ID 888")
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling persistent notification on destroy: ${e.message}")
        }
        
        super.onDestroy()
    }

    /**
     * Handle boot completed notification from NotificationReceiver
     */
    private fun handleBootCompletedNotification() {
        try {
            Log.d(TAG, "Handling boot completed notification")
            
            // Delay to ensure Flutter is ready before sending the notification
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    // Send boot completed event to Flutter via method channel
                    val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
                    if (binaryMessenger != null) {
                        val channel = MethodChannel(binaryMessenger, Constants.Channels.BOOT_COMPLETED)
                        channel.invokeMethod("onBootCompleted", null, object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                Log.d(TAG, "Successfully notified Flutter about boot completed")
                            }

                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            Log.e(TAG, "Error notifying Flutter about boot completed: $errorCode - $errorMessage")
                        }

                        override fun notImplemented() {
                            Log.w(TAG, "Boot completed method not implemented in Flutter")
                        }
                    })
                    } else {
                        Log.w(TAG, "BinaryMessenger is null, cannot send boot completed notification to Flutter")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending boot completed notification to Flutter: ${e.message}", e)
                }
            }, NOTIFICATION_HANDLER_DELAY_MS)
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleBootCompletedNotification: ${e.message}", e)
        }
    }

    /**
     * Start periodic check for pending app usage collection from WorkManager
     */
    private fun startPendingCollectionCheck() {
        val checkRunnable = object : Runnable {
            override fun run() {
                try {
                    val sharedPreferences = getSharedPreferences("app_usage_worker", Context.MODE_PRIVATE)
                    val shouldCollect = sharedPreferences.getBoolean("should_collect_usage", false)

                    if (shouldCollect) {
                        Log.d(TAG, "Pending app usage collection detected, triggering collection")

                        // Clear the flag
                        sharedPreferences.edit()
                            .putBoolean("should_collect_usage", false)
                            .apply()

                        // Trigger collection via method channel to Flutter
                        val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
                        if (binaryMessenger != null) {
                            val channel = MethodChannel(binaryMessenger, Constants.Channels.APP_USAGE_STATS)
                            channel.invokeMethod("triggerCollection", null)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in pending collection check: ${e.message}", e)
                }

                // Schedule next check in 30 seconds
                pendingCollectionHandler.postDelayed(this, 30000)
            }
        }

        // Start the periodic check
        pendingCollectionHandler.post(checkRunnable)
        Log.d(TAG, "Started periodic pending collection check")
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
                "isRunningInWorkProfile" -> {
                    try {
                        val isWorkProfile = isRunningInWorkProfile()
                        result.success(isWorkProfile)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking work profile status: ${e.message}", e)
                        result.error("WORK_PROFILE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
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
                            
                            // The SCHEDULE_EXACT_ALARM permission is a normal permission that's automatically
                            // granted if declared in the manifest. The real permission we need to check is
                            // whether the user has granted the "Alarms & reminders" permission in system settings.
                            // Only AlarmManager.canScheduleExactAlarms() can reliably check this.
                            val canSchedule = alarmManager.canScheduleExactAlarms()
                            
                            Log.d("ExactAlarm", "Android SDK: ${Build.VERSION.SDK_INT}")
                            Log.d("ExactAlarm", "Package: ${context.packageName}")
                            Log.d("ExactAlarm", "Target SDK: ${context.applicationInfo.targetSdkVersion}")
                            Log.d("ExactAlarm", "canScheduleExactAlarms: $canSchedule")
                            
                            result.success(canSchedule)
                        } else {
                            Log.d("ExactAlarm", "Android SDK < 31, exact alarm permission not required")
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
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            val canSchedule = alarmManager.canScheduleExactAlarms()
                            
                            // Return 0 (PERMISSION_GRANTED) if granted, -1 (PERMISSION_DENIED) if not
                            val permissionStatus = if (canSchedule) PackageManager.PERMISSION_GRANTED else PackageManager.PERMISSION_DENIED
                            
                            Log.d("ExactAlarm", "checkExactAlarmPermission: $permissionStatus (canSchedule: $canSchedule)")
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

                            // Only check using the AlarmManager API - this is the reliable way
                            val canScheduleExactAlarms = alarmManager.canScheduleExactAlarms()

                            // If we don't have permission, return false immediately
                            if (!canScheduleExactAlarms) {
                                Log.d("ExactAlarm", "No exact alarm permission detected via AlarmManager API")
                                result.success(false)
                                return@setMethodCallHandler
                            }

                            // Try to create a test alarm to verify permission
                            try {
                                // Create a test PendingIntent
                                val intent = Intent(context, MainActivity::class.java)
                                intent.action = "TEST_EXACT_ALARM_PERMISSION"
                                val pendingIntent = PendingIntent.getBroadcast(
                                    context,
                                    999999, // Use a unique ID for test
                                    intent,
                                    PendingIntent.FLAG_IMMUTABLE
                                )

                                // Get current time
                                val currentTimeMillis = System.currentTimeMillis()

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
                                // Fall back to the AlarmManager API check
                                result.success(canScheduleExactAlarms)
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
                            // First, check current permission status
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            val currentStatus = alarmManager.canScheduleExactAlarms()
                            Log.d("ExactAlarm", "Current permission status before opening settings: $currentStatus")
                            
                            // Open the exact alarm permission settings
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            intent.data = Uri.parse("package:${context.packageName}")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            
                            Log.d("ExactAlarm", "Opening exact alarm settings for package: ${context.packageName}")
                            startActivity(intent)

                            result.success(true)
                        } else {
                            Log.d("ExactAlarm", "Android version < 12, exact alarm permission not needed")
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

        // Channel for boot completed event notification
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.BOOT_COMPLETED).setMethodCallHandler { call, result ->
            when (call.method) {
                "onBootCompleted" -> {
                    Log.d(TAG, "Flutter notified of boot completed event")
                    result.success(true)
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
                        
                        // Use the enhanced notification tracking method
                        reminderTracker.trackNotification(
                            id = id,
                            title = title,
                            body = body,
                            payload = payload,
                            triggerTime = triggerTimeMillis,
                            reminderId = reminderId,
                            metadata = metadata
                        )

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
        
        // Channel for App Usage Stats permission checking and accurate usage retrieval
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
                "getAccurateForegroundUsage" -> {
                    try {
                        val startTime = call.argument<Long>("startTime") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "startTime is required", null)
                        val endTime = call.argument<Long>("endTime") ?: return@setMethodCallHandler result.error("INVALID_ARGS", "endTime is required", null)
                        
                        Log.d("AppUsageStats", "Getting accurate foreground usage from $startTime to $endTime")
                        
                        val usageHandler = AppUsageStatsHandler(this@MainActivity)
                        val usageMap = usageHandler.getAccurateForegroundUsage(startTime, endTime)
                        
                        // Convert to Flutter-compatible format
                        val resultMap = mutableMapOf<String, Any>()
                        usageMap.forEach { (packageName, usageTimeMs) ->
                            resultMap[packageName] = mapOf(
                                "packageName" to packageName,
                                "appName" to usageHandler.getAppDisplayName(packageName),
                                "usageTimeSeconds" to (usageTimeMs / 1000).toInt(),
                                "usageTimeMs" to usageTimeMs
                            )
                        }
                        
                        Log.d("AppUsageStats", "Returning ${resultMap.size} apps with accurate usage data")
                        result.success(resultMap)
                    } catch (e: Exception) {
                        Log.e("AppUsageStats", "Error getting accurate foreground usage: ${e.message}", e)
                        result.error("USAGE_ERROR", e.message, null)
                    }
                }
                "getTodayForegroundUsage" -> {
                    try {
                        Log.d("AppUsageStats", "Getting today's foreground usage (PRECISION Digital Wellbeing compatible)")
                        
                        val usageHandler = AppUsageStatsHandler(this@MainActivity)
                        val usageMap = usageHandler.getTodayForegroundUsage()
                        
                        // Convert to Flutter-compatible format with precision metadata
                        val resultMap = mutableMapOf<String, Any>()
                        var totalUsageSeconds = 0
                        
                        usageMap.forEach { (packageName, usageTimeMs) ->
                            val usageSeconds = (usageTimeMs / 1000).toInt()
                            totalUsageSeconds += usageSeconds
                            
                            resultMap[packageName] = mapOf(
                                "packageName" to packageName,
                                "appName" to usageHandler.getAppDisplayName(packageName),
                                "usageTimeSeconds" to usageSeconds,
                                "usageTimeMs" to usageTimeMs,
                                "precisionMode" to true,
                                "digitalWellbeingCompatible" to true
                            )
                        }
                        
                        // Add metadata for debugging precision
                        resultMap["_metadata"] = mapOf(
                            "totalApps" to resultMap.size,
                            "totalUsageSeconds" to totalUsageSeconds,
                            "totalUsageMinutes" to (totalUsageSeconds / 60),
                            "precisionAlgorithm" to "DigitalWellbeingExact",
                            "timestamp" to System.currentTimeMillis()
                        )
                        
                        Log.d("AppUsageStats", "PRECISION RESULT: ${resultMap.size-1} apps, ${totalUsageSeconds/60}m total")
                        result.success(resultMap)
                    } catch (e: Exception) {
                        Log.e("AppUsageStats", "Error getting precision today's usage: ${e.message}", e)
                        result.error("PRECISION_USAGE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Channel for WorkManager app usage tracking
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.WORK_MANAGER).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPeriodicAppUsageWork" -> {
                    try {
                        // Get optional interval parameter, if not provided, use default (60 minutes)
                        val intervalMinutes = call.argument<Int>("intervalMinutes")?.toLong()
                        AppUsageWorker.schedulePeriodicWork(this, intervalMinutes)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("WorkManager", "Error starting periodic work: ${e.message}", e)
                        result.error("START_WORK_ERROR", e.message, null)
                    }
                }
                "stopPeriodicAppUsageWork" -> {
                    try {
                        AppUsageWorker.cancelPeriodicWork(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("WorkManager", "Error stopping periodic work: ${e.message}", e)
                        result.error("STOP_WORK_ERROR", e.message, null)
                    }
                }
                "isWorkScheduled" -> {
                    try {
                        val isScheduled = AppUsageWorker.isWorkScheduled(this)
                        result.success(isScheduled)
                    } catch (e: Exception) {
                        Log.e("WorkManager", "Error checking work status: ${e.message}", e)
                        result.error("CHECK_WORK_ERROR", e.message, null)
                    }
                }
                "checkPendingCollection" -> {
                    try {
                        val sharedPreferences = getSharedPreferences("app_usage_worker", Context.MODE_PRIVATE)
                        val shouldCollect = sharedPreferences.getBoolean("should_collect_usage", false)

                        if (shouldCollect) {
                            // Clear the flag
                            sharedPreferences.edit()
                                .putBoolean("should_collect_usage", false)
                                .apply()

                            // Trigger collection via method channel to Flutter
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.APP_USAGE_STATS)
                                .invokeMethod("triggerCollection", null)
                        }

                        result.success(shouldCollect)
                    } catch (e: Exception) {
                        Log.e("WorkManager", "Error checking pending collection: ${e.message}", e)
                        result.error("CHECK_PENDING_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Channel for Sync WorkManager 
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.SYNC).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPeriodicSyncWork" -> {
                    try {
                        // Get optional interval parameter, if not provided, use default (30 minutes)
                        val intervalMinutes = call.argument<Int>("intervalMinutes")?.toLong()
                        SyncWorker.schedulePeriodicWork(this, intervalMinutes)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("SyncWorker", "Error starting periodic sync work: ${e.message}", e)
                        result.error("START_SYNC_WORK_ERROR", e.message, null)
                    }
                }
                "stopPeriodicSyncWork" -> {
                    try {
                        SyncWorker.cancelPeriodicWork(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("SyncWorker", "Error stopping periodic sync work: ${e.message}", e)
                        result.error("STOP_SYNC_WORK_ERROR", e.message, null)
                    }
                }
                "isSyncWorkScheduled" -> {
                    try {
                        val isScheduled = SyncWorker.isWorkScheduled(this)
                        result.success(isScheduled)
                    } catch (e: Exception) {
                        Log.e("SyncWorker", "Error checking sync work status: ${e.message}", e)
                        result.error("CHECK_SYNC_WORK_ERROR", e.message, null)
                    }
                }
                "checkPendingSync" -> {
                    try {
                        // For broadcast-based sync, we don't need to check SharedPreferences
                        // Return false since we're not using SharedPreferences anymore
                        result.success(false)
                    } catch (e: Exception) {
                        Log.e("SyncWorker", "Error checking pending sync: ${e.message}", e)
                        result.error("CHECK_PENDING_SYNC_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Detects if the app is running in a work profile.
     * Uses UserManager and UserHandle APIs to determine profile context.
     */
    private fun isRunningInWorkProfile(): Boolean {
        return try {
            val userManager = getSystemService(Context.USER_SERVICE) as UserManager
            val currentUser = android.os.Process.myUserHandle()
            val userProfiles = userManager.userProfiles
            
            Log.d(TAG, "Current user: $currentUser")
            Log.d(TAG, "User profiles: $userProfiles")
            
            // Find the main user (typically UserHandle{0})
            val mainUser = userProfiles.firstOrNull { 
                userManager.isUserRunning(it) && it.hashCode() == 0 
            }
            
            Log.d(TAG, "Main user: $mainUser")
            
            // If we have multiple profiles and current user is not the main user, we're in work profile
            val isWorkProfile = currentUser != mainUser && userProfiles.size > 1
            
            Log.d(TAG, "Is running in work profile: $isWorkProfile")
            return isWorkProfile
            
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting work profile: ${e.message}", e)
            false
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
