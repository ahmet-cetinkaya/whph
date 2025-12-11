import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:flutter/foundation.dart';

const int webSocketPort = 44040;
const int defaultSyncInterval = 1800; // 30 minutes in seconds
const int maxConcurrentConnections = 10; // Maximum number of concurrent connections for security
const int maxConnectionsPerIP = 5; // Max connections per IP - increased for paginated sync (was 3)
const int connectionTimeoutSeconds = 300; // 5 minutes timeout for idle connections
const int maxMessageSizeBytes = 1024 * 1024; // 1MB max message size
const int connectionRecycleIdleSeconds = 5; // Recycle connections idle for this duration

/// Desktop server sync service that acts as WebSocket server for WHPH clients
class DesktopServerSyncService extends SyncService {
  HttpServer? _server;
  bool _isServerMode = false;
  Timer? _serverKeepAlive;
  final List<WebSocket> _activeConnections = [];
  final Map<WebSocket, String> _connectionIPs = {}; // Track client IPs for each WebSocket
  final Map<WebSocket, DateTime> _connectionTimes = {}; // Track connection start times
  final Map<WebSocket, DateTime> _connectionLastActivity = {}; // Track last activity per connection
  final Map<String, int> _ipConnectionCounts = {}; // Track connections per IP for rate limiting

  final IDeviceIdService _deviceIdService;

  DesktopServerSyncService(super.mediator, this._deviceIdService) {
    // Clean up any existing connection state at construction (fire and forget)
    _validateAndCleanConnectionState();
  }

  /// Validates and cleans up any existing connection state
  /// This prevents stale connection data from previous app instances
  Future<void> _validateAndCleanConnectionState() async {
    Logger.debug('Validating and cleaning up connection state...');

    try {
      // Clear any existing connection data that might be left from previous instances
      final activeConnectionCount = _activeConnections.length;
      final connectionIPCount = _connectionIPs.length;
      final connectionTimeCount = _connectionTimes.length;
      final connectionActivityCount = _connectionLastActivity.length;
      final ipConnectionCount = _ipConnectionCounts.length;

      if (activeConnectionCount > 0 ||
          connectionIPCount > 0 ||
          connectionTimeCount > 0 ||
          connectionActivityCount > 0 ||
          ipConnectionCount > 0) {
        Logger.warning('Found stale connection data from previous instance:');
        Logger.warning('Active connections: $activeConnectionCount');
        Logger.warning('Connection IPs: $connectionIPCount');
        Logger.warning('Connection times: $connectionTimeCount');
        Logger.warning('Connection activities: $connectionActivityCount');
        Logger.warning('IP connection counts: $ipConnectionCount');

        // Force cleanup of all stale connection data
        await _forceCleanupAllConnections();

        Logger.info('Forced cleanup of stale connection data completed');
      } else {
        Logger.debug('No stale connection data found');
      }
    } catch (e) {
      Logger.error('Error during connection state validation: $e');
      // Force cleanup regardless of errors to ensure clean state
      await _forceCleanupAllConnections();
    }
  }

  /// Forces cleanup of all connection tracking data
  /// This is used during startup validation and error recovery
  Future<void> _forceCleanupAllConnections() async {
    try {
      // Close any lingering connections properly
      final closeFutures = <Future>[];
      for (final socket in List<WebSocket>.from(_activeConnections)) {
        try {
          if (socket.readyState != WebSocket.closed && socket.readyState != WebSocket.closing) {
            closeFutures.add(socket.close(1001, 'Server cleaning up stale connections'));
          }
        } catch (e) {
          Logger.debug('Error closing stale connection: $e');
        }
      }

      // Wait for all close operations to complete (with timeout)
      if (closeFutures.isNotEmpty) {
        try {
          await Future.wait(closeFutures).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              Logger.warning('Some connections took too long to close, proceeding with cleanup');
              return [];
            },
          );
        } catch (e) {
          Logger.warning('Error during connection closure: $e');
        }
      }

      Logger.debug('All connections closed successfully');
    } catch (e) {
      Logger.error('Error during forced connection cleanup: $e');
    } finally {
      // Clear all tracking data regardless of success or failure
      _activeConnections.clear();
      _connectionIPs.clear();
      _connectionTimes.clear();
      _connectionLastActivity.clear();
      _ipConnectionCounts.clear();
    }
  }

  /// Attempt to start as WebSocket server
  Future<bool> startAsServer() async {
    try {
      Logger.info('Attempting to start desktop WebSocket server...');

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        webSocketPort,
        shared: true,
      );

      _isServerMode = true;
      _startServerKeepAlive();
      _handleServerConnections();

      Logger.info('Desktop WebSocket server started on port $webSocketPort');
      Logger.info('Desktop server listening on all IPv4 interfaces (0.0.0.0:$webSocketPort)');
      Logger.info('Ready to receive sync requests from mobile and desktop clients');

      return true;
    } catch (e) {
      Logger.warning('Failed to start desktop server: $e');
      _isServerMode = false;
      return false;
    }
  }

  void _handleServerConnections() async {
    if (_server == null) return;

    await for (HttpRequest req in _server!) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final clientIP = req.connectionInfo?.remoteAddress.address ?? '127.0.0.1';

          // Check connection limits before accepting
          if (!_canAcceptNewConnection(clientIP)) {
            // Enhanced logging for connection rejections to aid diagnostics
            Logger.warning('Connection rejected: limits exceeded from $clientIP\n'
                '  Current active connections: ${_activeConnections.length}/$maxConcurrentConnections\n'
                '  Connections from $clientIP: ${_ipConnectionCounts[clientIP] ?? 0}/$maxConnectionsPerIP');

            // Log current connection distribution for debugging
            if (_ipConnectionCounts.isNotEmpty) {
              final ipSummary = _ipConnectionCounts.entries.map((e) => '${e.key}:${e.value}').join(', ');
              Logger.debug('Active connection IPs: $ipSummary');
            }

            req.response
              ..statusCode = HttpStatus.serviceUnavailable
              ..headers.add('Retry-After', '60')
              ..write('Connection limit exceeded')
              ..close();
            continue;
          }

          // Validate IP is from private network for security
          if (!_isPrivateIP(clientIP)) {
            Logger.warning('Connection rejected: non-private IP $clientIP');
            req.response
              ..statusCode = HttpStatus.forbidden
              ..write('Only private network connections allowed')
              ..close();
            continue;
          }

          final ws = await WebSocketTransformer.upgrade(req);
          _activeConnections.add(ws);

          // Store the client IP and connection time for this WebSocket connection
          final now = DateTime.now();
          _connectionIPs[ws] = clientIP;
          _connectionTimes[ws] = now;
          _connectionLastActivity[ws] = now; // Track last activity for idle detection
          _ipConnectionCounts[clientIP] = (_ipConnectionCounts[clientIP] ?? 0) + 1;

          Logger.info(
              'Desktop server: Client connected from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort} (${_activeConnections.length}/$maxConcurrentConnections)');

          ws.listen(
            (data) async {
              Logger.debug('Desktop server received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('Desktop server connection error: $e');
              _cleanupConnection(ws);
              ws.close();
            },
            onDone: () {
              Logger.debug('Desktop server: Client disconnected');
              _cleanupConnection(ws);
            },
            cancelOnError: true,
          );
        } else {
          req.response
            ..statusCode = HttpStatus.upgradeRequired
            ..headers.add('Upgrade', 'websocket')
            ..headers.add('Connection', 'Upgrade')
            ..write('WebSocket upgrade required')
            ..close();
        }
      } catch (e) {
        Logger.error('Desktop server request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  }

  Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
    try {
      // Update last activity time for idle detection
      _connectionLastActivity[socket] = DateTime.now();

      // Validate message size
      if (message.length > maxMessageSizeBytes) {
        Logger.warning('Message rejected: size ${message.length} exceeds limit $maxMessageSizeBytes');
        _sendMessage(
            socket, WebSocketMessage(type: 'error', data: {'message': 'Message too large', 'server_type': 'desktop'}));
        return;
      }

      // Check connection timeout
      if (_isConnectionExpired(socket)) {
        Logger.warning('Connection expired, closing socket');
        await socket.close();
        return;
      }

      Logger.debug('Processing message in desktop server: $message');

      WebSocketMessage? parsedMessage;
      try {
        parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
      } catch (e) {
        Logger.warning('Invalid JSON message received: $e');
        _sendMessage(socket,
            WebSocketMessage(type: 'error', data: {'message': 'Invalid JSON format', 'server_type': 'desktop'}));
        return;
      }

      if (parsedMessage == null) {
        throw FormatException('Error parsing WebSocket message');
      }

      // Validate message structure
      if (!_isValidWebSocketMessage(parsedMessage)) {
        Logger.warning('Invalid message structure received');
        _sendMessage(socket,
            WebSocketMessage(type: 'error', data: {'message': 'Invalid message structure', 'server_type': 'desktop'}));
        return;
      }

      switch (parsedMessage.type) {
        case 'device_info':
          await _handleDeviceInfoRequest(socket);
          break;

        case 'test':
          _sendMessage(
              socket,
              WebSocketMessage(
                type: 'test_response',
                data: {
                  'success': true,
                  'timestamp': DateTime.now().toIso8601String(),
                  'server_type': 'desktop',
                  'platform': Platform.operatingSystem,
                },
              ));
          break;

        case 'client_connect':
          await _handleClientConnect(parsedMessage, socket);
          break;

        case 'heartbeat':
          await _handleHeartbeat(parsedMessage, socket);
          break;

        case 'sync':
          Logger.warning('Legacy sync endpoint called on desktop server - this is deprecated');
          WebSocketMessage deprecationMessage = WebSocketMessage(type: 'sync_deprecated', data: {
            'success': false,
            'message': 'Legacy sync is deprecated. Please use paginated_sync endpoint.',
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'desktop'
          });
          _sendMessage(socket, deprecationMessage);
          // Keep connection alive for modern sync methods
          break;

        case 'paginated_sync_start':
          Logger.info('Desktop server received paginated sync start request');
          await _handlePaginatedSyncStart(parsedMessage, socket);
          break;

        case 'paginated_sync_request':
          Logger.info('Desktop server received data page request');
          await _handlePaginatedSyncRequest(parsedMessage, socket);
          break;

        case 'paginated_sync':
          Logger.info('Desktop server processing paginated sync request...');
          final paginatedSyncData = parsedMessage.data;
          if (paginatedSyncData == null) {
            throw FormatException('Paginated sync message missing data');
          }

          Logger.debug(
              'Desktop server paginated sync data received for entity: ${(paginatedSyncData as Map<String, dynamic>)['entityType']}');

          try {
            final command =
                PaginatedSyncCommand(paginatedSyncDataDto: PaginatedSyncDataDto.fromJson(paginatedSyncData));
            final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);
            Logger.info('Desktop server paginated sync processing completed successfully');

            // For paginated sync, send the data back as paginated_sync, not paginated_sync_complete
            WebSocketMessage responseMessage = WebSocketMessage(type: 'paginated_sync', data: {
              'paginatedSyncDataDto': response.paginatedSyncDataDto?.toJson(),
              'success': true,
              'isComplete': response.isComplete,
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'desktop'
            });
            _sendMessage(socket, responseMessage, 'Desktop server paginated sync response sent to client');

            // Close connection immediately after successful response for paginated sync
            // This frees up connection slots for subsequent entity sync requests
            // Paginated sync protocol uses one connection per entity type
            await _closeSocketGracefully(socket, 1000, 'Paginated sync completed successfully');
          } catch (e, stackTrace) {
            Logger.error('Desktop server paginated sync processing failed: $e');
            Logger.error('Stack trace: $stackTrace');

            final errorData = <String, dynamic>{
              'success': false,
              'message': e.toString(),
              'type': e.runtimeType.toString(),
              'stackTrace': stackTrace.toString(),
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'desktop',
              'entityType': (parsedMessage.data as Map<String, dynamic>?)?.containsKey('entityType') == true
                  ? (parsedMessage.data as Map<String, dynamic>)['entityType']
                  : 'unknown',
            };

            WebSocketMessage errorMessage = WebSocketMessage(type: 'paginated_sync_error', data: errorData);
            _sendMessage(socket, errorMessage);

            // Close connection even after errors to prevent connection leaks
            await _closeSocketGracefully(socket, 1011, 'Paginated sync failed');
          }
          break;

        default:
          _sendMessage(socket,
              WebSocketMessage(type: 'error', data: {'message': 'Unknown message type', 'server_type': 'desktop'}));
          // Keep connection alive in case client sends valid messages later
          break;
      }
    } catch (e) {
      Logger.error('Error processing WebSocket message in desktop server: $e');
      _sendMessage(socket, WebSocketMessage(type: 'error', data: {'message': e.toString(), 'server_type': 'desktop'}));
      await socket.close();
      rethrow;
    }
  }

  Future<void> _handleDeviceInfoRequest(WebSocket socket) async {
    try {
      final response = WebSocketMessage(
        type: 'device_info_response',
        data: {
          'success': true,
          'deviceId': await _deviceIdService.getDeviceId(),
          'deviceName': await DeviceInfoHelper.getDeviceName(),
          'appName': AppInfo.shortName,
          'platform': Platform.operatingSystem,
          'capabilities': {
            'canActAsServer': true,
            'canActAsClient': true,
            'supportedModes': ['server', 'client']
          },
          'serverInfo': {
            'isServerActive': true,
            'serverPort': webSocketPort,
            'activeConnections': _activeConnections.length,
          },
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _sendMessage(socket, response, 'Sent device info response');
    } catch (e) {
      Logger.error('Failed to handle device info request: $e');
    }
  }

  Future<void> _handleClientConnect(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>;
      final clientId = data['clientId'] as String?;
      final clientName = data['clientName'] as String?;

      Logger.info('Client connecting: $clientName ($clientId)');

      final response = WebSocketMessage(
        type: 'client_connected',
        data: {
          'success': true,
          'serverId': await _deviceIdService.getDeviceId(),
          'serverName': await DeviceInfoHelper.getDeviceName(),
          'syncInterval': defaultSyncInterval, // 30 minutes
          'supportedOperations': ['paginated_sync'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _sendMessage(socket, response, 'Client connected successfully: $clientName');
    } catch (e) {
      Logger.error('Failed to handle client connect: $e');

      final errorResponse = WebSocketMessage(
        type: 'client_connected',
        data: {
          'success': false,
          'message': 'Connection failed: $e',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _sendMessage(socket, errorResponse);
    }
  }

  /// Handle paginated sync start request from client
  Future<void> _handlePaginatedSyncStart(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>?;
      if (data == null) {
        throw FormatException('paginated_sync_start message missing data');
      }

      final clientId = data['clientId'] as String?;
      final serverId = data['serverId'] as String?;

      Logger.info('Desktop server: Client ($clientId) initiated paginated sync with server ($serverId)');

      // Acknowledge the sync start and initiate the actual sync process
      final response = WebSocketMessage(
        type: 'paginated_sync_started',
        data: {
          'success': true,
          'serverId': await _deviceIdService.getDeviceId(),
          'message': 'Paginated sync session started',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _sendMessage(socket, response, 'Desktop server: Sent paginated_sync_started response');

      // Acknowledge the sync start but don't immediately push data
      // The client will request data pages as needed
      Logger.info('Desktop server: Acknowledged sync start request from client');
    } catch (e, stackTrace) {
      Logger.error('Desktop server: Failed to handle paginated_sync_start: $e');
      Logger.error('Stack trace: $stackTrace');

      final errorMessage = WebSocketMessage(
        type: 'paginated_sync_error',
        data: {
          'success': false,
          'message': 'Failed to start paginated sync: ${e.toString()}',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _sendMessage(socket, errorMessage);
    }
  }

  /// Handle paginated sync data request from client
  Future<void> _handlePaginatedSyncRequest(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>?;
      if (data == null) {
        throw FormatException('paginated_sync_request message missing data');
      }

      final entityType = data['entityType'] as String?;
      final pageIndex = data['pageIndex'] as int?;
      final pageSize = data['pageSize'] as int? ?? 50;
      final clientId = data['clientId'] as String?;

      if (entityType == null || pageIndex == null || clientId == null) {
        throw FormatException('Missing required fields: entityType, pageIndex, or clientId');
      }

      Logger.info('Desktop server: Client requested page $pageIndex of $entityType (size: $pageSize)');

      // Create a paginated sync command to get the requested data
      // Get real IP addresses from the connection context
      final deviceId = await _deviceIdService.getDeviceId();
      final serverLocalIp = _getServerLocalIp();
      final clientRemoteIp = _getClientRemoteIp(socket);

      final syncDevice = SyncDevice(
        id: deviceId,
        createdDate: DateTime.now(),
        fromIp: serverLocalIp,
        toIp: clientRemoteIp,
        fromDeviceId: deviceId,
        toDeviceId: clientId,
        name: await DeviceInfoHelper.getDeviceName(),
      );

      final requestDto = PaginatedSyncDataDto(
        appVersion: AppInfo.version,
        syncDevice: syncDevice,
        isDebugMode: kDebugMode,
        entityType: entityType,
        pageIndex: pageIndex,
        pageSize: pageSize,
        totalPages: 1, // Will be updated by the handler
        totalItems: 0, // Will be updated by the handler
        isLastPage: false, // Will be updated by the handler
      );

      final command = PaginatedSyncCommand(paginatedSyncDataDto: requestDto);
      final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

      if (response.paginatedSyncDataDto != null) {
        final populatedData = response.paginatedSyncDataDto!.getPopulatedSyncData();
        final itemCount = populatedData?.data.getTotalItemCount() ?? 0;
        Logger.info('Desktop server: Found $itemCount items for page $pageIndex of $entityType');

        final responseMessage = WebSocketMessage(
          type: 'paginated_sync',
          data: {
            'success': true,
            'paginatedSyncDataDto': response.paginatedSyncDataDto!.toJson(),
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'desktop'
          },
        );

        _sendMessage(socket, responseMessage, 'Desktop server: Sent page $pageIndex data to client');
      } else {
        Logger.info('Desktop server: No data found for page $pageIndex of $entityType');

        final emptyResponseMessage = WebSocketMessage(
          type: 'paginated_sync_complete',
          data: {
            'success': true,
            'paginatedSyncDataDto': null,
            'isComplete': true,
            'message': 'No data available for requested page',
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'desktop'
          },
        );

        _sendMessage(socket, emptyResponseMessage, 'Desktop server: Sent empty response for page $pageIndex');
      }
    } catch (e, stackTrace) {
      Logger.error('Desktop server: Failed to handle paginated_sync_request: $e');
      Logger.error('Stack trace: $stackTrace');

      final errorMessage = WebSocketMessage(
        type: 'paginated_sync_error',
        data: {
          'success': false,
          'message': 'Failed to process data request: ${e.toString()}',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _sendMessage(socket, errorMessage);
    }
  }

  Future<void> _handleHeartbeat(WebSocketMessage message, WebSocket socket) async {
    try {
      Logger.debug('Received heartbeat from client');

      final response = WebSocketMessage(
        type: 'heartbeat_response',
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'serverStatus': 'healthy',
        },
      );

      _sendMessage(socket, response);
    } catch (e) {
      Logger.error('Failed to handle heartbeat: $e');
    }
  }

  void _startServerKeepAlive() {
    _serverKeepAlive = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_server != null && _isServerMode) {
        Logger.debug('Desktop server heartbeat - Active connections: ${_activeConnections.length}');

        // Proactively recycle idle connections to free slots
        _recycleIdleConnections();

        // Clean up closed connections and expired connections
        final closedConnections =
            _activeConnections.where((ws) => ws.readyState == WebSocket.closed || _isConnectionExpired(ws)).toList();
        for (final ws in closedConnections) {
          if (_isConnectionExpired(ws)) {
            Logger.debug('Closing expired connection');
            ws.close();
          }
          _cleanupConnection(ws);
        }

        // Log server health for debugging
        if (_activeConnections.isEmpty) {
          Logger.debug('Desktop server running in background, waiting for connections...');
        } else {
          Logger.debug('Desktop server actively serving ${_activeConnections.length} client(s)');
        }
      }
    });
  }

  @override
  Future<void> stopSync() async {
    await stopServer();
    super.stopSync();
  }

  Future<void> stopServer() async {
    if (_isServerMode) {
      Logger.info('Stopping desktop WebSocket server...');

      _serverKeepAlive?.cancel();
      _serverKeepAlive = null;

      // Enhanced cleanup: ensure all connections are properly closed and cleaned up
      await _forceCloseAllConnections();

      // Close the server
      try {
        await _server?.close();
        Logger.debug('Server socket closed successfully');
      } catch (e) {
        Logger.warning('Error closing server socket: $e');
      }
      _server = null;
      _isServerMode = false;

      // Final validation to ensure clean state
      await _validateCleanShutdown();

      Logger.info('Desktop WebSocket server stopped with enhanced cleanup');
    }
  }

  /// Forces closure of all active connections with enhanced error handling
  Future<void> _forceCloseAllConnections() async {
    final connectionsToClose = List<WebSocket>.from(_activeConnections);

    if (connectionsToClose.isEmpty) {
      Logger.debug('No active connections to close');
      return;
    }

    Logger.info('Force closing ${connectionsToClose.length} active connections...');

    // Close all connections concurrently with timeout
    final futures = connectionsToClose.map((ws) async {
      try {
        if (ws.readyState != WebSocket.closed && ws.readyState != WebSocket.closing) {
          await ws.close(1001, 'Server shutting down').timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              Logger.warning('Connection close timeout, forcing closure');
              return ws.close();
            },
          );
        }
      } catch (e) {
        Logger.warning('Error closing connection: $e');
      } finally {
        // Always cleanup tracking data, even if close fails
        _cleanupConnection(ws);
      }
    });

    // Wait for all connections to close (with timeout)
    try {
      await Future.wait(futures).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Logger.warning('Some connections took too long to close, proceeding with cleanup');
          return []; // Return empty list to satisfy the Future.wait return type
        },
      );
    } catch (e) {
      Logger.warning('Error during connection closure: $e');
    }

    // Force cleanup any remaining tracking data
    await _forceCleanupAllConnections();

    Logger.debug('All connections force-closed');
  }

  /// Validates that the server has shut down cleanly
  Future<void> _validateCleanShutdown() async {
    try {
      final remainingConnections = _activeConnections.length;
      final remainingIPs = _connectionIPs.length;
      final remainingTimes = _connectionTimes.length;
      final remainingActivities = _connectionLastActivity.length;
      final remainingIPCounts = _ipConnectionCounts.length;

      if (remainingConnections > 0 ||
          remainingIPs > 0 ||
          remainingTimes > 0 ||
          remainingActivities > 0 ||
          remainingIPCounts > 0) {
        Logger.warning('Server shutdown validation found remaining tracking data:');
        Logger.warning('Connections: $remainingConnections');
        Logger.warning('IPs: $remainingIPs');
        Logger.warning('Times: $remainingTimes');
        Logger.warning('Activities: $remainingActivities');
        Logger.warning('IP counts: $remainingIPCounts');

        // Force cleanup one more time
        await _forceCleanupAllConnections();
        Logger.info('Performed final cleanup after shutdown validation');
      } else {
        Logger.debug('Server shutdown validation passed - clean state confirmed');
      }
    } catch (e) {
      Logger.error('Error during shutdown validation: $e');
      // Ensure cleanup even if validation fails
      await _forceCleanupAllConnections();
    }
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }

  bool get isServerMode => _isServerMode;
  int get activeConnectionCount => _activeConnections.length;

  /// Check if the server is running and healthy
  bool get isServerHealthy => _isServerMode && _server != null;

  /// Helper method to send WebSocket messages and handle serialization
  void _sendMessage(WebSocket socket, WebSocketMessage message, [String? logMessage]) {
    socket.add(JsonMapper.serialize(message));
    if (logMessage != null) {
      Logger.debug(logMessage);
    }
  }

  /// Get the server's local IP address from the bound server
  String _getServerLocalIp() {
    try {
      // Get the server's bound address - this is the local IP the server is listening on
      final serverAddress = _server?.address;
      if (serverAddress != null) {
        // If server is bound to anyIPv4 (0.0.0.0), we need to get the actual local IP
        if (serverAddress.address == '0.0.0.0') {
          // For simplicity, return localhost - in production this could be enhanced
          // to get the actual network interface IP
          return '127.0.0.1';
        }
        return serverAddress.address;
      }
    } catch (e) {
      Logger.debug('Could not determine server local IP: $e');
    }
    return '127.0.0.1'; // Fallback to localhost
  }

  /// Get the client's remote IP address from the WebSocket connection
  String _getClientRemoteIp(WebSocket socket) {
    try {
      // Get the stored IP for this WebSocket connection
      final clientIP = _connectionIPs[socket];
      if (clientIP != null) {
        return clientIP;
      }
    } catch (e) {
      Logger.debug('Could not determine client remote IP: $e');
    }
    return '127.0.0.1'; // Fallback to localhost
  }

  /// Check if a new connection can be accepted based on limits
  ///
  /// Implements defensive rate limiting with two constraints:
  /// 1. Total concurrent connections (prevents server overload)
  /// 2. Per-IP connections (prevents single client from exhausting pool)
  ///
  /// Returns false if either limit is exceeded, true otherwise
  bool _canAcceptNewConnection(String clientIP) {
    // Validate input
    if (clientIP.isEmpty) {
      Logger.warning('Invalid empty client IP in connection check');
      return false;
    }

    // Check total connection limit
    if (_activeConnections.length >= maxConcurrentConnections) {
      Logger.debug('Connection pool at capacity: ${_activeConnections.length}/$maxConcurrentConnections');
      return false;
    }

    // Check per-IP connection limit
    // Increased from 3 to 5 to accommodate paginated sync sequential requests
    final ipConnections = _ipConnectionCounts[clientIP] ?? 0;
    if (ipConnections >= maxConnectionsPerIP) {
      Logger.debug('IP $clientIP at connection limit: $ipConnections/$maxConnectionsPerIP');
      return false;
    }

    return true;
  }

  /// Check if an IP address is from a private network
  bool _isPrivateIP(String ip) {
    try {
      final address = InternetAddress(ip);

      // Check for private IPv4 ranges
      if (address.type == InternetAddressType.IPv4) {
        final parts = ip.split('.');
        if (parts.length != 4) return false;

        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);

        if (first == null || second == null) return false;

        // 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8
        return (first == 10) ||
            (first == 172 && second >= 16 && second <= 31) ||
            (first == 192 && second == 168) ||
            (first == 127);
      }

      // Check for private IPv6 ranges
      if (address.type == InternetAddressType.IPv6) {
        // fe80::/10 (link-local), ::1 (localhost), fc00::/7 (unique local)
        return ip.startsWith('fe80:') || ip == '::1' || ip.startsWith('fc') || ip.startsWith('fd');
      }
    } catch (e) {
      Logger.debug('Error parsing IP address $ip: $e');
      return false;
    }

    return false;
  }

  /// Check if a connection has exceeded the timeout
  bool _isConnectionExpired(WebSocket socket) {
    final connectionTime = _connectionTimes[socket];
    if (connectionTime == null) return false;

    final elapsed = DateTime.now().difference(connectionTime);
    return elapsed.inSeconds > connectionTimeoutSeconds;
  }

  /// Proactively recycle idle connections to prevent pool exhaustion
  ///
  /// This method addresses the core issue where paginated sync creates many
  /// short-lived connections that linger after completing their work.
  /// By aggressively closing idle connections, we free up slots for new requests.
  ///
  /// Defensive programming notes:
  /// - Uses snapshot of connections to avoid modification during iteration
  /// - Validates connection state before closing
  /// - Handles errors gracefully without disrupting other connections
  /// - Always cleans up tracking data even if close fails
  void _recycleIdleConnections() {
    if (_activeConnections.isEmpty) {
      return; // Early exit if no connections to recycle
    }

    final now = DateTime.now();
    final connectionsToRecycle = <WebSocket>[];

    try {
      // Create snapshot to avoid concurrent modification
      final connectionSnapshot = List<WebSocket>.from(_activeConnections);

      for (final socket in connectionSnapshot) {
        try {
          // Skip if socket is already closed or closing
          if (socket.readyState == WebSocket.closed || socket.readyState == WebSocket.closing) {
            continue;
          }

          // Check idle time since last activity (more accurate than connection time)
          final lastActivity = _connectionLastActivity[socket];
          if (lastActivity == null) {
            // Missing activity timestamp is suspicious - mark for cleanup
            Logger.debug('Connection missing activity timestamp, marking for recycling');
            connectionsToRecycle.add(socket);
            continue;
          }

          final idleTime = now.difference(lastActivity);

          // Recycle connections idle for more than configured threshold
          // This is safe for paginated sync which completes quickly (<2s per entity)
          if (idleTime.inSeconds > connectionRecycleIdleSeconds) {
            Logger.debug(
                'Recycling idle connection (idle: ${idleTime.inSeconds}s, threshold: ${connectionRecycleIdleSeconds}s)');
            connectionsToRecycle.add(socket);
          }
        } catch (e) {
          // Defensive: Don't let error in one connection affect others
          Logger.debug('Error checking connection for recycling: $e');
        }
      }

      // Close and cleanup identified connections
      if (connectionsToRecycle.isNotEmpty) {
        Logger.debug('Recycling ${connectionsToRecycle.length} idle connection(s)');

        for (final socket in connectionsToRecycle) {
          try {
            socket.close(1000, 'Connection recycled due to inactivity');
            _cleanupConnection(socket);
          } catch (e) {
            // Defensive: Ensure cleanup even if close fails
            Logger.debug('Error closing connection during recycling: $e');
            _cleanupConnection(socket); // Still cleanup tracking data
          }
        }
      }
    } catch (e) {
      // Outer defensive catch: Don't let recycling errors crash the server
      Logger.warning('Error during connection recycling: $e');
    }
  }

  /// Validate WebSocket message structure
  bool _isValidWebSocketMessage(WebSocketMessage message) {
    // Check required fields
    if (message.type.isEmpty) return false;

    // Check for known message types
    const validTypes = {
      'device_info',
      'test',
      'client_connect',
      'heartbeat',
      'sync',
      'paginated_sync_start',
      'paginated_sync_request',
      'paginated_sync'
    };

    if (!validTypes.contains(message.type)) {
      Logger.debug('Unknown message type: ${message.type}');
      return false;
    }

    return true;
  }

  /// Clean up connection tracking data
  ///
  /// Defensive cleanup that ensures all connection tracking data is removed
  /// even if some operations fail. Uses defensive programming to prevent leaks.
  void _cleanupConnection(WebSocket socket) {
    try {
      final clientIP = _connectionIPs[socket];

      // Remove from all tracking structures
      // Each operation is independent to ensure partial cleanup on errors
      _activeConnections.remove(socket);
      _connectionIPs.remove(socket);
      _connectionTimes.remove(socket);
      _connectionLastActivity.remove(socket);

      // Decrement IP connection count with validation
      if (clientIP != null && clientIP.isNotEmpty) {
        final currentCount = _ipConnectionCounts[clientIP] ?? 0;

        // Defensive: Validate count is positive before decrementing
        if (currentCount > 1) {
          _ipConnectionCounts[clientIP] = currentCount - 1;
        } else if (currentCount == 1) {
          _ipConnectionCounts.remove(clientIP);
        } else {
          // Defensive: Log if count is already 0 or negative (shouldn't happen)
          Logger.warning('Attempted to decrement IP count for $clientIP but count was $currentCount');
        }
      }
    } catch (e) {
      // Defensive: Log error but don't throw - cleanup must always succeed
      Logger.warning('Error during connection cleanup: $e');
    }
  }

  /// Gracefully close a WebSocket connection with proper cleanup and error handling
  ///
  /// This method ensures connection resources are freed immediately to prevent pool exhaustion.
  /// Uses defensive programming to handle edge cases and prevent connection leaks.
  ///
  /// Parameters:
  /// - socket: The WebSocket to close
  /// - code: WebSocket close code (1000 = normal, 1011 = server error)
  /// - reason: Human-readable reason for closure
  Future<void> _closeSocketGracefully(WebSocket socket, int code, String reason) async {
    try {
      // Validate socket state before attempting to close
      if (socket.readyState == WebSocket.closed || socket.readyState == WebSocket.closing) {
        Logger.debug('Socket already closed or closing, skipping graceful close');
        _cleanupConnection(socket);
        return;
      }

      Logger.debug('Closing socket gracefully: $reason (code: $code)');

      // WORKAROUND: Add brief delay to prevent race condition where close() is called
      // before the add() operation completes sending data over the wire.
      // The dart:io WebSocket implementation does not expose a flush() method or
      // a way to await send completion. This delay ensures pending messages in the
      // send buffer are transmitted before the socket is closed.
      // Under high load or slow networks, this may not always be sufficient, but
      // it significantly reduces the likelihood of premature closure.
      await Future.delayed(const Duration(milliseconds: 100));

      // Attempt to close with proper WebSocket close code
      await socket.close(code, reason).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          Logger.warning('Socket close timed out, forcing closure');
          // Force close if graceful close hangs
          return socket.close();
        },
      );

      Logger.debug('Socket closed successfully');
    } catch (e) {
      // Defensive: Log but don't throw - connection cleanup must always succeed
      Logger.warning('Error during graceful socket close: $e');

      // Attempt force close as fallback
      try {
        await socket.close();
      } catch (forceCloseError) {
        Logger.debug('Could not force close socket: $forceCloseError');
      }
    } finally {
      // Always cleanup tracking data, even if close fails
      // This prevents connection leaks in error scenarios
      _cleanupConnection(socket);
    }
  }
}
