import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/shared/models/websocket_request.dart';

import 'abstraction/i_sync_service.dart';

class SyncService implements ISyncService {
  final Mediator _mediator;

  final _syncCompleteController = StreamController<bool>.broadcast();
  Timer? _periodicTimer;
  WebSocketChannel? _channel;
  DateTime? _lastSyncTime;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  static const Duration _syncInterval = Duration(minutes: 1);
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  @override
  Stream<bool> get onSyncComplete => _syncCompleteController.stream;
  bool get isConnected => _isConnected;

  SyncService(this._mediator);

  void _handleDisconnection() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;

    // In case of force close, do not attempt to reconnect
    if (_lastSyncTime != null && DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 5)) {
      if (kDebugMode) debugPrint('[SyncService]: Recent sync completed, skipping reconnection');
      return;
    }

    // If maximum attempts reached or initialization is in progress
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        debugPrint('[SyncService]: Max reconnection attempts reached or initialization in progress, resetting counter');
      }
      _reconnectAttempts = 0;
      return;
    }

    // Attempt to reconnect in case of normal disconnect
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
  }

  void _forceCloseConnection() {
    if (kDebugMode) debugPrint('[SyncService]: Force closing WebSocket connection');
    if (_isConnected) {
      // Mark last sync time before closing
      _lastSyncTime = DateTime.now();

      // Send a close frame before closing
      _channel?.sink.add(
          JsonMapper.serialize(WebSocketMessage(type: 'close', data: {'timestamp': DateTime.now().toIso8601String()})));

      // Close immediately
      _channel?.sink.close();
      _channel = null;
      _isConnected = false;

      // Notify sync completion
      notifySyncComplete();
    }
  }

  @override
  Future<void> startSync() async {
    // First, clear the existing timer
    stopSync();

    // Run the initial sync
    await runSync();

    // Start periodic sync
    _periodicTimer = Timer.periodic(_syncInterval, (timer) async {
      try {
        if (kDebugMode) debugPrint('[SyncService]: Running periodic sync at ${DateTime.now()}');
        await runSync();
      } catch (e) {
        if (kDebugMode) debugPrint('ERROR: Periodic sync failed: $e');
      }
    });

    if (kDebugMode) {
      debugPrint('[SyncService]: Started periodic sync with interval: ${_syncInterval.inMinutes} minutes');
    }
  }

  @override
  Future<void> runSync() async {
    try {
      if (kDebugMode) debugPrint('[SyncService]: Starting sync process at ${DateTime.now()}...');
      await _mediator.send(SyncCommand());

      // Reset the attempt count on successful sync
      _reconnectAttempts = 0;

      // After a successful sync, wait for a sufficient time and close the connection
      Timer(const Duration(seconds: 1), () {
        if (_isConnected) {
          if (kDebugMode) debugPrint('[SyncService]: Sync completed, closing connection');
          _forceCloseConnection();
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ERROR: Sync failed: $e');
      _handleDisconnection();
    }
  }

  @override
  void stopSync() {
    if (_periodicTimer != null) {
      if (kDebugMode) debugPrint('[SyncService]: Stopping periodic sync');
      _periodicTimer!.cancel();
      _periodicTimer = null;
    }
  }

  void notifySyncComplete() {
    if (kDebugMode) debugPrint('[SyncService]: Notifying sync completion at ${DateTime.now()}');
    _syncCompleteController.add(true);
  }

  @override
  void dispose() {
    stopSync();
    _channel?.sink.close();
    _syncCompleteController.close();
  }
}
