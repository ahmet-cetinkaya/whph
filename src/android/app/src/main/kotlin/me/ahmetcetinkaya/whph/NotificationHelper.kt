package me.ahmetcetinkaya.whph

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

class NotificationHelper(private val context: Context) {
    private val TAG = "NotificationHelper"
    
    init {
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val taskChannel = NotificationChannel(
                Constants.NotificationChannels.TASK_CHANNEL_ID,
                Constants.NotificationChannels.TASK_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for task reminders"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            notificationManager.createNotificationChannel(taskChannel)

            val habitChannel = NotificationChannel(
                Constants.NotificationChannels.HABIT_CHANNEL_ID,
                Constants.NotificationChannels.HABIT_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for habit reminders"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            notificationManager.createNotificationChannel(habitChannel)
        }
    }

    fun showNotification(id: Int, title: String, body: String, payload: String?) {
        Log.d(TAG, "Showing notification with ID: $id, Title: $title, Payload: $payload")
        
        // Create an explicit intent to launch MainActivity
        // Use the specific action we defined in the AndroidManifest
        val activityIntent = Intent(context, MainActivity::class.java).apply {
            action = Constants.IntentActions.NOTIFICATION_CLICK
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP

            // Add the payload as an extra
            if (payload != null) {
                putExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD, payload)
                
                // For detailed debugging purposes
                try {
                    val jsonPayload = JSONObject(payload)
                    Log.d(TAG, "Payload route: ${jsonPayload.optString("route")}")
                    Log.d(TAG, "Payload arguments: ${jsonPayload.optJSONObject("arguments")}")
                } catch (e: Exception) {
                    Log.d(TAG, "Non-JSON payload or parsing error: ${e.message}")
                }
            }
        }

        // Create a PendingIntent with a unique request code per notification ID
        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Determine the correct notification channel
        val channelId = if (payload?.contains("habitId") == true || payload?.contains("/habits") == true) {
            Constants.NotificationChannels.HABIT_CHANNEL_ID
        } else {
            Constants.NotificationChannels.TASK_CHANNEL_ID
        }

        // Build the notification
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)

        try {
            // Show the notification
            NotificationManagerCompat.from(context).notify(id, builder.build())
            Log.d(TAG, "Successfully showed notification with ID: $id")
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to show notification: ${e.message}")
        }
    }
}
