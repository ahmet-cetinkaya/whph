package me.ahmetcetinkaya.whph.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.Constants

/**
 * Broadcast receiver for habit completions from notification action buttons. Receives
 * HABIT_COMPLETE_BROADCAST broadcasts and forwards them to Flutter via the notification method
 * channel.
 */
class HabitCompletionReceiver : BroadcastReceiver() {
  private val TAG = "HabitCompletionReceiver"

  override fun onReceive(context: Context?, intent: Intent?) {
    try {
      if (intent?.action == Constants.IntentActions.HABIT_COMPLETE_BROADCAST) {
        val habitId = intent.getStringExtra(Constants.IntentExtras.HABIT_ID)
        Log.d(TAG, "Habit completion broadcast received: $habitId")

        if (habitId != null) {
          // Send completion to Flutter via MethodChannel
          val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
          if (binaryMessenger != null) {
            val channel = MethodChannel(binaryMessenger, Constants.Channels.NOTIFICATION)
            channel.invokeMethod("completeHabit", habitId)
            Log.d(TAG, "Successfully sent habit completion to Flutter: $habitId")

            // Clear the pending entry since we successfully sent it to Flutter
            val prefs = context?.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
            prefs?.edit()?.remove("complete_habit_$habitId")?.apply()
            Log.d(TAG, "Cleared pending habit completion entry: $habitId")
          } else {
            Log.w(
              TAG,
              "Flutter engine not ready for habit completion - already stored as pending by NotificationReceiver",
            )
          }
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error in HabitCompletionReceiver.onReceive: ${e.message}", e)
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
    fun createIntentFilter(): IntentFilter {
      return IntentFilter(Constants.IntentActions.HABIT_COMPLETE_BROADCAST)
    }
  }
}
