import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

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

  final IDeviceIdService _deviceIdService;

  static const Duration _heartbeatInterval = Duration(minutes: 2);
  static const Duration _syncInterval = Duration(minutes: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  DesktopClientSyncService(super.mediator, this._deviceIdService);

  /// Connect to a WHPH server as client
  Future<bool> connectToServer(String serverAddress, int serverPort) async {
    try {
      Logger.info('Connecting to server at $serverAddress:$serverPort');

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
          Logger.error('Client connection error: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          _handleConnectionError();
        },
        onDone: () {
          Logger.info('Server connection closed');
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
        Logger.info('Successfully connected to server $serverAddress:$serverPort');

        // Start periodic sync
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

  /// Disconnect from current server
  Future<void> disconnectFromServer() async {
    Logger.info('Disconnecting from server');
    await _cleanupConnection();
    Logger.info('Disconnected from server');
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
      Logger.warning('Cannot start sync - not connected to server');
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

    try {
      Logger.info('Starting client paginated sync over persistent connection');

      // Update sync status to syncing
      updateSyncStatus(SyncStatus(
        state: SyncState.syncing,
        isManual: isManual,
        lastSyncTime: DateTime.now(),
      ));

      // Use persistent connection for sync instead of creating new connections
      await _performPaginatedSyncOverPersistentConnection();

      Logger.info('Client paginated sync completed');
    } catch (e) {
      Logger.error('Client paginated sync failed: $e');
      rethrow;
    }
  }

  /// Perform paginated sync using the persistent WebSocket connection
  Future<void> _performPaginatedSyncOverPersistentConnection() async {
    final localDeviceId = await _deviceIdService.getDeviceId();

    // Send initial sync request through persistent connection
    final syncRequest = WebSocketMessage(
      type: 'paginated_sync_start',
      data: {
        'clientId': localDeviceId,
        'serverId': _connectedServerId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _sendMessage(syncRequest, 'Sent paginated sync start request over persistent connection');

    // The sync process will continue through the WebSocket message handler
    // which will handle paginated_sync_response messages from the server
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

              // Process the data from the server
              final command = PaginatedSyncCommand(paginatedSyncDataDto: dto);
              final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

              Logger.info('Successfully processed sync data from server');

              // Continue with next page if available, or send client's data for bidirectional sync
              if (!dto.isLastPage) {
                // Request next page from server
                final nextPageRequest = WebSocketMessage(
                  type: 'paginated_sync_request',
                  data: {
                    'entityType': dto.entityType,
                    'pageIndex': dto.pageIndex + 1,
                    'pageSize': dto.pageSize,
                    'clientId': await _deviceIdService.getDeviceId(),
                  },
                );
                _sendMessage(nextPageRequest,
                    'Requested next page ${dto.pageIndex + 1} from server for entity ${dto.entityType}');
              } else if (response.paginatedSyncDataDto != null) {
                // Send client's data back to the server for bidirectional sync
                final responseMessage = WebSocketMessage(
                  type: 'paginated_sync',
                  data: response.paginatedSyncDataDto!.toJson(),
                );
                _sendMessage(responseMessage,
                    'Sent paginated sync data back to server for entity ${response.paginatedSyncDataDto!.entityType}');
              }
            } catch (e) {
              Logger.error('Failed to process paginated_sync data: $e');
            }
          } else {
            Logger.warning('Received paginated_sync with no data or failed status');
          }
          break;

        case 'paginated_sync_complete':
          Logger.debug('Received final sync completion from server');
          final data = response.data as Map<String, dynamic>;
          if (data['success'] == true && data['paginatedSyncDataDto'] != null) {
            try {
              final dto = PaginatedSyncDataDto.fromJson(data['paginatedSyncDataDto'] as Map<String, dynamic>);
              Logger.info('Processing final sync data from server: ${dto.entityType}');

              // Process the final data from the server
              final command = PaginatedSyncCommand(paginatedSyncDataDto: dto);
              await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);

              Logger.info('Successfully processed final sync data from server');
            } catch (e) {
              Logger.error('Failed to process paginated_sync_complete data: $e');
            }
          }

          // Check if we need to send more data from the client side for bidirectional sync
          if (data['isComplete'] == false) {
            // Server indicates it's not complete, we might need to send more client data
            Logger.debug('Server indicates sync not complete, preparing client data');
            // In a proper implementation, we would trigger sending client data here
            // For now, we'll just update the status but leave the connection open for further messages
          } else {
            // Update sync status to completed
            updateSyncStatus(SyncStatus(
              state: SyncState.completed,
              lastSyncTime: DateTime.now(),
            ));
          }
          break;

        case 'error':
          final data = response.data as Map<String, dynamic>;
          Logger.error('Server error: ${data['message']}');
          break;

        default:
          Logger.debug('Unhandled message type: ${response.type}');
      }
    } catch (e) {
      Logger.error('Error handling server message: $e');
    }
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
    // Implement reconnection logic based on settings
    _attemptReconnection();
  }

  void _handleConnectionClosed() {
    Logger.info('Connection closed');
    _isConnected = false;
    // Implement reconnection logic based on settings
    _attemptReconnection();
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

  /// Helper method to send WebSocket messages and handle serialization
  void _sendMessage(WebSocketMessage message, [String? logMessage]) {
    if (_clientChannel != null) {
      _clientChannel!.sink.add(JsonMapper.serialize(message));
      if (logMessage != null) {
        Logger.debug(logMessage);
      }
    }
  }

  /// Attempt to reconnect to the server based on settings
  void _attemptReconnection() {
    // Implement reconnection logic based on settings
    if (_connectedServerAddress != null && _connectedServerPort != null) {
      Logger.info('Attempting reconnection to server $_connectedServerAddress:$_connectedServerPort');
      // Add a delay before attempting reconnection
      Future.delayed(const Duration(seconds: 5), () {
        connectToServer(_connectedServerAddress!, _connectedServerPort!);
      });
    } else {
      Logger.warning('Cannot attempt reconnection - no server address/port stored');
    }
  }
}
