import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/infrastructure/android/features/sync/android_sync_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/presentation/api/controllers/paginated_sync_controller.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';

const int webSocketPort = 44040;

class AndroidServerSyncService extends AndroidSyncService {
  HttpServer? _server;
  bool _isServerMode = false;
  Timer? _serverKeepAlive;
  final List<WebSocket> _activeConnections = [];

  final IDeviceIdService _deviceIdService;
  final DeviceInfoPlugin _deviceInfoPlugin;

  AndroidServerSyncService(
    super.mediator,
    this._deviceIdService,
    this._deviceInfoPlugin,
  );

  /// Attempt to start as WebSocket server
  Future<bool> startAsServer() async {
    try {
      Logger.info('🚀 Attempting to start mobile WebSocket server...');

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        webSocketPort,
        shared: true,
      );

      _isServerMode = true;
      _startServerKeepAlive();
      _handleServerConnections();

      Logger.info('✅ Mobile WebSocket server started on port $webSocketPort');
      Logger.info('🌐 Mobile server listening on all IPv4 interfaces (0.0.0.0:$webSocketPort)');
      Logger.info('📱 Ready to receive sync requests from other mobile devices');

      return true;
    } catch (e) {
      Logger.warning('❌ Failed to start mobile server: $e');
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
              '📱 Mobile server: Client connected from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort}');

          ws.listen(
            (data) async {
              Logger.debug('📨 Mobile server received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('❌ Mobile server connection error: $e');
              _activeConnections.remove(ws);
              ws.close();
            },
            onDone: () {
              Logger.debug('🔚 Mobile server: Client disconnected');
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
        Logger.error('⚠️ Mobile server request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  }

  Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
    try {
      Logger.debug('Processing message in mobile server: $message');

      WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
      if (parsedMessage == null) {
        throw FormatException('Error parsing WebSocket message');
      }

      switch (parsedMessage.type) {
        case 'device_info':
          Logger.info('🤝 Mobile server handling device_info handshake request');
          try {
            final localDeviceId = await _deviceIdService.getDeviceId();
            final androidInfo = await _deviceInfoPlugin.androidInfo;
            final deviceName = androidInfo.model;
            const appName = AppInfo.shortName;
            const platform = 'android';

            final capabilities = DeviceCapabilities(
              canActAsServer: true,
              canActAsClient: true,
              supportedModes: ['mobile', 'paginated_sync'],
              supportedOperations: ['sync', 'paginated_sync', 'device_handshake'],
            );

            final serverInfo = ServerInfo(
              isServerActive: true,
              serverPort: webSocketPort,
              activeConnections: _activeConnections.length,
            );

            final responseData = {
              'success': true,
              'deviceId': localDeviceId,
              'deviceName': deviceName,
              'appName': appName,
              'platform': platform,
              'capabilities': capabilities.toJson(),
              'serverInfo': serverInfo.toJson(),
            };

            final responseMessage = WebSocketMessage(
              type: 'device_info_response',
              data: responseData,
            );

            socket.add(JsonMapper.serialize(responseMessage));
            Logger.info('✅ Mobile server sent device_info_response: $deviceName ($localDeviceId)');

            // Close after handshake response
            await Future.delayed(const Duration(milliseconds: 100));
            await socket.close();
          } catch (e) {
            Logger.error('❌ Failed to prepare device_info response: $e');
            final errorData = {
              'success': false,
              'error': 'Failed to prepare device information: ${e.toString()}',
            };
            final errorMessage = WebSocketMessage(
              type: 'device_info_response',
              data: errorData,
            );
            socket.add(JsonMapper.serialize(errorMessage));
            await socket.close();
          }
          break;
        case 'test':
          socket.add(JsonMapper.serialize(WebSocketMessage(
            type: 'test_response',
            data: {
              'success': true,
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'mobile',
            },
          )));
          break;

        case 'sync':
          Logger.warning('⚠️ Legacy sync endpoint called on mobile server - this is deprecated');
          WebSocketMessage deprecationMessage = WebSocketMessage(type: 'sync_deprecated', data: {
            'success': false,
            'message': 'Legacy sync is deprecated. Please use paginated_sync endpoint.',
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'mobile'
          });
          socket.add(JsonMapper.serialize(deprecationMessage));
          await socket.close();
          break;

        case 'paginated_sync':
          Logger.info('🔄 Mobile server processing paginated sync request...');
          final paginatedSyncData = parsedMessage.data;
          if (paginatedSyncData == null) {
            throw FormatException('Paginated sync message missing data');
          }

          Logger.debug(
              '📊 Mobile server paginated sync data received for entity: ${(paginatedSyncData as Map<String, dynamic>)['entityType']}');
          final paginatedController = PaginatedSyncController();

          try {
            final response = await paginatedController.paginatedSync(PaginatedSyncDataDto.fromJson(paginatedSyncData));
            Logger.info('✅ Mobile server paginated sync processing completed successfully');

            WebSocketMessage responseMessage = WebSocketMessage(type: 'paginated_sync_complete', data: {
              'paginatedSyncDataDto': response.paginatedSyncDataDto?.toJson(),
              'success': true,
              'isComplete': response.isComplete,
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'mobile'
            });
            socket.add(JsonMapper.serialize(responseMessage));
            Logger.info('📤 Mobile server paginated sync response sent to client');

            await Future.delayed(const Duration(milliseconds: 200));
            await socket.close();
          } catch (e, stackTrace) {
            Logger.error('Mobile server paginated sync processing failed: $e');
            Logger.error('Stack trace: $stackTrace');

            final errorData = <String, dynamic>{
              'success': false,
              'message': e.toString(),
              'type': e.runtimeType.toString(),
              'stackTrace': stackTrace.toString(),
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'mobile',
              'entityType': (parsedMessage.data as Map<String, dynamic>?)?.containsKey('entityType') == true
                  ? (parsedMessage.data as Map<String, dynamic>)['entityType']
                  : 'unknown',
            };

            WebSocketMessage errorMessage = WebSocketMessage(type: 'paginated_sync_error', data: errorData);
            socket.add(JsonMapper.serialize(errorMessage));
            await socket.close();
          }
          break;

        default:
          socket.add(JsonMapper.serialize(
              WebSocketMessage(type: 'error', data: {'message': 'Unknown message type', 'server_type': 'mobile'})));
          await socket.close();
          break;
      }
    } catch (e) {
      Logger.error('Error processing WebSocket message in mobile server: $e');
      socket.add(JsonMapper.serialize(
          WebSocketMessage(type: 'error', data: {'message': e.toString(), 'server_type': 'mobile'})));
      await socket.close();
      rethrow;
    }
  }

  void _startServerKeepAlive() {
    _serverKeepAlive = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_server != null && _isServerMode) {
        Logger.debug('📱 Mobile server heartbeat - Active connections: ${_activeConnections.length}');

        // Clean up closed connections
        _activeConnections.removeWhere((ws) => ws.readyState == WebSocket.closed);

        // Log server health for debugging
        if (_activeConnections.isEmpty) {
          Logger.debug('📱 Mobile server running in background, waiting for connections...');
        } else {
          Logger.debug('📱 Mobile server actively serving ${_activeConnections.length} client(s)');
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
      Logger.info('🛑 Stopping mobile WebSocket server...');

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

      Logger.info('✅ Mobile WebSocket server stopped');
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
}
