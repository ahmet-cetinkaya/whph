import 'dart:async';
import 'package:flutter/services.dart';
import 'package:whph/src/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/core/application/features/sync/services/sync_service.dart';

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
      await runSync();
    });

    // Start WorkManager periodic sync (30 minutes interval)
    final success = await _startPeriodicSyncWork(intervalMinutes: 30);
    if (success) {
      Logger.info('Android periodic sync started successfully');
    } else {
      Logger.error('Failed to start Android periodic sync');
    }

    // For Android, we still want to do an initial sync, but delay it by 60 seconds to improve app startup performance
    Timer(const Duration(seconds: 60), () async {
      Logger.info('Running delayed initial sync after 60 seconds');
      await runSync();
    });
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
