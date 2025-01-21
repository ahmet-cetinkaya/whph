import 'dart:async';
import 'dart:convert';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/application/shared/models/websocket_request.dart';
import 'package:whph/presentation/shared/utils/network_utils.dart';

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
  static const Duration _reconnectDelay = Duration(seconds: 5);
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  bool _isInitializing = false;

  @override
  Stream<bool> get onSyncComplete => _syncCompleteController.stream;
  bool get isConnected => _isConnected;

  SyncService(this._mediator) {
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    // If already connected or initialization is in progress, exit
    if (_isConnected || _isInitializing || _reconnectAttempts >= _maxReconnectAttempts) return;

    _isInitializing = true;

    try {
      // Check existing sync devices to get the IP to connect to
      var syncDevices = await _mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(
          GetListSyncDevicesQuery(pageIndex: 0, pageSize: 10));
      var targetIp = syncDevices.items.isNotEmpty ? syncDevices.items.first.fromIp : null;

      if (targetIp != null) {
        if (kDebugMode) {
          print('DEBUG: Attempting to connect to WebSocket at ws://$targetIp:4040 (Attempt ${_reconnectAttempts + 1})');
        }

        bool canConnect = await NetworkUtils.testWebSocketConnection(
          targetIp,
          timeout: const Duration(seconds: 5),
        );

        if (!canConnect) {
          if (kDebugMode) print('DEBUG: No WebSocket server available at ws://$targetIp:4040');
          _handleDisconnection();
          return;
        }

        _channel?.sink.close();
        _channel = WebSocketChannel.connect(Uri.parse('ws://$targetIp:4040'));

        _channel!.stream.listen(
          (message) {
            _isConnected = true;
            _reconnectAttempts = 0;
            _handleWebSocketMessage(message);
          },
          onError: (error) {
            if (kDebugMode) print('ERROR: WebSocket error: $error');
            _handleDisconnection();
          },
          onDone: () {
            if (kDebugMode) print('DEBUG: WebSocket connection closed');
            _handleDisconnection();
          },
          cancelOnError: false,
        );

        _isConnected = true;
        _reconnectAttempts = 0; // Reset the attempt count on successful connection
        if (kDebugMode) print('DEBUG: WebSocket connected successfully');
      } else {
        if (kDebugMode) print('DEBUG: No sync devices found to connect to');
        return;
      }
    } catch (e) {
      if (kDebugMode) print('ERROR: WebSocket connection error: $e');
      _handleDisconnection();
    } finally {
      _isInitializing = false;
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;

    // In case of force close, do not attempt to reconnect
    if (_lastSyncTime != null && DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 5)) {
      if (kDebugMode) print('DEBUG: Recent sync completed, skipping reconnection');
      return;
    }

    // If maximum attempts reached or initialization is in progress
    if (_reconnectAttempts >= _maxReconnectAttempts || _isInitializing) {
      if (kDebugMode) {
        print('DEBUG: Max reconnection attempts reached or initialization in progress, resetting counter');
      }
      _reconnectAttempts = 0;
      return;
    }

    // Attempt to reconnect in case of normal disconnect
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, _initializeWebSocket);
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      if (kDebugMode) print('DEBUG: Processing WebSocket message');
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'sync':
          if (kDebugMode) print('DEBUG: Received sync data message');
          _processSyncData(data['data']);

          if (_channel != null && _isConnected) {
            if (kDebugMode) print('DEBUG: Sending sync_complete response');
            _channel!.sink.add(JsonMapper.serialize(WebSocketMessage(
                type: 'sync_complete', data: {'success': true, 'timestamp': DateTime.now().toIso8601String()})));
          }
          break;

        case 'sync_complete':
          if (kDebugMode) print('DEBUG: Received sync_complete message');
          if (data['data']?['success'] == true) {
            if (kDebugMode) print('DEBUG: Processing sync complete');
            _processSyncComplete(data['data']);
          }
          break;

        default:
          if (kDebugMode) print('WARNING: Unknown message type: ${data['type']}');
          break;
      }
    } catch (e, stack) {
      if (kDebugMode) print('ERROR: Failed to process WebSocket message: $e');
      if (kDebugMode) print('ERROR: Stack trace: $stack');
      _forceCloseConnection();
    }
  }

  void _forceCloseConnection() {
    if (kDebugMode) print('DEBUG: Force closing WebSocket connection');
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

  void _processSyncData(Map<String, dynamic> data) {
    try {
      if (data['syncDevice']?['lastSyncDate'] != null) {
        // Update last sync time but don't notify completion yet
        _lastSyncTime = DateTime.parse(data['syncDevice']['lastSyncDate']);
        if (kDebugMode) print('DEBUG: Updated last sync time to: $_lastSyncTime');
      }
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to process sync data: $e');
    }
  }

  void _processSyncComplete(Map<String, dynamic> data) {
    try {
      if (data['syncDataDto']?['syncDevice']?['lastSyncDate'] != null) {
        _lastSyncTime = DateTime.parse(data['syncDataDto']['syncDevice']['lastSyncDate']);
      } else {
        _lastSyncTime = DateTime.now();
      }

      if (kDebugMode) print('DEBUG: Sync completed at: $_lastSyncTime');
      _scheduleNextSync();
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to process sync complete: $e');
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
        if (kDebugMode) print('DEBUG: Running periodic sync at ${DateTime.now()}');
        await runSync();
      } catch (e) {
        if (kDebugMode) print('ERROR: Periodic sync failed: $e');
      }
    });

    if (kDebugMode) print('DEBUG: Started periodic sync with interval: ${_syncInterval.inMinutes} minutes');
  }

  @override
  Future<void> runSync() async {
    try {
      if (!_isConnected) {
        if (kDebugMode) print('DEBUG: Attempting to reconnect before sync...');
        await _initializeWebSocket();

        if (!_isConnected) {
          if (kDebugMode) print('DEBUG: Could not establish WebSocket connection, skipping sync');
          return;
        }
      }

      if (kDebugMode) print('DEBUG: Starting sync process at ${DateTime.now()}...');
      await _mediator.send(SyncCommand());

      // Reset the attempt count on successful sync
      _reconnectAttempts = 0;

      // After a successful sync, wait for a sufficient time and close the connection
      Timer(const Duration(seconds: 1), () {
        if (_isConnected) {
          if (kDebugMode) print('DEBUG: Sync completed, closing connection');
          _forceCloseConnection();
        }
      });
    } catch (e) {
      if (kDebugMode) print('ERROR: Sync failed: $e');
      _handleDisconnection();
    }
  }

  @override
  void stopSync() {
    if (_periodicTimer != null) {
      if (kDebugMode) print('DEBUG: Stopping periodic sync');
      _periodicTimer!.cancel();
      _periodicTimer = null;
    }
  }

  void _scheduleNextSync() {
    // Simplify this method to just update the last sync time
    if (_lastSyncTime != null) {
      if (kDebugMode) print('DEBUG: Last sync time updated to: $_lastSyncTime');
    }
  }

  void notifySyncComplete() {
    if (kDebugMode) print('DEBUG: Notifying sync completion at ${DateTime.now()}');
    _syncCompleteController.add(true);
  }

  @override
  void dispose() {
    stopSync();
    _channel?.sink.close();
    _syncCompleteController.close();
  }
}
