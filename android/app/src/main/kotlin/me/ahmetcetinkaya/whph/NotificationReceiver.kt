package me.ahmetcetinkaya.whph

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationReceiver : BroadcastReceiver() {
    private val TAG = "NotificationReceiver"
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received intent with action: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                // Here we would reschedule all notifications after device reboot
                Log.d(TAG, "Received BOOT_COMPLETED event")
                // This requires storing scheduled notifications in a database
            }
            Constants.IntentActions.NOTIFICATION_CLICKED -> {
                val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)
                val payload = intent.getStringExtra(Constants.IntentExtras.PAYLOAD) 
                    ?: intent.getStringExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)

                Log.d(TAG, "Notification clicked with ID: $notificationId, Payload: $payload")

                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    // Make sure we bring the app to foreground
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    
                    // Set a debug action
                    action = "${Constants.PACKAGE_NAME}.NOTIFICATION_CLICK"
                    
                    if (payload != null) {
                        putExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD, payload)
                    }
                }

                try {
                    Log.d(TAG, "Starting MainActivity with payload: $payload")
                    context.startActivity(launchIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error starting MainActivity: ${e.message}")
                }
            }
            Constants.IntentActions.ALARM_TRIGGERED -> {
                val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)
                val title = intent.getStringExtra(Constants.IntentExtras.TITLE) ?: "Reminder"
                val body = intent.getStringExtra(Constants.IntentExtras.BODY) ?: "You have a reminder"
                val payload = intent.getStringExtra(Constants.IntentExtras.PAYLOAD)

                Log.d(TAG, "Alarm triggered for notification ID: $notificationId, payload: $payload")

                val notificationHelper = NotificationHelper(context)
                notificationHelper.showNotification(notificationId, title, body, payload)
            }
            else -> {
                Log.d(TAG, "Received unhandled intent action: ${intent.action}")
                
                // Check if this is potentially a notification click with missing action
                if (intent.hasExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)) {
                    val payload = intent.getStringExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD)
                    Log.d(TAG, "Found notification payload in intent without proper action: $payload")
                    
                    // Try to handle it anyway by forwarding to MainActivity
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        action = "me.ahmetcetinkaya.whph.NOTIFICATION_CLICK"
                        putExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD, payload)
                    }

                    try {
                        context.startActivity(launchIntent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting MainActivity for unhandled intent: ${e.message}")
                    }
                }
            }
        }
    }
}
