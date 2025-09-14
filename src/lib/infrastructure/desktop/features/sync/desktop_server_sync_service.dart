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

const int webSocketPort = 44040;
const int defaultSyncInterval = 1800; // 30 minutes in seconds

/// Desktop server sync service that acts as WebSocket server for WHPH clients
class DesktopServerSyncService extends SyncService {
  HttpServer? _server;
  bool _isServerMode = false;
  Timer? _serverKeepAlive;
  final List<WebSocket> _activeConnections = [];

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
          final ws = await WebSocketTransformer.upgrade(req);
          _activeConnections.add(ws);

          Logger.info(
              '🖥️ Desktop server: Client connected from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort}');

          ws.listen(
            (data) async {
              Logger.debug('📨 Desktop server received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('❌ Desktop server connection error: $e');
              _activeConnections.remove(ws);
              ws.close();
            },
            onDone: () {
              Logger.debug('🔚 Desktop server: Client disconnected');
              _activeConnections.remove(ws);
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
      Logger.debug('Processing message in desktop server: $message');

      WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
      if (parsedMessage == null) {
        throw FormatException('Error parsing WebSocket message');
      }

      switch (parsedMessage.type) {
        case 'device_info':
          await _handleDeviceInfoRequest(socket);
          break;

        case 'test':
          _sendMessage(socket, WebSocketMessage(
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

        case 'paginated_sync':
          Logger.info('🔄 Desktop server processing paginated sync request...');
          final paginatedSyncData = parsedMessage.data;
          if (paginatedSyncData == null) {
            throw FormatException('Paginated sync message missing data');
          }

          Logger.debug(
              '📊 Desktop server paginated sync data received for entity: ${(paginatedSyncData as Map<String, dynamic>)['entityType']}');

          try {
            final command = PaginatedSyncCommand(paginatedSyncDataDto: PaginatedSyncDataDto.fromJson(paginatedSyncData));
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
          _sendMessage(socket, WebSocketMessage(type: 'error', data: {'message': 'Unknown message type', 'server_type': 'desktop'}));
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

      // Start an asynchronous sync process that will send data over the persistent connection
      Logger.info('🔄 Desktop server: Starting sync data gathering for client');
      _startSyncDataGathering(clientId, socket);

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

  /// Start async sync data gathering using persistent connection
  void _startSyncDataGathering(String? clientId, WebSocket socket) {
    // Run the sync data gathering asynchronously to avoid blocking the response
    Future(() async {
      try {
        Logger.info('🔄 Desktop server: Gathering sync data for client over persistent connection');

        // Use the mediator to get sync data, but keep the connection open
        final command = PaginatedSyncCommand(targetDeviceId: clientId);
        final syncResponse = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

        // Send the sync data back to the client over persistent connection
        final syncDataMessage = WebSocketMessage(
          type: 'paginated_sync',
          data: {
            'success': true,
            'paginatedSyncDataDto': syncResponse.paginatedSyncDataDto?.toJson(),
            'isComplete': syncResponse.isComplete,
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'desktop',
          },
        );

        _sendMessage(socket, syncDataMessage, '📤 Desktop server: Sent sync data to client via persistent connection');

      } catch (e, stackTrace) {
        Logger.error('❌ Desktop server: Failed to gather sync data: $e');
        Logger.error('Stack trace: $stackTrace');

        final errorMessage = WebSocketMessage(
          type: 'paginated_sync_error',
          data: {
            'success': false,
            'message': 'Failed to gather sync data: ${e.toString()}',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        _sendMessage(socket, errorMessage);
      }
    }).catchError((e) {
      Logger.error('❌ Desktop server: Unhandled error in sync data gathering: $e');
    });
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

        // Clean up closed connections
        _activeConnections.removeWhere((ws) => ws.readyState == WebSocket.closed);

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
}
