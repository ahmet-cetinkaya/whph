package me.ahmetcetinkaya.whph.handlers

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.Constants

/**
 * Handler for boot completed event notifications. Provides methods to notify Flutter when the
 * device has finished booting.
 */
class BootCompletedHandler(private val context: Context) {
  private val TAG = "BootCompletedHandler"

  private val NOTIFICATION_HANDLER_DELAY_MS = 1000L // Wait 1 second before trying to send event

  /**
   * Notify Flutter that boot has completed. Uses a delay to ensure Flutter is ready before sending
   * the notification.
   *
   * @param binaryMessenger The binary messenger to invoke the method channel
   */
  fun onBootCompleted(binaryMessenger: BinaryMessenger?) {
    try {
      Log.d(TAG, "Handling boot completed notification")

      // Delay to ensure Flutter is ready before sending the notification
      Handler(Looper.getMainLooper())
        .postDelayed(
          {
            try {
              if (binaryMessenger != null) {
                val channel = MethodChannel(binaryMessenger, Constants.Channels.BOOT_COMPLETED)
                channel.invokeMethod(
                  "onBootCompleted",
                  null,
                  object : MethodChannel.Result {
                    override fun success(result: Any?) {
                      Log.d(TAG, "Successfully notified Flutter about boot completed")
                    }

                    override fun error(
                      errorCode: String,
                      errorMessage: String?,
                      errorDetails: Any?,
                    ) {
                      Log.e(
                        TAG,
                        "Error notifying Flutter about boot completed: $errorCode - $errorMessage",
                      )
                    }

                    override fun notImplemented() {
                      Log.w(TAG, "Boot completed method not implemented in Flutter")
                    }
                  },
                )
              } else {
                Log.w(
                  TAG,
                  "BinaryMessenger is null, cannot send boot completed notification to Flutter",
                )
              }
            } catch (e: Exception) {
              Log.e(TAG, "Error sending boot completed notification to Flutter: ${e.message}", e)
            }
          },
          NOTIFICATION_HANDLER_DELAY_MS,
        )
    } catch (e: Exception) {
      Log.e(TAG, "Error in onBootCompleted: ${e.message}", e)
    }
  }
}
