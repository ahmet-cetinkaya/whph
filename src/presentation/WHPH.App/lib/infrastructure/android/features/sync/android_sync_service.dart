import 'dart:async';
import 'package:flutter/services.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';

class AndroidSyncService extends SyncService {
  static final MethodChannel _syncChannel = MethodChannel(AndroidAppConstants.channels.sync);

  AndroidSyncService(super.mediator);

  @override
  Future<void> startSync() async {
    // First, clear the existing timer
    stopSync();

    Logger.debug('Starting Android WorkManager periodic sync (30 minutes)');

    // Setup listener for WorkManager triggers first
    _setupSyncListener(() async {
      Logger.info('Sync triggered by Android WorkManager');
      await _runSync();
    });

    // Start WorkManager periodic sync (30 minutes interval)
    final success = await _startPeriodicSyncWork(intervalMinutes: 30);
    if (success) {
      Logger.info('Android periodic sync started successfully');
    } else {
      Logger.error('Failed to start Android periodic sync');
    }

    // For Android, delay initial sync and use UI-optimized version
    Timer(const Duration(seconds: 60), () async {
      Logger.info('Running delayed initial sync with UI optimization after 60 seconds');
      await _runSync();
    });
  }

  /// Run sync with UI thread optimization to prevent frame drops
  Future<void> _runSync() async {
    try {
      // Use scheduleMicrotask to ensure sync doesn't block UI
      final syncCompleter = Completer<void>();

      scheduleMicrotask(() async {
        try {
          // Pass isManual: false for automatic WorkManager sync
          await runPaginatedSync(isManual: false);
          syncCompleter.complete();
        } catch (e) {
          syncCompleter.completeError(e);
        }
      });

      await syncCompleter.future;
    } catch (e) {
      Logger.error('UI-optimized sync failed: $e');
      rethrow;
    }
  }

  @override
  void stopSync() {
    Logger.debug('Stopping Android WorkManager periodic sync');
    _stopPeriodicSyncWork().then((success) {
      if (success) {
        Logger.info('Android periodic sync stopped successfully');
      } else {
        Logger.error('Failed to stop Android periodic sync');
      }
    });
  }

  /// Starts periodic sync work with specified interval (default: 30 minutes)
  Future<bool> _startPeriodicSyncWork({int? intervalMinutes}) async {
    try {
      final result = await _syncChannel.invokeMethod('startPeriodicSyncWork', {
        if (intervalMinutes != null) 'intervalMinutes': intervalMinutes,
      });
      Logger.info('Periodic sync work started successfully: $result');
      return result == true;
    } catch (e) {
      Logger.error('Failed to start periodic sync work: $e');
      return false;
    }
  }

  /// Stops periodic sync work
  Future<bool> _stopPeriodicSyncWork() async {
    try {
      final result = await _syncChannel.invokeMethod('stopPeriodicSyncWork');
      Logger.info('Periodic sync work stopped successfully: $result');
      return result == true;
    } catch (e) {
      Logger.error('Failed to stop periodic sync work: $e');
      return false;
    }
  }

  /// Sets up method channel listener for sync triggers from Android
  void _setupSyncListener(Function() onSyncTriggered) {
    _syncChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerSync') {
        Logger.info('Sync triggered from Android WorkManager');
        onSyncTriggered();
      }
    });
  }
}
