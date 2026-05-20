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
  private val tag = "NotificationHelper"

  init {
    createNotificationChannels()
  }

  private fun createNotificationChannels() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

      createNotificationChannel(
        notificationManager,
        Constants.NotificationChannels.TASK_CHANNEL_ID,
        Constants.NotificationChannels.TASK_CHANNEL_NAME,
        "Notifications for task reminders",
        Color.RED,
      )

      createNotificationChannel(
        notificationManager,
        Constants.NotificationChannels.HABIT_CHANNEL_ID,
        Constants.NotificationChannels.HABIT_CHANNEL_NAME,
        "Notifications for habit reminders",
        Color.BLUE,
      )
    }
  }

  private fun createNotificationChannel(
    notificationManager: NotificationManager,
    channelId: String,
    channelName: String,
    description: String,
    lightColor: Int,
  ) {
    val channel =
      NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH).apply {
        this.description = description
        enableLights(true)
        lightColor = lightColor
        enableVibration(true)
        setSound(
          RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
          AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build(),
        )
      }
    notificationManager.createNotificationChannel(channel)
  }

  fun showNotification(
    id: Int,
    title: String,
    body: String,
    payload: String?,
    actionButtonText: String? = null,
  ): Boolean {
    Log.d(
      tag,
      "Showing notification with ID: $id, Title: $title, Payload: $payload, ActionText: $actionButtonText",
    )

    val activityIntent =
      Intent(context, MainActivity::class.java).apply {
        action = Constants.IntentActions.NOTIFICATION_CLICK
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

        if (payload != null) {
          putExtra(Constants.IntentExtras.NOTIFICATION_PAYLOAD, payload)

          try {
            val jsonPayload = JSONObject(payload)
            Log.d(tag, "Payload route: ${jsonPayload.optString("route")}")
            Log.d(tag, "Payload arguments: ${jsonPayload.optJSONObject("arguments")}")
          } catch (e: Exception) {
            Log.d(tag, "Non-JSON payload or parsing error: ${e.message}")
          }
        }
      }

    val pendingIntent =
      PendingIntent.getActivity(
        context,
        id,
        activityIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )

    val channelId = resolveNotificationChannel(payload)

    val completePendingIntent = buildCompleteAction(payload, channelId)

    val builder =
      NotificationCompat.Builder(context, channelId)
        .setSmallIcon(R.drawable.ic_notification)
        .setContentTitle(title)
        .setContentText(body)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setContentIntent(pendingIntent)
        .setAutoCancel(false)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setCategory(NotificationCompat.CATEGORY_REMINDER)

    completePendingIntent?.let {
      val actionLabel =
        actionButtonText ?: context.getString(R.string.notification_action_mark_done)
      builder.addAction(R.drawable.ic_widget_done_all, actionLabel, it)
    }

    return try {
      NotificationManagerCompat.from(context).notify(id, builder.build())
      Log.d(tag, "Successfully showed notification with ID: $id")
      true
    } catch (e: SecurityException) {
      Log.e(tag, "Failed to show notification: ${e.message}")
      false
    }
  }

  private fun resolveNotificationChannel(payload: String?): String {
    return if (isHabitPayload(payload)) {
      Constants.NotificationChannels.HABIT_CHANNEL_ID
    } else {
      Constants.NotificationChannels.TASK_CHANNEL_ID
    }
  }

  private fun isHabitPayload(payload: String?): Boolean {
    return payload?.contains("habitId") == true || payload?.contains("/habits") == true
  }

  private fun buildCompleteAction(payload: String?, channelId: String): PendingIntent? {
    val taskId = extractPayloadId(payload, "taskId")
    val habitId = extractPayloadId(payload, "habitId")

    return when {
      channelId == Constants.NotificationChannels.TASK_CHANNEL_ID && taskId != null ->
        buildCompleteIntent(Constants.IntentActions.TASK_COMPLETE_ACTION, taskId, idOffset = 1000)
      channelId == Constants.NotificationChannels.HABIT_CHANNEL_ID && habitId != null ->
        buildCompleteIntent(Constants.IntentActions.HABIT_COMPLETE_ACTION, habitId, idOffset = 2000)
      else -> null
    }
  }

  private fun buildCompleteIntent(action: String, entityId: String, idOffset: Int): PendingIntent {
    val completeIntent =
      Intent(context, NotificationReceiver::class.java).apply {
        this.action = action
        putExtra(
          if (action == Constants.IntentActions.TASK_COMPLETE_ACTION) Constants.IntentExtras.TASK_ID
          else Constants.IntentExtras.HABIT_ID,
          entityId,
        )
      }
    return PendingIntent.getBroadcast(
      context,
      idOffset,
      completeIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  private fun extractPayloadId(payload: String?, key: String): String? {
    if (payload == null) return null
    return try {
      val jsonPayload = JSONObject(payload)
      jsonPayload.getJSONObject("arguments")?.optString(key)
    } catch (e: Exception) {
      Log.d(tag, "Failed to extract $key from payload: ${e.message}")
      null
    }
  }
}
