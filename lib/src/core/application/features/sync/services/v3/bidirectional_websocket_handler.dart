import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:whph/src/core/application/features/sync/models/v3/bidirectional_sync_message.dart';
import 'package:whph/src/core/application/features/sync/services/v3/bidirectional_sync_engine.dart';
import 'package:whph/src/core/application/features/sync/registry/sync_entity_registry.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// Bidirectional WebSocket Handler - manages persistent connections for both sides
class BidirectionalWebSocketHandler {
  final BidirectionalSyncEngine _syncEngine;
  final int port;
  
  HttpServer? _server;
  final Map<String, WebSocket> _activeConnections = {};
  final StreamController<String> _connectionEvents = StreamController.broadcast();
  
  bool get isServerRunning => _server != null;
  int get activeConnectionCount => _activeConnections.length;

  BidirectionalWebSocketHandler({
    required SyncEntityRegistry registry,
    this.port = 44041,
  }) : _syncEngine = BidirectionalSyncEngine(registry) {
    print('🔧 DEBUG: BidirectionalWebSocketHandler constructor called');
    
    // Listen to outgoing messages from sync engine
    _syncEngine.outgoingMessages.listen(_sendMessageToAll);
    
    // Listen to session updates
    _syncEngine.sessionUpdates.listen((session) {
      Logger.debug('🌐 BidirectionalWebSocketHandler: Session update - ${session.toString()}');
    });
  }

  /// Start WebSocket server (for Desktop)
  Future<void> startServer() async {
    print('🔧 DEBUG: BidirectionalWebSocketHandler.startServer() called');
    if (_server != null) {
      print('🔧 DEBUG: Server already running on port $port');
      Logger.warning('🌐 BidirectionalWebSocketHandler: Server already running on port $port');
      return;
    }

    try {
      print('🔧 DEBUG: Binding HTTP server to port $port...');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('🔧 DEBUG: HTTP server bound successfully!');
      Logger.info('🌐 BidirectionalWebSocketHandler: Server started on port $port');
      
      _server!.listen(_handleHttpRequest);
      
      Logger.info('🌐 BidirectionalWebSocketHandler: Ready for bidirectional sync connections');
      
    } catch (e, stackTrace) {
      Logger.error('🌐 BidirectionalWebSocketHandler: Failed to start server: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Connect as client (for Android)
  Future<WebSocket> connectAsClient(String serverAddress) async {
    final uri = Uri.parse('ws://$serverAddress:$port');
    Logger.info('🌐 BidirectionalWebSocketHandler: Connecting to $uri as client');

    try {
      final webSocket = await WebSocket.connect(uri.toString());
      final connectionId = 'client_${DateTime.now().millisecondsSinceEpoch}';
      
      _activeConnections[connectionId] = webSocket;
      _setupWebSocketListeners(webSocket, connectionId, isClient: true);
      
      Logger.info('🌐 BidirectionalWebSocketHandler: Connected as client to $serverAddress');
      _connectionEvents.add('client_connected:$serverAddress');
      
      return webSocket;
      
    } catch (e, stackTrace) {
      Logger.error('🌐 BidirectionalWebSocketHandler: Failed to connect as client: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Handle HTTP requests and upgrade to WebSocket
  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      _handleWebSocketUpgrade(request);
    } else {
      // Return simple info for non-WebSocket requests
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'service': 'WHPH Bidirectional Sync Server',
          'version': '3.0',
          'activeConnections': activeConnectionCount,
          'timestamp': DateTime.now().toIso8601String(),
        }))
        ..close();
    }
  }

  /// Handle WebSocket upgrade
  void _handleWebSocketUpgrade(HttpRequest request) async {
    try {
      final webSocket = await WebSocketTransformer.upgrade(request);
      final connectionId = 'server_${DateTime.now().millisecondsSinceEpoch}';
      final clientAddress = request.connectionInfo?.remoteAddress.address ?? 'unknown';
      
      _activeConnections[connectionId] = webSocket;
      _setupWebSocketListeners(webSocket, connectionId, isClient: false);
      
      Logger.info('🌐 BidirectionalWebSocketHandler: New connection from $clientAddress (id: $connectionId)');
      _connectionEvents.add('server_connection:$clientAddress');
      
    } catch (e, stackTrace) {
      Logger.error('🌐 BidirectionalWebSocketHandler: WebSocket upgrade failed: $e');
      Logger.error('StackTrace: $stackTrace');
    }
  }

  /// Setup WebSocket event listeners
  void _setupWebSocketListeners(WebSocket webSocket, String connectionId, {required bool isClient}) {
    final role = isClient ? 'CLIENT' : 'SERVER';
    
    webSocket.listen(
      (data) => _handleIncomingMessage(data, connectionId, role),
      onError: (error) => _handleConnectionError(error, connectionId, role),
      onDone: () => _handleConnectionClosed(connectionId, role),
    );
  }

  /// Handle incoming WebSocket message
  void _handleIncomingMessage(dynamic data, String connectionId, String role) async {
    try {
      final jsonData = jsonDecode(data as String) as Map<String, dynamic>;
      Logger.debug('🌐 BidirectionalWebSocketHandler: [$role] Received message from $connectionId');
      
      // Parse as bidirectional sync message
      final message = BidirectionalSyncMessage.fromJson(jsonData);
      
      // Process through sync engine
      await _syncEngine.processIncomingMessage(message);
      
    } catch (e, stackTrace) {
      Logger.error('🌐 BidirectionalWebSocketHandler: [$role] Error processing message from $connectionId: $e');
      Logger.error('StackTrace: $stackTrace');
    }
  }

  /// Handle connection error
  void _handleConnectionError(dynamic error, String connectionId, String role) {
    Logger.error('🌐 BidirectionalWebSocketHandler: [$role] Connection error for $connectionId: $error');
    _removeConnection(connectionId);
  }

  /// Handle connection closed
  void _handleConnectionClosed(String connectionId, String role) {
    Logger.info('🌐 BidirectionalWebSocketHandler: [$role] Connection $connectionId closed');
    _removeConnection(connectionId);
  }

  /// Remove connection from active list
  void _removeConnection(String connectionId) {
    _activeConnections.remove(connectionId);
    _connectionEvents.add('connection_closed:$connectionId');
  }

  /// Send message to all active connections
  void _sendMessageToAll(BidirectionalSyncMessage message) {
    if (_activeConnections.isEmpty) {
      Logger.warning('🌐 BidirectionalWebSocketHandler: No active connections to send message');
      return;
    }

    final jsonMessage = jsonEncode(message.toJson());
    final connectionsToRemove = <String>[];

    for (final entry in _activeConnections.entries) {
      final connectionId = entry.key;
      final webSocket = entry.value;

      try {
        if (webSocket.readyState == WebSocket.open) {
          webSocket.add(jsonMessage);
          Logger.debug('🌐 BidirectionalWebSocketHandler: Sent ${message.phase.value} message to $connectionId');
        } else {
          Logger.warning('🌐 BidirectionalWebSocketHandler: Connection $connectionId is not open (state: ${webSocket.readyState})');
          connectionsToRemove.add(connectionId);
        }
      } catch (e) {
        Logger.error('🌐 BidirectionalWebSocketHandler: Failed to send message to $connectionId: $e');
        connectionsToRemove.add(connectionId);
      }
    }

    // Clean up dead connections
    for (final connectionId in connectionsToRemove) {
      _removeConnection(connectionId);
    }
  }


  /// Start bidirectional sync (as initiator)
  Future<String> startBidirectionalSync({
    required String remoteDeviceId,
    required Map<String, dynamic> syncDeviceData,
    required DateTime lastSyncDate,
  }) async {
    Logger.info('🌐 BidirectionalWebSocketHandler: Starting bidirectional sync');

    if (_activeConnections.isEmpty) {
      throw Exception('No active connections available for sync');
    }

    // Create sync device from data
    // TODO: Proper SyncDevice construction
    final syncDevice = _createSyncDeviceFromData(syncDeviceData);

    // Initiate sync through engine
    final sessionId = await _syncEngine.initiateBidirectionalSync(
      syncDevice: syncDevice,
      remoteDeviceId: remoteDeviceId,
      lastSyncDate: lastSyncDate,
    );

    return sessionId;
  }

  /// Create SyncDevice from data (placeholder)
  dynamic _createSyncDeviceFromData(Map<String, dynamic> data) {
    // TODO: Implement proper SyncDevice construction
    // For now, return a mock object
    return data;
  }

  /// Get connection events stream
  Stream<String> get connectionEvents => _connectionEvents.stream;

  /// Get active connection IDs
  List<String> get activeConnectionIds => _activeConnections.keys.toList();

  /// Stop server and close all connections
  Future<void> stop() async {
    Logger.info('🌐 BidirectionalWebSocketHandler: Stopping server and closing connections');

    // Close all active connections
    for (final webSocket in _activeConnections.values) {
      try {
        await webSocket.close();
      } catch (e) {
        Logger.error('🌐 BidirectionalWebSocketHandler: Error closing connection: $e');
      }
    }
    _activeConnections.clear();

    // Stop server
    if (_server != null) {
      await _server!.close();
      _server = null;
      Logger.info('🌐 BidirectionalWebSocketHandler: Server stopped');
    }

    // Dispose sync engine
    await _syncEngine.dispose();
    
    // Close event streams
    await _connectionEvents.close();
  }

  /// Get handler status summary
  String get statusSummary {
    return '''
🌐 BidirectionalWebSocketHandler Status:
  Server running: $isServerRunning
  Port: $port
  Active connections: $activeConnectionCount
  Sync engine: ${_syncEngine.toString()}
''';
  }

  @override
  String toString() => 'BidirectionalWebSocketHandler(port: $port, connections: $activeConnectionCount, server: $isServerRunning)';
}