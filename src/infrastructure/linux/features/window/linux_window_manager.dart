import 'package:flutter/services.dart';
import '../../../shared/features/window/window_manager.dart';

/// Linux-specific implementation of WindowManagerInterface with native platform channel support
class LinuxWindowManager extends WindowManager {
  /// Platform channel for native window operations
  static const MethodChannel _channel = MethodChannel('me.ahmetcetinkaya.whph/app_usage');

  /// Constructor
  LinuxWindowManager();

  @override
  Future<void> focus() async {
    try {
      // Try to focus using base implementation first
      await super.focus();

      // Check if already focused
      final bool isFocused = await super.isFocused();
      if (isFocused) {
        return;
      }

      // Get the current window title
      final String currentTitle = await getTitle();

      // Use native implementation to focus window
      final bool success = await _channel.invokeMethod<bool>('focusWindow', currentTitle) ?? false;

      if (!success) {
        // If native focus failed, try with default app name
        await _channel.invokeMethod<bool>('focusWindow', 'whph');
      }
    } catch (e) {
      // If platform channel fails, fallback to base implementation
      await super.focus();
    }
  }

  /// Focus window by title using native implementation
  Future<bool> focusWindowByTitle(String title) async {
    try {
      return await _channel.invokeMethod<bool>('focusWindow', title) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get active window info from native implementation
  Future<String?> getActiveWindowInfo() async {
    try {
      return await _channel.invokeMethod<String>('getActiveWindow');
    } catch (e) {
      return null;
    }
  }
}
