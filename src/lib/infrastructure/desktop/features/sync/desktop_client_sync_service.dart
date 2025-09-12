import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Desktop client sync service that connects to WHPH servers
class DesktopClientSyncService extends SyncService {
  WebSocketChannel? _clientChannel;
  Timer? _heartbeatTimer;
  Timer? _syncTimer;
  String? _connectedServerAddress;
  int? _connectedServerPort;
  String? _connectedServerId;
  bool _isConnected = false;
  StreamSubscription? _messageSubscription;

  static const Duration _heartbeatInterval = Duration(minutes: 2);
  static const Duration _syncInterval = Duration(minutes: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  DesktopClientSyncService(super.mediator);

  /// Connect to a WHPH server as client
  Future<bool> connectToServer(String serverAddress, int serverPort) async {
    try {
      Logger.info('🔌 Connecting to server at $serverAddress:$serverPort');

      // Clean up any existing connection
      await _cleanupConnection();

      // Connect to server
      final uri = Uri.parse('ws://$serverAddress:$serverPort');
      _clientChannel = WebSocketChannel.connect(uri);

      // Set up message handling
      final completer = Completer<bool>();
      
      _messageSubscription = _clientChannel!.stream.listen(
        (message) async {
          await _handleServerMessage(message, completer);
        },
        onError: (error) {
          Logger.error('❌ Client connection error: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          _handleConnectionError();
        },
        onDone: () {
          Logger.info('🔚 Server connection closed');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          _handleConnectionClosed();
        },
      );

      // Send initial handshake
      await _sendHandshakeRequest();

      // Wait for connection confirmation
      final connected = await completer.future.timeout(
        _connectionTimeout,
        onTimeout: () {
          Logger.warning('⏰ Connection timeout');
          return false;
        },
      );

      if (connected) {
        _connectedServerAddress = serverAddress;
        _connectedServerPort = serverPort;
        _isConnected = true;
        
        _startHeartbeat();
        Logger.info('✅ Successfully connected to server $serverAddress:$serverPort');
        
        // Start periodic sync
        await startSync();
      } else {
        await _cleanupConnection();
        Logger.warning('❌ Failed to connect to server');
      }

      return connected;
    } catch (e) {
      Logger.error('❌ Connection failed: $e');
      await _cleanupConnection();
      return false;
    }
  }

  /// Disconnect from current server
  Future<void> disconnectFromServer() async {
    Logger.info('🔌 Disconnecting from server');
    await _cleanupConnection();
    Logger.info('✅ Disconnected from server');
  }

  /// Check if connected to server
  bool get isConnectedToServer => _isConnected && _clientChannel != null;

  /// Get connected server info
  Map<String, dynamic>? get connectedServerInfo => _isConnected 
      ? {
          'address': _connectedServerAddress,
          'port': _connectedServerPort,
          'serverId': _connectedServerId,
        }
      : null;

  @override
  Future<void> startSync() async {
    if (!_isConnected) {
      Logger.warning('⚠️ Cannot start sync - not connected to server');
      return;
    }

    Logger.debug('Starting desktop client periodic sync');

    // Run initial sync
    await runSync();

    // Start periodic sync
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      try {
        Logger.debug('Running client periodic sync at ${DateTime.now()}');
        await runSync();
      } catch (e) {
        Logger.error('Periodic client sync failed: $e');
      }
    });

    Logger.debug('Started desktop client periodic sync with interval: ${_syncInterval.inMinutes} minutes');
  }

  @override
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    Logger.debug('Stopped desktop client periodic sync');
  }

  @override
  Future<void> runSync({bool isManual = false}) async {
    if (!_isConnected) {
      Logger.warning('⚠️ Cannot sync - not connected to server');
      return;
    }

    try {
      Logger.info('🔄 Starting client sync with server');
      await runPaginatedSync(isManual: isManual);
      Logger.info('✅ Client sync completed successfully');
    } catch (e) {
      Logger.error('❌ Client sync failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> runPaginatedSync({bool isManual = false}) async {
    if (!_isConnected) {
      throw Exception('Not connected to server');
    }

    try {
      Logger.info('🔄 Starting client paginated sync');
      
      // Update sync status to syncing
      updateSyncStatus(SyncStatus(
        state: SyncState.syncing,
        isManual: isManual,
        lastSyncTime: DateTime.now(),
      ));

      // Use the base implementation which calls the mediator
      await super.runPaginatedSync(isManual: isManual);

      Logger.info('✅ Client paginated sync completed');
    } catch (e) {
      Logger.error('❌ Client paginated sync failed: $e');
      rethrow;
    }
  }


  Future<void> _sendHandshakeRequest() async {
    if (_clientChannel == null) return;

    final handshake = WebSocketMessage(
      type: 'client_connect',
      data: {
        'clientId': 'desktop-client-${DateTime.now().millisecondsSinceEpoch}',
        'clientName': 'Desktop Client',
        'platform': 'desktop',
        'requestedServices': ['sync'],
        'clientCapabilities': ['paginated_sync'],
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _clientChannel!.sink.add(JsonMapper.serialize(handshake));
    Logger.debug('📤 Sent client handshake request');
  }

  Future<void> _handleServerMessage(dynamic message, Completer<bool>? connectionCompleter) async {
    try {
      final messageStr = message.toString();
      Logger.debug('📨 Received server message: $messageStr');

      final response = JsonMapper.deserialize<WebSocketMessage>(messageStr);
      if (response == null) return;

      switch (response.type) {
        case 'client_connected':
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true) {
            _connectedServerId = data['serverId'] as String?;
            Logger.info('✅ Client connected to server: ${data['serverName']}');
            connectionCompleter?.complete(true);
          } else {
            Logger.warning('❌ Server rejected client connection: ${data['message']}');
            connectionCompleter?.complete(false);
          }
          break;

        case 'test_response':
          Logger.debug('📨 Received server test response');
          break;

        case 'paginated_sync_complete':
          Logger.debug('📨 Received sync response from server');
          break;

        case 'error':
          final data = response.data as Map<String, dynamic>;
          Logger.error('❌ Server error: ${data['message']}');
          break;

        default:
          Logger.debug('📨 Unhandled message type: ${response.type}');
      }
    } catch (e) {
      Logger.error('❌ Error handling server message: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected && _clientChannel != null) {
        try {
          final heartbeat = WebSocketMessage(
            type: 'heartbeat',
            data: {
              'timestamp': DateTime.now().toIso8601String(),
              'clientId': _connectedServerId,
            },
          );
          _clientChannel!.sink.add(JsonMapper.serialize(heartbeat));
          Logger.debug('💓 Sent heartbeat to server');
        } catch (e) {
          Logger.error('❌ Failed to send heartbeat: $e');
          _handleConnectionError();
        }
      }
    });
  }

  void _handleConnectionError() {
    Logger.warning('⚠️ Connection error detected');
    _isConnected = false;
    // Could implement reconnection logic here
  }

  void _handleConnectionClosed() {
    Logger.info('🔚 Connection closed');
    _isConnected = false;
    // Could implement reconnection logic here
  }

  Future<void> _cleanupConnection() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    _syncTimer?.cancel();
    _syncTimer = null;

    await _messageSubscription?.cancel();
    _messageSubscription = null;

    try {
      await _clientChannel?.sink.close();
    } catch (e) {
      Logger.debug('Warning: Failed to close WebSocket: $e');
    }
    
    _clientChannel = null;
    _isConnected = false;
    _connectedServerAddress = null;
    _connectedServerPort = null;
    _connectedServerId = null;
  }

  @override
  void dispose() {
    _cleanupConnection();
    super.dispose();
  }
}