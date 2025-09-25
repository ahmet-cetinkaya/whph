import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:flutter/foundation.dart';

const int webSocketPort = 44040;
const int defaultSyncInterval = 1800; // 30 minutes in seconds
const int maxConcurrentConnections = 10; // Maximum number of concurrent connections for security
const int connectionTimeoutSeconds = 300; // 5 minutes timeout for idle connections
const int maxMessageSizeBytes = 1024 * 1024; // 1MB max message size

/// Desktop server sync service that acts as WebSocket server for WHPH clients
class DesktopServerSyncService extends SyncService {
  HttpServer? _server;
  bool _isServerMode = false;
  Timer? _serverKeepAlive;
  final List<WebSocket> _activeConnections = [];
  final Map<WebSocket, String> _connectionIPs = {}; // Track client IPs for each WebSocket
  final Map<WebSocket, DateTime> _connectionTimes = {}; // Track connection start times
  final Map<String, int> _ipConnectionCounts = {}; // Track connections per IP for rate limiting

  final IDeviceIdService _deviceIdService;

  DesktopServerSyncService(super.mediator, this._deviceIdService);

  /// Attempt to start as WebSocket server
  Future<bool> startAsServer() async {
    try {
      Logger.info('🚀 Attempting to start desktop WebSocket server...');

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        webSocketPort,
        shared: true,
      );

      _isServerMode = true;
      _startServerKeepAlive();
      _handleServerConnections();

      Logger.info('✅ Desktop WebSocket server started on port $webSocketPort');
      Logger.info('🌐 Desktop server listening on all IPv4 interfaces (0.0.0.0:$webSocketPort)');
      Logger.info('🖥️ Ready to receive sync requests from mobile and desktop clients');

      return true;
    } catch (e) {
      Logger.warning('❌ Failed to start desktop server: $e');
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
            Logger.warning('🚫 Connection rejected: limits exceeded from $clientIP');
            req.response
              ..statusCode = HttpStatus.serviceUnavailable
              ..headers.add('Retry-After', '60')
              ..write('Connection limit exceeded')
              ..close();
            continue;
          }

          // Validate IP is from private network for security
          if (!_isPrivateIP(clientIP)) {
            Logger.warning('🚫 Connection rejected: non-private IP $clientIP');
            req.response
              ..statusCode = HttpStatus.forbidden
              ..write('Only private network connections allowed')
              ..close();
            continue;
          }

          final ws = await WebSocketTransformer.upgrade(req);
          _activeConnections.add(ws);

          // Store the client IP and connection time for this WebSocket connection
          _connectionIPs[ws] = clientIP;
          _connectionTimes[ws] = DateTime.now();
          _ipConnectionCounts[clientIP] = (_ipConnectionCounts[clientIP] ?? 0) + 1;

          Logger.info(
              '🖥️ Desktop server: Client connected from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort} (${_activeConnections.length}/$maxConcurrentConnections)');

          ws.listen(
            (data) async {
              Logger.debug('📨 Desktop server received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('❌ Desktop server connection error: $e');
              _cleanupConnection(ws);
              ws.close();
            },
            onDone: () {
              Logger.debug('🔚 Desktop server: Client disconnected');
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
        Logger.error('⚠️ Desktop server request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  }

  Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
    try {
      // Validate message size
      if (message.length > maxMessageSizeBytes) {
        Logger.warning('🚫 Message rejected: size ${message.length} exceeds limit $maxMessageSizeBytes');
        _sendMessage(
            socket, WebSocketMessage(type: 'error', data: {'message': 'Message too large', 'server_type': 'desktop'}));
        return;
      }

      // Check connection timeout
      if (_isConnectionExpired(socket)) {
        Logger.warning('🕒 Connection expired, closing socket');
        await socket.close();
        return;
      }

      Logger.debug('Processing message in desktop server: $message');

      WebSocketMessage? parsedMessage;
      try {
        parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
      } catch (e) {
        Logger.warning('🚫 Invalid JSON message received: $e');
        _sendMessage(socket,
            WebSocketMessage(type: 'error', data: {'message': 'Invalid JSON format', 'server_type': 'desktop'}));
        return;
      }

      if (parsedMessage == null) {
        throw FormatException('Error parsing WebSocket message');
      }

      // Validate message structure
      if (!_isValidWebSocketMessage(parsedMessage)) {
        Logger.warning('🚫 Invalid message structure received');
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
          Logger.warning('⚠️ Legacy sync endpoint called on desktop server - this is deprecated');
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
          Logger.info('🔄 Desktop server received paginated sync start request');
          await _handlePaginatedSyncStart(parsedMessage, socket);
          break;

        case 'paginated_sync_request':
          Logger.info('🔄 Desktop server received data page request');
          await _handlePaginatedSyncRequest(parsedMessage, socket);
          break;

        case 'paginated_sync':
          Logger.info('🔄 Desktop server processing paginated sync request...');
          final paginatedSyncData = parsedMessage.data;
          if (paginatedSyncData == null) {
            throw FormatException('Paginated sync message missing data');
          }

          Logger.debug(
              '📊 Desktop server paginated sync data received for entity: ${(paginatedSyncData as Map<String, dynamic>)['entityType']}');

          try {
            final command =
                PaginatedSyncCommand(paginatedSyncDataDto: PaginatedSyncDataDto.fromJson(paginatedSyncData));
            final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);
            Logger.info('✅ Desktop server paginated sync processing completed successfully');

            // For paginated sync, send the data back as paginated_sync, not paginated_sync_complete
            WebSocketMessage responseMessage = WebSocketMessage(type: 'paginated_sync', data: {
              'paginatedSyncDataDto': response.paginatedSyncDataDto?.toJson(),
              'success': true,
              'isComplete': response.isComplete,
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'desktop'
            });
            _sendMessage(socket, responseMessage, '📤 Desktop server paginated sync response sent to client');

            // Keep connection alive for potential additional sync requests
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
            // Keep connection alive even after errors
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

      _sendMessage(socket, response, '📤 Sent device info response');
    } catch (e) {
      Logger.error('Failed to handle device info request: $e');
    }
  }

  Future<void> _handleClientConnect(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>;
      final clientId = data['clientId'] as String?;
      final clientName = data['clientName'] as String?;

      Logger.info('🔌 Client connecting: $clientName ($clientId)');

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

      _sendMessage(socket, response, '✅ Client connected successfully: $clientName');
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

      Logger.info('🤝 Desktop server: Client ($clientId) initiated paginated sync with server ($serverId)');

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

      _sendMessage(socket, response, '📤 Desktop server: Sent paginated_sync_started response');

      // Acknowledge the sync start but don't immediately push data
      // The client will request data pages as needed
      Logger.info('🔄 Desktop server: Acknowledged sync start request from client');
    } catch (e, stackTrace) {
      Logger.error('❌ Desktop server: Failed to handle paginated_sync_start: $e');
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

      Logger.info('📄 Desktop server: Client requested page $pageIndex of $entityType (size: $pageSize)');

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
        Logger.info('✅ Desktop server: Found $itemCount items for page $pageIndex of $entityType');

        final responseMessage = WebSocketMessage(
          type: 'paginated_sync',
          data: {
            'success': true,
            'paginatedSyncDataDto': response.paginatedSyncDataDto!.toJson(),
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'desktop'
          },
        );

        _sendMessage(socket, responseMessage, '📤 Desktop server: Sent page $pageIndex data to client');
      } else {
        Logger.info('📄 Desktop server: No data found for page $pageIndex of $entityType');

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

        _sendMessage(socket, emptyResponseMessage, '📤 Desktop server: Sent empty response for page $pageIndex');
      }
    } catch (e, stackTrace) {
      Logger.error('❌ Desktop server: Failed to handle paginated_sync_request: $e');
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
      Logger.debug('💓 Received heartbeat from client');

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
        Logger.debug('🖥️ Desktop server heartbeat - Active connections: ${_activeConnections.length}');

        // Clean up closed connections and expired connections
        final closedConnections =
            _activeConnections.where((ws) => ws.readyState == WebSocket.closed || _isConnectionExpired(ws)).toList();
        for (final ws in closedConnections) {
          if (_isConnectionExpired(ws)) {
            Logger.debug('🕒 Closing expired connection');
            ws.close();
          }
          _cleanupConnection(ws);
        }

        // Log server health for debugging
        if (_activeConnections.isEmpty) {
          Logger.debug('🖥️ Desktop server running in background, waiting for connections...');
        } else {
          Logger.debug('🖥️ Desktop server actively serving ${_activeConnections.length} client(s)');
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
      Logger.info('🛑 Stopping desktop WebSocket server...');

      _serverKeepAlive?.cancel();
      _serverKeepAlive = null;

      // Close all active connections
      for (final ws in _activeConnections) {
        try {
          await ws.close();
        } catch (e) {
          Logger.debug('Error closing WebSocket connection: $e');
        }
      }
      _activeConnections.clear();
      _connectionIPs.clear(); // Clean up IP mappings
      _connectionTimes.clear(); // Clean up connection times
      _ipConnectionCounts.clear(); // Clean up IP connection counts

      // Close the server
      await _server?.close();
      _server = null;
      _isServerMode = false;

      Logger.info('✅ Desktop WebSocket server stopped');
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
  bool _canAcceptNewConnection(String clientIP) {
    // Check total connection limit
    if (_activeConnections.length >= maxConcurrentConnections) {
      return false;
    }

    // Check per-IP connection limit (max 3 connections per IP)
    final ipConnections = _ipConnectionCounts[clientIP] ?? 0;
    if (ipConnections >= 3) {
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
  void _cleanupConnection(WebSocket socket) {
    final clientIP = _connectionIPs[socket];

    _activeConnections.remove(socket);
    _connectionIPs.remove(socket);
    _connectionTimes.remove(socket);

    // Decrement IP connection count
    if (clientIP != null) {
      final currentCount = _ipConnectionCounts[clientIP] ?? 0;
      if (currentCount > 1) {
        _ipConnectionCounts[clientIP] = currentCount - 1;
      } else {
        _ipConnectionCounts.remove(clientIP);
      }
    }
  }
}
