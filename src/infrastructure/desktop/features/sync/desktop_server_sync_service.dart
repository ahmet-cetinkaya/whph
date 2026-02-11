import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/utils/network_utils.dart';
import 'package:application/features/sync/services/sync_service.dart';
import 'package:application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:application/shared/models/websocket_request.dart';
import 'package:application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:whph/infrastructure/desktop/features/sync/websocket_connection_manager.dart';
import 'package:whph/infrastructure/desktop/features/sync/websocket_message_validator.dart';
import 'package:flutter/foundation.dart';

const int webSocketPort = 44040;
const int defaultSyncInterval = 1800;

/// Desktop server sync service that acts as WebSocket server for WHPH clients.
///
/// Uses extracted components for cleaner separation:
/// - [WebSocketConnectionManager] for connection lifecycle
/// - [WebSocketMessageValidator] for message validation
class DesktopServerSyncService extends SyncService {
  HttpServer? _server;
  bool _isServerMode = false;
  Timer? _serverKeepAlive;

  final WebSocketConnectionManager _connectionManager = WebSocketConnectionManager();
  final WebSocketMessageValidator _messageValidator = const WebSocketMessageValidator();
  final IDeviceIdService _deviceIdService;

  DesktopServerSyncService(super.mediator, this._deviceIdService) {
    _connectionManager.validateAndCleanConnectionState();
  }

  Future<bool> startAsServer() async {
    try {
      DomainLogger.info('Attempting to start desktop WebSocket server...');

      _server = await HttpServer.bind(InternetAddress.anyIPv4, webSocketPort, shared: true);
      _isServerMode = true;
      _startServerKeepAlive();
      _handleServerConnections();

      DomainLogger.info('Desktop WebSocket server started on port $webSocketPort');
      return true;
    } catch (e) {
      DomainLogger.warning('Failed to start desktop server: $e');
      _isServerMode = false;
      return false;
    }
  }

  void _handleServerConnections() async {
    final server = _server;
    if (server == null) return;

    await for (HttpRequest req in server) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final clientIP = req.connectionInfo?.remoteAddress.address ?? '127.0.0.1';

          if (!_connectionManager.canAcceptNewConnection(clientIP)) {
            _rejectConnection(req, HttpStatus.serviceUnavailable, 'Connection limit exceeded');
            continue;
          }

          if (!NetworkUtils.isPrivateIP(clientIP)) {
            _rejectConnection(req, HttpStatus.forbidden, 'Only private network connections allowed');
            continue;
          }

          final ws = await WebSocketTransformer.upgrade(req);
          _connectionManager.registerConnection(ws, clientIP);

          DomainLogger.info(
              'Client connected from $clientIP (${_connectionManager.connectionCount}/$maxConcurrentConnections)');

          ws.listen(
            (data) async => await _handleWebSocketMessage(data.toString(), ws),
            onError: (e) {
              DomainLogger.error('Connection error: $e');
              _connectionManager.cleanupConnection(ws);
              ws.close();
            },
            onDone: () {
              DomainLogger.debug('Client disconnected');
              _connectionManager.cleanupConnection(ws);
            },
            cancelOnError: true,
          );
        } else {
          _rejectConnection(req, HttpStatus.upgradeRequired, 'WebSocket upgrade required');
        }
      } catch (e) {
        DomainLogger.error('Request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  }

  void _rejectConnection(HttpRequest req, int statusCode, String message) {
    req.response
      ..statusCode = statusCode
      ..write(message)
      ..close();
    DomainLogger.warning('Connection rejected: $message');
  }

  Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
    try {
      _connectionManager.updateActivity(socket);

      if (!_messageValidator.isMessageSizeValid(message)) {
        _sendError(socket, 'Message too large');
        return;
      }

      if (_connectionManager.isConnectionExpired(socket)) {
        DomainLogger.warning('Connection expired, closing socket');
        await socket.close();
        return;
      }

      WebSocketMessage? parsedMessage;
      try {
        parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
      } catch (e) {
        _sendError(socket, 'Invalid JSON format');
        return;
      }

      if (parsedMessage == null || !_messageValidator.isValidWebSocketMessage(parsedMessage)) {
        _sendError(socket, 'Invalid message structure');
        return;
      }

      await _routeMessage(parsedMessage, socket);
    } catch (e) {
      DomainLogger.error('Error processing message: $e');
      _sendError(socket, e.toString());
      await socket.close();
    }
  }

  Future<void> _routeMessage(WebSocketMessage message, WebSocket socket) async {
    switch (message.type) {
      case 'device_info':
        await _handleDeviceInfoRequest(socket);
        break;
      case 'test':
        _sendTestResponse(socket);
        break;
      case 'client_connect':
        await _handleClientConnect(message, socket);
        break;
      case 'heartbeat':
        _sendHeartbeatResponse(socket);
        break;
      case 'sync':
        _sendDeprecationWarning(socket);
        break;
      case 'paginated_sync_start':
        await _handlePaginatedSyncStart(message, socket);
        break;
      case 'paginated_sync_request':
        await _handlePaginatedSyncRequest(message, socket);
        break;
      case 'paginated_sync':
        await _handlePaginatedSync(message, socket);
        break;
      default:
        _sendError(socket, 'Unknown message type');
    }
  }

  Future<void> _handleDeviceInfoRequest(WebSocket socket) async {
    _sendMessage(
        socket,
        WebSocketMessage(
          type: 'device_info_response',
          data: {
            'success': true,
            'deviceId': await _deviceIdService.getDeviceId(),
            'deviceName': await DeviceInfoHelper.getDeviceName(),
            'appName': AppInfo.shortName,
            'platform': Platform.operatingSystem,
            'serverInfo': {
              'isServerActive': true,
              'serverPort': webSocketPort,
              'activeConnections': _connectionManager.connectionCount
            },
            'timestamp': DateTime.now().toIso8601String(),
          },
        ));
  }

  void _sendTestResponse(WebSocket socket) {
    _sendMessage(
        socket,
        WebSocketMessage(
          type: 'test_response',
          data: {
            'success': true,
            'timestamp': DateTime.now().toIso8601String(),
            'server_type': 'desktop',
            'platform': Platform.operatingSystem
          },
        ));
  }

  Future<void> _handleClientConnect(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>;
      DomainLogger.info('Client connecting: ${data['clientName']} (${data['clientId']})');

      _sendMessage(
          socket,
          WebSocketMessage(
            type: 'client_connected',
            data: {
              'success': true,
              'serverId': await _deviceIdService.getDeviceId(),
              'serverName': await DeviceInfoHelper.getDeviceName(),
              'syncInterval': defaultSyncInterval,
              'supportedOperations': ['paginated_sync'],
              'timestamp': DateTime.now().toIso8601String(),
            },
          ));
    } catch (e) {
      DomainLogger.error('Failed to handle client connect: $e');
      _sendMessage(socket,
          WebSocketMessage(type: 'client_connected', data: {'success': false, 'message': 'Connection failed: $e'}));
    }
  }

  void _sendHeartbeatResponse(WebSocket socket) {
    _sendMessage(
        socket,
        WebSocketMessage(
          type: 'heartbeat_response',
          data: {'timestamp': DateTime.now().toIso8601String(), 'serverStatus': 'healthy'},
        ));
  }

  void _sendDeprecationWarning(WebSocket socket) {
    DomainLogger.warning('Legacy sync endpoint called - deprecated');
    _sendMessage(
        socket,
        WebSocketMessage(
          type: 'sync_deprecated',
          data: {
            'success': false,
            'message': 'Legacy sync is deprecated. Please use paginated_sync endpoint.',
            'timestamp': DateTime.now().toIso8601String()
          },
        ));
  }

  Future<void> _handlePaginatedSyncStart(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>?;
      if (data == null) throw FormatException('paginated_sync_start message missing data');

      DomainLogger.info('Client (${data['clientId']}) initiated paginated sync');
      _sendMessage(
          socket,
          WebSocketMessage(
            type: 'paginated_sync_started',
            data: {
              'success': true,
              'serverId': await _deviceIdService.getDeviceId(),
              'message': 'Paginated sync session started',
              'timestamp': DateTime.now().toIso8601String()
            },
          ));
    } catch (e) {
      DomainLogger.error('Failed to handle paginated_sync_start: $e');
      _sendMessage(
          socket,
          WebSocketMessage(
              type: 'paginated_sync_error', data: {'success': false, 'message': 'Failed to start paginated sync: $e'}));
    }
  }

  Future<void> _handlePaginatedSyncRequest(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data as Map<String, dynamic>?;
      if (data == null) throw FormatException('paginated_sync_request message missing data');

      final entityType = data['entityType'] as String?;
      final pageIndex = data['pageIndex'] as int?;
      final pageSize = data['pageSize'] as int? ?? 50;
      final clientId = data['clientId'] as String?;

      if (entityType == null || pageIndex == null || clientId == null) {
        throw FormatException('Missing required fields');
      }

      DomainLogger.info('Client requested page $pageIndex of $entityType (size: $pageSize)');

      final deviceId = await _deviceIdService.getDeviceId();
      final syncDevice = SyncDevice(
        id: deviceId,
        createdDate: DateTime.now(),
        fromIp: _getServerLocalIp(),
        toIp: _connectionManager.getClientIP(socket) ?? '127.0.0.1',
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
        totalPages: 1,
        totalItems: 0,
        isLastPage: false,
      );

      final command = PaginatedSyncCommand(paginatedSyncDataDto: requestDto);
      final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

      if (response.paginatedSyncDataDto != null) {
        _sendMessage(
            socket,
            WebSocketMessage(
              type: 'paginated_sync',
              data: {
                'success': true,
                'paginatedSyncDataDto': response.paginatedSyncDataDto!.toJson(),
                'timestamp': DateTime.now().toIso8601String(),
                'server_type': 'desktop'
              },
            ));
      } else {
        _sendMessage(
            socket,
            WebSocketMessage(
              type: 'paginated_sync_complete',
              data: {
                'success': true,
                'isComplete': true,
                'message': 'No data available',
                'timestamp': DateTime.now().toIso8601String()
              },
            ));
      }
    } catch (e) {
      DomainLogger.error('Failed to handle paginated_sync_request: $e');
      _sendMessage(
          socket,
          WebSocketMessage(
              type: 'paginated_sync_error', data: {'success': false, 'message': 'Failed to process data request: $e'}));
    }
  }

  Future<void> _handlePaginatedSync(WebSocketMessage message, WebSocket socket) async {
    try {
      final data = message.data;
      if (data == null) throw FormatException('Paginated sync message missing data');

      final command =
          PaginatedSyncCommand(paginatedSyncDataDto: PaginatedSyncDataDto.fromJson(data as Map<String, dynamic>));

      final response = await mediator
          .send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command)
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw TimeoutException('Sync operation timed out');
      });

      _sendMessage(
          socket,
          WebSocketMessage(
            type: 'paginated_sync',
            data: {
              'paginatedSyncDataDto': response.paginatedSyncDataDto?.toJson(),
              'success': true,
              'isComplete': response.isComplete,
              'timestamp': DateTime.now().toIso8601String(),
              'server_type': 'desktop'
            },
          ));

      await _connectionManager.closeSocketGracefully(socket, 1000, 'Paginated sync completed');
    } catch (e) {
      DomainLogger.error('Paginated sync failed: $e');
      _sendMessage(
          socket, WebSocketMessage(type: 'paginated_sync_error', data: {'success': false, 'message': e.toString()}));
      await _connectionManager.closeSocketGracefully(socket, 1011, 'Paginated sync failed');
    }
  }

  void _startServerKeepAlive() {
    _serverKeepAlive = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_server != null && _isServerMode) {
        DomainLogger.debug('Server heartbeat - Active connections: ${_connectionManager.connectionCount}');
        _connectionManager.recycleIdleConnections();
        _connectionManager.cleanupExpiredConnections();
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
      DomainLogger.info('Stopping desktop WebSocket server...');
      _serverKeepAlive?.cancel();
      _serverKeepAlive = null;
      await _connectionManager.forceCleanupAllConnections();
      await _server?.close();
      _server = null;
      _isServerMode = false;
      DomainLogger.info('Desktop WebSocket server stopped');
    }
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }

  void _sendMessage(WebSocket socket, WebSocketMessage message) => socket.add(JsonMapper.serialize(message));
  void _sendError(WebSocket socket, String message) =>
      _sendMessage(socket, WebSocketMessage(type: 'error', data: {'message': message, 'server_type': 'desktop'}));

  String _getServerLocalIp() {
    try {
      final serverAddress = _server?.address;
      if (serverAddress != null && serverAddress.address != '0.0.0.0') {
        return serverAddress.address;
      }
    } catch (e) {
      DomainLogger.debug('Failed to get server local IP: $e');
    }
    return '127.0.0.1';
  }

  bool get isServerMode => _isServerMode;
  int get activeConnectionCount => _connectionManager.connectionCount;
  bool get isServerHealthy => _isServerMode && _server != null;
}
