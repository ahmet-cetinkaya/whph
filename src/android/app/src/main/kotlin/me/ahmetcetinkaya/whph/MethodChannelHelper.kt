package me.ahmetcetinkaya.whph

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Helper class to reduce boilerplate when setting up method channels. Provides generic handlers for
 * common patterns.
 */
object MethodChannelHelper {
  private val TAG = "MethodChannelHelper"

  /**
   * Set up a simple method channel that delegates to handler functions.
   *
   * @param messenger The binary messenger
   * @param channelName The channel name
   * @param handlers Map of method names to handler functions
   */
  fun setupChannel(
    messenger: BinaryMessenger,
    channelName: String,
    handlers: Map<String, (MethodCall, MethodChannel.Result) -> Unit>,
  ) {
    MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
      handlers[call.method]?.invoke(call, result) ?: result.notImplemented()
    }
  }

  /**
   * Wrap a handler function with try-catch and error handling.
   *
   * @param errorCode The error code to use on failure
   * @param block The handler function
   */
  fun safeCall(errorCode: String = "ERROR", block: () -> Unit) {
    try {
      block()
    } catch (e: Exception) {
      Log.e(TAG, "Error in $errorCode: ${e.message}", e)
      throw e
    }
  }

  /** Create a result wrapper that handles errors consistently. */
  fun Result.Companion.fromCall(block: () -> Any?): MethodChannel.Result {
    return object : MethodChannel.Result {
      override fun success(result: Any?) = Unit

      override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

      override fun notImplemented() = Unit
    }
  }
}
