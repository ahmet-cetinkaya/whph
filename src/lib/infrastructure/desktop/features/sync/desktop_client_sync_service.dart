import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Desktop client sync service that connects to WHPH servers
class DesktopClientSyncService extends SyncService {
  WebSocketChannel? _clientChannel;
  Timer? _heartbeatTimer;
  Timer? _syncTimer;
  Timer? _reconnectTimer;
  String? _connectedServerAddress;
  int? _connectedServerPort;
  String? _connectedServerId;
  bool _isConnected = false;
  StreamSubscription? _messageSubscription;
  _DesktopSyncSession? _activeSyncSession;

  final IDeviceIdService _deviceIdService;
  final IRestoreBarrier _restoreBarrier;

  static const Duration _heartbeatInterval = Duration(minutes: 2);
  static const Duration _syncInterval = Duration(minutes: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  DesktopClientSyncService(
    super.mediator,
    this._deviceIdService, {
    required super.restoreBarrier,
  }) : _restoreBarrier = restoreBarrier;

  Future<bool> connectToServer(String serverAddress, int serverPort) async {
    try {
      Logger.info('Connecting to server at $serverAddress:$serverPort');

      await _cleanupConnection();

      final uri = Uri.parse('ws://$serverAddress:$serverPort');
      _clientChannel = WebSocketChannel.connect(uri);

      final completer = Completer<bool>();

      _messageSubscription = _clientChannel!.stream.listen(
        (message) async {
          await _handleServerMessage(message, completer);
        },
        onError: (error) {
          Logger.error('Client connection error: $error');
          _activeSyncSession?.requestTermination(error);
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          _handleConnectionError();
        },
        onDone: () {
          Logger.info('Server connection closed');
          _activeSyncSession?.requestTermination(StateError('Server connection closed during sync'));
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          _handleConnectionClosed();
        },
      );

      await _sendHandshakeRequest();

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
        Logger.info('Successfully connected to server $serverAddress:$serverPort');

        await startSync();
      } else {
        await _cleanupConnection();
        Logger.warning('Failed to connect to server');
      }

      return connected;
    } catch (e) {
      Logger.error('Connection failed: $e');
      await _cleanupConnection();
      return false;
    }
  }

  Future<void> disconnectFromServer() async {
    Logger.info('Disconnecting from server');
    await _cleanupConnection();
    Logger.info('Disconnected from server');
  }

  bool get isConnectedToServer => _isConnected && _clientChannel != null;

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
      Logger.warning('Cannot start sync - not connected to server');
      return;
    }

    Logger.debug('Starting desktop client periodic sync');

    await runSync();

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
      Logger.warning('Cannot sync - not connected to server');
      return;
    }

    try {
      Logger.info('Starting client sync with server');
      await runPaginatedSync(isManual: isManual);
      Logger.info('Client sync completed successfully');
    } catch (e) {
      Logger.error('Client sync failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> runPaginatedSync({bool isManual = false}) async {
    if (!_isConnected || _clientChannel == null) {
      throw Exception('Not connected to server');
    }
    if (_activeSyncSession != null) {
      throw StateError('A desktop client sync session is already active');
    }

    final lease = _restoreBarrier.acquireShared();
    final session = _DesktopSyncSession(lease);
    _activeSyncSession = session;
    try {
      Logger.info('Starting client paginated sync over persistent connection');

      updateSyncStatus(SyncStatus(
        state: SyncState.syncing,
        isManual: isManual,
        lastSyncTime: DateTime.now(),
      ));

      await _performPaginatedSyncOverPersistentConnection();
      await session.completion;

      Logger.info('Client paginated sync completed');
    } catch (e) {
      Logger.error('Client paginated sync failed: $e');
      rethrow;
    } finally {
      if (identical(_activeSyncSession, session)) _activeSyncSession = null;
      lease.release();
    }
  }

  Future<void> _performPaginatedSyncOverPersistentConnection() async {
    final localDeviceId = await _deviceIdService.getDeviceId();

    final syncRequest = WebSocketMessage(
      type: 'paginated_sync_start',
      data: {
        'clientId': localDeviceId,
        'serverId': _connectedServerId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _sendMessage(syncRequest, 'Sent paginated sync start request over persistent connection');
  }

  Future<void> _sendHandshakeRequest() async {
    if (_clientChannel == null) return;

    final handshake = WebSocketMessage(
      type: 'client_connect',
      data: {
        'clientId': await _deviceIdService.getDeviceId(),
        'clientName': await DeviceInfoHelper.getDeviceName(),
        'platform': 'desktop',
        'requestedServices': ['sync'],
        'clientCapabilities': ['paginated_sync'],
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _sendMessage(handshake, 'Sent client handshake request');
  }

  Future<void> _handleServerMessage(dynamic message, Completer<bool>? connectionCompleter) async {
    try {
      final messageStr = message.toString();
      Logger.debug('Received server message: $messageStr');

      final response = JsonMapper.deserialize<WebSocketMessage>(messageStr);
      if (response == null) return;

      if (_isSyncSessionMessage(response.type)) {
        final session = _activeSyncSession;
        if (session == null ||
            !session.enqueue(
              () => _handleServerResponse(response, connectionCompleter),
              closesSession: _endsSyncSession(response),
            )) {
          Logger.warning('Ignoring sync message without an active client session');
        }
        return;
      }
      await _handleServerResponse(response, connectionCompleter);
    } catch (error, stackTrace) {
      Logger.error('Error handling server message: $error');
      _activeSyncSession?.requestTermination(error, stackTrace);
    }
  }

  Future<void> _handleServerResponse(WebSocketMessage response, Completer<bool>? connectionCompleter) async {
    switch (response.type) {
      case 'client_connected':
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          _connectedServerId = data['serverId'] as String?;
          Logger.info('Client connected to server: ${data['serverName']}');
          connectionCompleter?.complete(true);
        } else {
          Logger.warning('Server rejected client connection: ${data['message']}');
          connectionCompleter?.complete(false);
        }
        break;

      case 'test_response':
        Logger.debug('Received server test response');
        break;

      case 'paginated_sync_started':
        Logger.info('Server acknowledged sync start');
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          Logger.debug('Paginated sync session established with server');
          // Initiate the actual data exchange by requesting the first data page
          final firstDataRequest = WebSocketMessage(
            type: 'paginated_sync_request',
            data: {
              'entityType': 'tasks', // Start with tasks
              'pageIndex': 0,
              'pageSize': 50,
              'clientId': await _deviceIdService.getDeviceId(),
            },
          );
          _sendMessage(firstDataRequest, 'Sent first data page request to server');
        } else {
          throw StateError('Server rejected the paginated sync session');
        }
        break;

      case 'paginated_sync':
        Logger.debug('Received paginated sync data from server');
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['paginatedSyncDataDto'] != null) {
          try {
            final dto = PaginatedSyncDataDto.fromJson(data['paginatedSyncDataDto'] as Map<String, dynamic>);
            Logger.info(
                'Processing sync data from server: ${dto.entityType} (page ${dto.pageIndex + 1}/${dto.totalPages})');

            final command = PaginatedSyncCommand(paginatedSyncDataDto: dto);
            final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

            Logger.info('Successfully processed sync data from server');

            if (!dto.isLastPage) {
              final nextPageRequest = WebSocketMessage(
                type: 'paginated_sync_request',
                data: {
                  'entityType': dto.entityType,
                  'pageIndex': dto.pageIndex + 1,
                  'pageSize': dto.pageSize,
                  'clientId': await _deviceIdService.getDeviceId(),
                },
              );
              _sendMessage(
                  nextPageRequest, 'Requested next page ${dto.pageIndex + 1} from server for entity ${dto.entityType}');
            } else if (response.paginatedSyncDataDto != null) {
              final responseMessage = WebSocketMessage(
                type: 'paginated_sync',
                data: response.paginatedSyncDataDto!.toJson(),
              );
              _sendMessage(responseMessage,
                  'Sent paginated sync data back to server for entity ${response.paginatedSyncDataDto!.entityType}');
            }
          } catch (e) {
            Logger.error('Failed to process paginated_sync data: $e');
            rethrow;
          }
        } else {
          throw StateError('Received invalid paginated sync data');
        }
        break;

      case 'paginated_sync_complete':
        Logger.debug('Received final sync completion from server');
        final data = response.data as Map<String, dynamic>;
        if (data['success'] != true) {
          throw StateError('Server failed to complete the paginated sync session');
        }
        if (data['success'] == true && data['paginatedSyncDataDto'] != null) {
          try {
            final dto = PaginatedSyncDataDto.fromJson(data['paginatedSyncDataDto'] as Map<String, dynamic>);
            Logger.info('Processing final sync data from server: ${dto.entityType}');

            final command = PaginatedSyncCommand(paginatedSyncDataDto: dto);
            await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

            Logger.info('Successfully processed final sync data from server');
          } catch (e) {
            Logger.error('Failed to process paginated_sync_complete data: $e');
            rethrow;
          }
        }

        // Check if we need to send more data from the client side for bidirectional sync
        if (data['isComplete'] == false) {
          // Server indicates it's not complete, we might need to send more client data
          Logger.debug('Server indicates sync not complete, preparing client data');
          // In a proper implementation, we would trigger sending client data here
          // For now, we'll just update the status but leave the connection open for further messages
        } else {
          updateSyncStatus(SyncStatus(
            state: SyncState.completed,
            lastSyncTime: DateTime.now(),
          ));
        }
        break;

      case 'error':
        final data = response.data as Map<String, dynamic>;
        Logger.error('Server error: ${data['message']}');
        throw StateError('Server ended the sync session with an error');

      default:
        Logger.debug('Unhandled message type: ${response.type}');
    }
  }

  bool _isSyncSessionMessage(String type) =>
      type == 'paginated_sync_started' ||
      type == 'paginated_sync' ||
      type == 'paginated_sync_complete' ||
      (type == 'error' && _activeSyncSession != null);

  bool _endsSyncSession(WebSocketMessage response) {
    if (response.type == 'error') return true;
    if (response.type != 'paginated_sync_complete') return false;
    final data = response.data;
    return data is! Map<String, dynamic> || data['isComplete'] != false;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      if (_isConnected && _clientChannel != null) {
        try {
          final heartbeat = WebSocketMessage(
            type: 'heartbeat',
            data: {
              'timestamp': DateTime.now().toIso8601String(),
              'clientId': await _deviceIdService.getDeviceId(),
            },
          );
          _sendMessage(heartbeat, ' Sent heartbeat to server');
        } catch (e) {
          Logger.error('Failed to send heartbeat: $e');
          _handleConnectionError();
        }
      }
    });
  }

  void _handleConnectionError() {
    Logger.warning('Connection error detected');
    _isConnected = false;
    _attemptReconnection();
  }

  void _handleConnectionClosed() {
    Logger.info('Connection closed');
    _isConnected = false;
    _attemptReconnection();
  }

  Future<void> _cleanupConnection() async {
    final activeSession = _activeSyncSession;
    activeSession?.requestTermination(StateError('Desktop client sync was cancelled'));
    if (activeSession != null) await activeSession.settled;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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

  void _sendMessage(WebSocketMessage message, [String? logMessage]) {
    if (_clientChannel != null) {
      _clientChannel!.sink.add(JsonMapper.serialize(message));
      if (logMessage != null) {
        Logger.debug(logMessage);
      }
    }
  }

  void _attemptReconnection() {
    final address = _connectedServerAddress;
    final port = _connectedServerPort;
    if (address == null || port == null) {
      Logger.warning('Cannot attempt reconnection - no server address/port stored');
      return;
    }
    Logger.info('Attempting reconnection to server $address:$port');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () => connectToServer(address, port));
  }
}

final class _DesktopSyncSession {
  _DesktopSyncSession(this._lease);

  final RestoreBarrierLease _lease;
  final Completer<void> _completion = Completer<void>();
  final Completer<void> _settled = Completer<void>();
  Future<void> _callbackTail = Future<void>.value();
  bool _isAccepting = true;
  bool _isTerminationRequested = false;
  Object? _terminationError;
  StackTrace? _terminationStackTrace;

  Future<void> get completion => _completion.future;
  Future<void> get settled => _settled.future;

  bool enqueue(Future<void> Function() callback, {required bool closesSession}) {
    if (!_isAccepting) return false;
    if (closesSession) _isAccepting = false;

    final previous = _callbackTail;
    _callbackTail = () async {
      await previous;
      try {
        await _lease.run(callback);
        if (closesSession) requestTermination();
      } catch (error, stackTrace) {
        requestTermination(error, stackTrace);
      }
    }();
    return true;
  }

  void requestTermination([Object? error, StackTrace? stackTrace]) {
    if (_isTerminationRequested) return;
    _isTerminationRequested = true;
    _isAccepting = false;
    _terminationError = error;
    _terminationStackTrace = stackTrace;
    unawaited(_settle());
  }

  Future<void> _settle() async {
    await _callbackTail;
    final error = _terminationError;
    if (error == null) {
      _completion.complete();
    } else {
      _completion.completeError(error, _terminationStackTrace ?? StackTrace.current);
    }
    _settled.complete();
  }
}
