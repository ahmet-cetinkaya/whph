import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/commands/paginated_sync_command.dart';
import 'package:whph/src/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

import 'abstraction/i_sync_service.dart';

class SyncService implements ISyncService {
  final Mediator _mediator;

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
  Future<void> runSync() async {
    // Redirect to paginated sync - this is now the default and only sync method
    await runPaginatedSync();
  }

  /// Runs paginated sync operation - this is now the primary sync method
  @override
  Future<void> runPaginatedSync() async {
    try {
      Logger.debug('Starting paginated sync process at ${DateTime.now()}...');

      // Create paginated sync command handler and listen to progress
      final command = PaginatedSyncCommand();
      await _mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

      // Reset the attempt count on successful sync
      _reconnectAttempts = 0;

      Logger.info('✅ Paginated sync completed successfully');
      notifySyncComplete();
    } catch (e) {
      Logger.error('Paginated sync failed: $e');
      _handleDisconnection();
    }
  }

  @override
  void stopSync() {
    // Default implementation - can be overridden by platform-specific services
    Logger.debug('Base SyncService stopSync called');
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
  }
}
