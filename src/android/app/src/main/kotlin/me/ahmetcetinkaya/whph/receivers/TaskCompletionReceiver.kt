package me.ahmetcetinkaya.whph.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.Constants

/**
 * Broadcast receiver for task completions from notification action buttons. Receives
 * TASK_COMPLETE_BROADCAST broadcasts and forwards them to Flutter via the notification method
 * channel.
 */
class TaskCompletionReceiver : BroadcastReceiver() {
  @Suppress("PropertyNaming") private val TAG = "TaskCompletionReceiver"

  override fun onReceive(context: Context?, intent: Intent?) {
    try {
      if (intent?.action == Constants.IntentActions.TASK_COMPLETE_BROADCAST) {
        val taskId = intent.getStringExtra(Constants.IntentExtras.TASK_ID)
        Log.d(TAG, "Task completion broadcast received: $taskId")

        if (taskId != null) {
          // Send completion to Flutter via MethodChannel
          val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
          if (binaryMessenger != null) {
            val channel = MethodChannel(binaryMessenger, Constants.Channels.NOTIFICATION)
            channel.invokeMethod("completeTask", taskId)
            Log.d(TAG, "Successfully sent task completion to Flutter: $taskId")

            // Clear the pending entry since we successfully sent it to Flutter
            val prefs = context?.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
            prefs?.edit()?.remove("complete_task_$taskId")?.apply()
            Log.d(TAG, "Cleared pending task completion entry: $taskId")
          } else {
            Log.w(
              TAG,
              "Flutter engine not ready for task completion - already stored as pending by NotificationReceiver",
            )
          }
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error in TaskCompletionReceiver.onReceive: ${e.message}", e)
    }
  }

  companion object {
    // Static reference to FlutterEngine (set by MainActivity)
    private var flutterEngine: io.flutter.embedding.engine.FlutterEngine? = null

    /** Set the Flutter engine for this receiver. Called by MainActivity during initialization. */
    fun setFlutterEngine(engine: io.flutter.embedding.engine.FlutterEngine?) {
      flutterEngine = engine
    }

    /** Create the intent filter for this receiver. */
    fun createIntentFilter(): IntentFilter =
      IntentFilter(Constants.IntentActions.TASK_COMPLETE_BROADCAST)
  }
}
