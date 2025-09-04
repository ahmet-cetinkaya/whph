import 'dart:async';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';

class DesktopSyncService extends SyncService {
  Timer? _periodicTimer;
  static const Duration _syncInterval = Duration(minutes: 30);

  DesktopSyncService(super.mediator);

  @override
  Future<void> startSync() async {
    // First, clear the existing timer
    stopSync();

    Logger.debug('Starting desktop periodic sync (30 minutes)');

    // Run the initial sync
    await runSync();

    // Start periodic sync for desktop
    _periodicTimer = Timer.periodic(_syncInterval, (timer) async {
      try {
        Logger.debug('Running periodic sync at ${DateTime.now()}');
        await runSync();
      } catch (e) {
        Logger.error('Periodic sync failed: $e');
      }
    });

    Logger.debug('Started desktop periodic sync with interval: ${_syncInterval.inMinutes} minutes');
  }

  @override
  void stopSync() {
    // Stop desktop timer-based sync
    if (_periodicTimer != null) {
      Logger.debug('Stopping desktop periodic sync');
      _periodicTimer!.cancel();
      _periodicTimer = null;
    }
  }

  @override
  void dispose() {
    stopSync();
    super.dispose();
  }
}
