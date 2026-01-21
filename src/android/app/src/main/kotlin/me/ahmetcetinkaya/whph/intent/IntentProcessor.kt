package me.ahmetcetinkaya.whph.intent

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.Constants
import me.ahmetcetinkaya.whph.handlers.BootCompletedHandler
import me.ahmetcetinkaya.whph.handlers.NotificationMethodHandler
import me.ahmetcetinkaya.whph.handlers.ShareIntentHandler

/**
 * Centralized intent processing logic. Handles notification payloads, widget clicks, share intents,
 * and boot completed notifications.
 */
class IntentProcessor(
  private val context: Context,
  private val notificationMethodHandler: NotificationMethodHandler,
  private val shareIntentHandler: ShareIntentHandler,
  private val bootCompletedHandler: BootCompletedHandler,
) {
  private val TAG = "IntentProcessor"

  companion object {
    const val ACTION_NOTIFICATION_CLICK = "${Constants.PACKAGE_NAME}.NOTIFICATION_CLICK"
    const val ACTION_SELECT_NOTIFICATION =
      "SELECT_NOTIFICATION" // Standard action from FlutterLocalNotifications
    const val NOTIFICATION_HANDLER_DELAY_MS = 1000L
  }

  /**
   * Process an intent to extract and handle notification payload, widget clicks, or share intents.
   *
   * @param intent The intent to process
   * @param flutterEngine The Flutter engine (optional, for immediate delivery)
   */
  fun processIntent(
    intent: Intent?,
    flutterEngine: io.flutter.embedding.engine.FlutterEngine? = null,
  ) {
    if (intent == null) {
      Log.d(TAG, "processIntent: Intent is null")
      return
    }

    Log.d(TAG, "Processing intent with action: ${intent.action}")
    Log.d(TAG, "Intent data: ${intent.data}")

    // Check for share intents (ACTION_SEND)
    if (intent.action == Intent.ACTION_SEND) {
      Log.d(TAG, "=== SHARE INTENT DETECTED ===")
      shareIntentHandler.handleShareIntent(intent, flutterEngine)
      return
    }

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

    // Check if there's a notification ID related to this intent and cancel it
    if (intent.hasExtra(Constants.IntentExtras.NOTIFICATION_ID)) {
      val notificationId = intent.getIntExtra(Constants.IntentExtras.NOTIFICATION_ID, -1)
      if (notificationId != -1) {
        Log.d(TAG, "Explicitly cancelling clicked notification ID: $notificationId")
        NotificationManagerCompat.from(context).cancel(notificationId)
      }
    }

    // Extract payload based on the action
    val payload =
      when (intent.action) {
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
          handleBootCompletedNotification(flutterEngine?.dartExecutor?.binaryMessenger)
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
      notificationMethodHandler.setInitialNotificationPayload(payload)
      Log.d(TAG, "Stored initialNotificationPayload: $payload")

      // Check if Flutter engine is ready before attempting to send the payload
      if (flutterEngine != null) {
        Log.d(TAG, "Flutter engine is ready, sending payload immediately")
        notifyFlutterOfPayload(payload, flutterEngine.dartExecutor.binaryMessenger)
      } else {
        Log.d(TAG, "Flutter engine not ready, payload will be sent when engine is configured")
      }
    } else {
      Log.d(
        TAG,
        "No payload found in intent. Intent extras: ${intent.extras?.keySet()?.joinToString()}",
      )
    }
  }

  /**
   * Handle widget click by triggering the HomeWidget plugin's click mechanism.
   *
   * @param uri The widget click URI
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
        val triggerClickMethod =
          homeWidgetClass.getDeclaredMethod("triggerClick", String::class.java)
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
            val widgetClickedMethod =
              homeWidgetClass.getDeclaredMethod("widgetClicked", String::class.java)
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
   * Fallback method to handle widget clicks when HomeWidget plugin methods fail.
   *
   * @param uri The widget click URI
   */
  private fun fallbackWidgetClick(uri: Uri) {
    try {
      Log.d(TAG, "Using fallback widget click handling")

      // Send a broadcast that might be picked up by the HomeWidget plugin
      val broadcastIntent =
        Intent().apply {
          action = "es.antonborri.home_widget.WIDGET_CLICK"
          putExtra("url", uri.toString())
          setPackage(context.packageName)
        }
      context.sendBroadcast(broadcastIntent)
      Log.d(TAG, "Sent fallback broadcast for widget click")
    } catch (e: Exception) {
      Log.e(TAG, "Fallback widget click handling failed", e)
    }
  }

  /**
   * Notify Flutter of a notification payload.
   *
   * @param payload The notification payload to send
   * @param binaryMessenger The binary messenger to invoke the method channel
   */
  fun notifyFlutterOfPayload(
    payload: String,
    binaryMessenger: io.flutter.plugin.common.BinaryMessenger?,
  ) {
    try {
      Handler(Looper.getMainLooper())
        .postDelayed(
          {
            try {
              if (binaryMessenger != null) {
                Log.d(TAG, "Sending notification payload to Flutter: $payload")
                MethodChannel(binaryMessenger, Constants.Channels.NOTIFICATION)
                  .invokeMethod("onNotificationClicked", payload)
                Log.d(TAG, "Successfully sent notification payload to Flutter")
              } else {
                Log.e(TAG, "BinaryMessenger is null, can't send payload")
              }
            } catch (e: Exception) {
              Log.e(TAG, "Error sending notification payload to Flutter: ${e.message}", e)
            }
          },
          NOTIFICATION_HANDLER_DELAY_MS,
        ) // Short delay to ensure Flutter is ready
    } catch (e: Exception) {
      Log.e(TAG, "Error setting up delayed payload delivery: ${e.message}", e)
    }
  }

  /**
   * Notify Flutter of shared text.
   *
   * @param text The shared text
   * @param subject The optional subject
   * @param binaryMessenger The binary messenger to invoke the method channel
   */
  fun notifyFlutterOfShare(
    text: String,
    subject: String?,
    binaryMessenger: io.flutter.plugin.common.BinaryMessenger?,
  ) {
    try {
      Handler(Looper.getMainLooper())
        .postDelayed(
          {
            try {
              if (binaryMessenger != null) {
                Log.d(TAG, "Sending share data to Flutter: text='$text', subject='$subject'")
                val shareData = mapOf("text" to text, "subject" to subject)
                MethodChannel(binaryMessenger, Constants.Channels.SHARE)
                  .invokeMethod("onSharedText", shareData)
                Log.d(TAG, "Successfully sent share data to Flutter")
              } else {
                Log.e(TAG, "BinaryMessenger is null, can't send share data")
              }
            } catch (e: Exception) {
              Log.e(TAG, "Error sending share data to Flutter: ${e.message}", e)
            }
          },
          NOTIFICATION_HANDLER_DELAY_MS,
        ) // Short delay to ensure Flutter is ready
    } catch (e: Exception) {
      Log.e(TAG, "Error setting up delayed share delivery: ${e.message}", e)
    }
  }

  /**
   * Handle boot completed notification from NotificationReceiver.
   *
   * @param binaryMessenger The binary messenger to invoke the method channel
   */
  private fun handleBootCompletedNotification(
    binaryMessenger: io.flutter.plugin.common.BinaryMessenger?
  ) {
    bootCompletedHandler.onBootCompleted(binaryMessenger)
  }
}
