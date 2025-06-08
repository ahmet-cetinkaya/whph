import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:whph/corePackages/acore/logging/i_logger.dart';
import 'abstractions/i_wakelock_service.dart';

/// Implementation of IWakelockService using wakelock_plus package
class WakelockService implements IWakelockService {
  final ILogger _logger;

  /// Creates a new instance of WakelockService
  const WakelockService(this._logger);
  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      _logger.info('Wakelock enabled successfully');
    } catch (e) {
      _logger.error('Failed to enable wakelock', e);
      rethrow;
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      _logger.info('Wakelock disabled successfully');
    } catch (e) {
      _logger.error('Failed to disable wakelock', e);
      rethrow;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      _logger.error('Failed to check wakelock status', e);
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
