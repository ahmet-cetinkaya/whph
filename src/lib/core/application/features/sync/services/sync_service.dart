import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mediatr/mediatr.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/shared/utils/logger.dart';

import 'abstraction/i_sync_service.dart';

class SyncService implements ISyncService {
  final Mediator _mediator;

  /// Protected getter for mediator access in subclasses
  @protected
  Mediator get mediator => _mediator;

  final _syncCompleteController = StreamController<bool>.broadcast();
  WebSocketChannel? _channel;
  DateTime? _lastSyncTime;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  @override
  Stream<bool> get onSyncComplete => _syncCompleteController.stream;
  bool get isConnected => _isConnected;

  // Progress tracking for paginated sync
  final _progressController = StreamController<SyncProgress>.broadcast();
  @override
  Stream<SyncProgress> get progressStream => _progressController.stream;

  // Sync status tracking
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);

  @override
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  @override
  SyncStatus get currentSyncStatus => _currentSyncStatus;

  @override
  void updateSyncStatus(SyncStatus status) {
    _currentSyncStatus = status;
    _syncStatusController.add(status);
    Logger.debug('Sync status updated: $status');
  }

  SyncService(this._mediator);

  void _handleDisconnection() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;

    // In case of force close, do not attempt to reconnect
    if (_lastSyncTime != null && DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 5)) {
      Logger.debug('Recent sync completed, skipping reconnection');
      return;
    }

    // If maximum attempts reached or initialization is in progress
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      Logger.debug('Max reconnection attempts reached or initialization in progress, resetting counter');

      _reconnectAttempts = 0;
      return;
    }

    // Attempt to reconnect in case of normal disconnect
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
  }

  @override
  Future<void> startSync() async {
    // Default implementation - can be overridden by platform-specific services
    Logger.debug('Base SyncService startSync called');
    await runSync();
  }

  @override
  Future<void> runSync({bool isManual = false}) async {
    // Redirect to paginated sync - this is now the default and only sync method
    await runPaginatedSync(isManual: isManual);
  }

  /// Runs paginated sync operation - this is now the primary sync method
  @override
  Future<void> runPaginatedSync({bool isManual = false}) async {
    try {
      // Update sync status to syncing
      updateSyncStatus(SyncStatus(
        state: SyncState.syncing,
        isManual: isManual,
        lastSyncTime: DateTime.now(),
      ));

      Logger.debug('Starting paginated sync process at ${DateTime.now()}... (manual: $isManual)');

      // Create paginated sync command handler and listen to progress
      final command = PaginatedSyncCommand();
      final response = await _mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

      // Check if sync was actually successful and had no errors
      if (response.isComplete && !response.hasErrors) {
        // Reset the attempt count on successful sync
        _reconnectAttempts = 0;

        Logger.info('✅ Paginated sync completed successfully');

        // Update sync status to completed
        updateSyncStatus(SyncStatus(
          state: SyncState.completed,
          isManual: isManual,
          lastSyncTime: DateTime.now(),
        ));

        // Only notify sync completion for meaningful syncs
        // Don't notify for background syncs that found no devices
        _notifySyncCompleteIfMeaningful(isManual, response);
      } else {
        // Sync failed, was incomplete, or had errors
        final errorReason =
            response.hasErrors ? 'Sync errors: ${response.errorMessages.join('; ')}' : 'Sync was incomplete or failed';

        Logger.error('❌ Paginated sync failed: $errorReason');

        // Update sync status to error
        updateSyncStatus(SyncStatus(
          state: SyncState.error,
          errorMessage: errorReason,
          isManual: isManual,
          lastSyncTime: DateTime.now(),
        ));

        _handleDisconnection();

        // Reset to idle after error delay
        Timer(const Duration(seconds: 5), () {
          updateSyncStatus(SyncStatus(
            state: SyncState.idle,
            lastSyncTime: DateTime.now(),
          ));
        });
        return; // Exit early to skip the success flow
      }

      // Reset to idle after a short delay
      Timer(const Duration(seconds: 2), () {
        updateSyncStatus(SyncStatus(
          state: SyncState.idle,
          lastSyncTime: DateTime.now(),
        ));
      });
    } catch (e) {
      Logger.error('Paginated sync failed: $e');

      // Update sync status to error
      updateSyncStatus(SyncStatus(
        state: SyncState.error,
        errorMessage: e.toString(),
        isManual: isManual,
        lastSyncTime: DateTime.now(),
      ));

      _handleDisconnection();

      // Reset to idle after error delay
      Timer(const Duration(seconds: 5), () {
        updateSyncStatus(SyncStatus(
          state: SyncState.idle,
          lastSyncTime: DateTime.now(),
        ));
      });
    }
  }

  @override
  void stopSync() {
    // Default implementation - can be overridden by platform-specific services
    Logger.debug('Base SyncService stopSync called');
  }

  /// Determines if sync completion should trigger a notification
  /// Only notify for meaningful syncs to avoid premature notifications
  void _notifySyncCompleteIfMeaningful(bool isManual, PaginatedSyncCommandResponse response) {
    // Always notify for manual syncs - user initiated these
    if (isManual) {
      Logger.debug('Notifying sync completion for manual sync at ${DateTime.now()}');
      notifySyncComplete();
      return;
    }

    // For background syncs, use the response data to determine if notification should be shown
    if (!response.hadMeaningfulSync || response.syncedDeviceCount == 0) {
      Logger.debug(
          'Skipping notification for background sync - no meaningful sync activity (devices: ${response.syncedDeviceCount}, meaningful: ${response.hadMeaningfulSync})');
      return;
    }

    // For background syncs with meaningful activity, show notification
    Logger.debug(
        'Notifying sync completion for background sync with meaningful activity (${response.syncedDeviceCount} devices synced) at ${DateTime.now()}');
    notifySyncComplete();
  }

  void notifySyncComplete() {
    Logger.debug('Notifying sync completion at ${DateTime.now()}');
    _syncCompleteController.add(true);
  }

  @override
  void dispose() {
    stopSync();
    _channel?.sink.close();
    _syncCompleteController.close();
    _progressController.close();
    _syncStatusController.close();
  }
}
