import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'abstractions/i_wakelock_service.dart';

/// Implementation of IWakelockService using wakelock_plus package
class WakelockService implements IWakelockService {
  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      if (kDebugMode) {
        debugPrint('Wakelock enabled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to enable wakelock: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      if (kDebugMode) {
        debugPrint('Wakelock disabled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to disable wakelock: $e');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to check wakelock status: $e');
      }
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }
}
