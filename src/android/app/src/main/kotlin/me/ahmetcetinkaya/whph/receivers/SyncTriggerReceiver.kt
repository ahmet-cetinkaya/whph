package me.ahmetcetinkaya.whph.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import me.ahmetcetinkaya.whph.Constants

/**
 * Broadcast receiver for sync triggers from WorkManager. Receives SYNC_TRIGGER broadcasts and
 * forwards them to Flutter via the sync method channel.
 */
class SyncTriggerReceiver : BroadcastReceiver() {
  private val TAG = "SyncTriggerReceiver"

  override fun onReceive(context: Context?, intent: Intent?) {
    if (intent?.action == "${Constants.PACKAGE_NAME}.SYNC_TRIGGER") {
      Log.d(TAG, "Sync trigger received from WorkManager")

      // Trigger sync via method channel to Flutter
      val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
      if (binaryMessenger != null) {
        val channel = MethodChannel(binaryMessenger, Constants.Channels.SYNC)
        channel.invokeMethod("triggerSync", null)
        Log.d(TAG, "Successfully triggered sync via method channel")
      } else {
        Log.w(TAG, "Flutter engine not ready, cannot trigger sync")
      }
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
      return IntentFilter("${Constants.PACKAGE_NAME}.SYNC_TRIGGER")
    }
  }
}
