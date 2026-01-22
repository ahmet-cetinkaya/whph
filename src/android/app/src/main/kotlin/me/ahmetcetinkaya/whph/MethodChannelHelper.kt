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
   * Wrap a handler function with try-catch and error handling. Returns the result of the block, or
   * null if an exception occurs.
   *
   * @param result The MethodChannel.Result to report errors to
   * @param errorCode The error code to use on failure
   * @param block The handler function
   */
  fun safeCall(result: MethodChannel.Result, errorCode: String = "ERROR", block: () -> Any?) {
    try {
      val returnValue = block()
      result.success(returnValue)
    } catch (e: Exception) {
      Log.e(TAG, "Error in safeCall: ${e.message}", e)
      result.error(errorCode, e.message, null)
    }
  }

  /**
   * Wrap a handler function with try-catch for unit-returning operations.
   *
   * @param result The MethodChannel.Result to report errors to
   * @param errorCode The error code to use on failure
   * @param block The handler function
   */
  fun safeCallUnit(result: MethodChannel.Result, errorCode: String = "ERROR", block: () -> Unit) {
    try {
      block()
      result.success(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error in safeCallUnit: ${e.message}", e)
      result.error(errorCode, e.message, null)
    }
  }
}
