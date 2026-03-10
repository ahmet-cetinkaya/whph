package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.Constants

/**
 * Handler for share intent operations. Manages share intent state (initialShareText,
 * initialShareSubject) and provides methods to retrieve and acknowledge share data.
 */
class ShareIntentHandler(private val context: Context) {
  @Suppress("PropertyNaming") private val TAG = "ShareIntentHandler"

  // Store the initial share intent data
  var initialShareText: String? = null
    private set

  var initialShareSubject: String? = null
    private set

  private val NOTIFICATION_HANDLER_DELAY_MS = 1000L // Wait 1 second before trying to send data

  /**
   * Get the initial share intent data.
   *
   * @return A map containing "text" and "subject" keys
   */
  fun getInitialShareIntent(): Map<String, Any?> {
    Log.d(
      TAG,
      "Getting initial share intent: text='$initialShareText', subject='$initialShareSubject'",
    )
    return mapOf("text" to initialShareText, "subject" to initialShareSubject)
  }

  /** Acknowledge that the share intent has been processed and clear the stored data. */
  fun acknowledgeShareIntent() {
    Log.d(TAG, "Acknowledging share intent")
    initialShareText = null
    initialShareSubject = null
  }

  /**
   * Handle a share intent to extract shared text and subject. Stores the data for later retrieval
   * if Flutter engine is not ready yet.
   *
   * @param intent The share intent to process
   * @param flutterEngine The Flutter engine (optional, for immediate delivery)
   */
  fun handleShareIntent(intent: Intent, flutterEngine: FlutterEngine? = null) {
    try {
      Log.d(TAG, "=== HANDLING SHARE INTENT ===")

      // Extract shared text from Intent.EXTRA_TEXT
      val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
      val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)

      Log.d(TAG, "Shared text: $sharedText")
      Log.d(TAG, "Shared subject: $sharedSubject")

      if (sharedText != null && sharedText.isNotEmpty()) {
        // Store the share data for later use if Flutter engine is not ready yet
        initialShareText = sharedText
        initialShareSubject = sharedSubject
        Log.d(TAG, "Stored initial share data: text='$sharedText', subject='$sharedSubject'")

        // Check if Flutter engine is ready before attempting to send the data
        if (flutterEngine != null) {
          Log.d(TAG, "Flutter engine is ready, sending share data immediately")
          notifyFlutterOfShare(sharedText, sharedSubject, flutterEngine)
        } else {
          Log.d(TAG, "Flutter engine not ready, share data will be sent when engine is configured")
        }
      } else {
        Log.w(TAG, "Share intent received but no text found")
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error handling share intent: ${e.message}", e)
    }
  }

  /**
   * Notify Flutter of shared text.
   *
   * @param text The shared text
   * @param subject The optional subject
   * @param flutterEngine The Flutter engine
   */
  fun notifyFlutterOfShare(text: String, subject: String?, flutterEngine: FlutterEngine) {
    try {
      Handler(Looper.getMainLooper())
        .postDelayed(
          {
            try {
              Log.d(TAG, "Sending share data to Flutter: text='$text', subject='$subject'")
              val shareData = mapOf("text" to text, "subject" to subject)
              MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.Channels.SHARE)
                .invokeMethod("onSharedText", shareData)
              Log.d(TAG, "Successfully sent share data to Flutter")
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
}
