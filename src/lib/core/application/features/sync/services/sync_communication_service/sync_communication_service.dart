import 'dart:async';
import 'dart:io';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/sync_communication_service/helpers/sync_dto_serializer.dart';
import 'package:whph/core/application/features/sync/services/sync_communication_service/helpers/sync_message_serializer.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Implementation of sync communication service for WebSocket-based sync operations
///
/// This service orchestrates sync communication by delegating to specialized helpers:
/// - [SyncDtoSerializer] for DTO-to-JSON conversion
/// - [SyncMessageSerializer] for WebSocket message handling
class SyncCommunicationService implements ISyncCommunicationService {
  static const int _defaultWebsocketPort = 44040;

  final SyncDtoSerializer _dtoSerializer = SyncDtoSerializer();
  final SyncMessageSerializer _messageSerializer = SyncMessageSerializer();
  final int _maxRetries;
  final Duration _baseTimeout;
  final Duration Function(int attempt) _retryBackoff;
  final int _websocketPort;

  SyncCommunicationService({
    int maxRetries = 3,
    Duration baseTimeout = const Duration(seconds: 15),
    Duration Function(int attempt)? retryBackoff,
    int websocketPort = _defaultWebsocketPort,
  })  : _maxRetries = maxRetries,
        _baseTimeout = baseTimeout,
        _retryBackoff = retryBackoff ?? _defaultRetryBackoff,
        _websocketPort = websocketPort {
    Logger.info('SyncCommunicationService initialized');
  }

  static Duration _defaultRetryBackoff(int attempt) => Duration(seconds: attempt * 2);

  @override
  Future<SyncCommunicationResponse> sendPaginatedDataToDevice(String ipAddress, PaginatedSyncDataDto dto) async {
    final entityType = dto.entityType;
    final pageIndex = dto.pageIndex;
    final startTime = DateTime.now();
    int attempt = 0;

    Logger.info('Starting paginated sync transmission to $ipAddress:$_websocketPort');
    Logger.debug('Sending: entity=$entityType, page=$pageIndex');

    while (attempt < _maxRetries) {
      WebSocket? socket;
      try {
        final timeout = _baseTimeout * (attempt + 1);
        socket = await WebSocket.connect(getWebSocketUrl(ipAddress)).timeout(timeout);

        final response = await _executeSync(
          socket: socket,
          dto: dto,
          entityType: entityType,
          timeout: timeout,
          attempt: attempt,
          startTime: startTime,
        );

        // Close our end explicitly. A sync of ~250 pages opens a connection
        // per page; leaving the successful ones for the peer to tear down
        // holds sockets open against the server's connection limits longer
        // than necessary.
        await socket.close();
        return response;
      } catch (e) {
        attempt++;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        Logger.warning('WebSocket attempt $attempt failed after ${totalTime}ms: $e');

        _closeSocket(socket);

        if (attempt >= _maxRetries) {
          Logger.error('All WebSocket attempts failed. Final error: $e');
          return SyncCommunicationResponse(
            success: false,
            isComplete: true,
            error: 'All retry attempts failed: $e',
          );
        }

        final backoffDelay = _retryBackoff(attempt);
        Logger.debug('Waiting ${backoffDelay.inSeconds}s before retry...');
        await Future.delayed(backoffDelay);
      }
    }

    return SyncCommunicationResponse(
      success: false,
      isComplete: true,
      error: 'Sync operation failed',
    );
  }

  /// Executes the sync operation on an established WebSocket connection
  Future<SyncCommunicationResponse> _executeSync({
    required WebSocket socket,
    required PaginatedSyncDataDto dto,
    required String entityType,
    required Duration timeout,
    required int attempt,
    required DateTime startTime,
  }) async {
    final completer = Completer<SyncCommunicationResponse>();
    unawaited(completer.future.then<void>((_) {}, onError: (_, __) {}));
    late final Timer timeoutTimer;

    timeoutTimer = Timer(timeout, () async {
      if (completer.isCompleted) return;

      final message = 'WebSocket timeout after ${timeout.inSeconds} seconds (attempt ${attempt + 1}/$_maxRetries)';
      Logger.error('⏰ $message');
      completer.completeError(TimeoutException(message, timeout));
      _closeSocket(socket);
    });

    // Convert DTO to JSON
    final startJsonTime = DateTime.now();
    Logger.debug('Converting DTO to JSON for transmission');
    await _yieldToUIThread();

    final dtoJson = await _dtoSerializer.convertDtoToJson(dto);
    final jsonTime = DateTime.now().difference(startJsonTime).inMilliseconds;
    Logger.debug('DTO to JSON conversion completed in ${jsonTime}ms');

    await _yieldToUIThread();

    // Serialize message
    Logger.debug('Serializing WebSocket message');
    final message = WebSocketMessage(type: 'paginated_sync', data: dtoJson);
    final serializedMessage = await _messageSerializer.serializeMessage(message);

    await _yieldToUIThread();

    // Validate before sending
    if (!_messageSerializer.validateMessageIntegrity(dtoJson, entityType)) {
      Logger.error('Pre-transmission validation failed');
      throw Exception('Pre-transmission validation failed');
    }

    // Send message
    final transmissionStartTime = DateTime.now();
    Logger.debug('Sending message via WebSocket (${serializedMessage.length} bytes)');
    socket.add(serializedMessage);

    socket.listen((responseMessage) async {
      if (completer.isCompleted) return;

      try {
        final responseTime = DateTime.now().difference(transmissionStartTime).inMilliseconds;
        Logger.debug(
            'Received WebSocket response (${responseMessage.toString().length} bytes) - Response time: ${responseTime}ms');
        await _yieldToUIThread();

        final response = await _processResponse(responseMessage, timeoutTimer, startTime);
        if (response != null) {
          if (!completer.isCompleted) {
            completer.complete(response);
          }
        }
      } catch (e) {
        Logger.error('Error processing WebSocket response: $e');
        if (!completer.isCompleted) {
          completer.complete(SyncCommunicationResponse(
            success: false,
            isComplete: true,
            error: 'Operation failed',
          ));
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  /// Processes a WebSocket response message
  Future<SyncCommunicationResponse?> _processResponse(
    dynamic message,
    Timer timeoutTimer,
    DateTime startTime,
  ) async {
    final receivedMessage = await _messageSerializer.deserializeMessage(message);

    if (receivedMessage == null) {
      Logger.error('Failed to deserialize WebSocket message');
      return SyncCommunicationResponse(
        success: false,
        isComplete: true,
        error: 'Operation failed',
      );
    }

    Logger.debug('✓ Successfully deserialized message type: ${receivedMessage.type}');
    await _yieldToUIThread();

    if (receivedMessage.type == 'paginated_sync_complete' || receivedMessage.type == 'paginated_sync') {
      timeoutTimer.cancel();
      return _handleSyncResponse(receivedMessage, startTime);
    } else if (receivedMessage.type == 'error') {
      timeoutTimer.cancel();
      final error = receivedMessage.data?['message'] ?? 'Unknown error';
      Logger.error('Server error during sync: $error');
      return SyncCommunicationResponse(
        success: false,
        isComplete: true,
        error: 'Operation failed',
      );
    }

    return null; // Continue listening for correct message type
  }

  /// Handles a successful sync response
  SyncCommunicationResponse _handleSyncResponse(WebSocketMessage receivedMessage, DateTime startTime) {
    if (receivedMessage.data is! Map<String, dynamic>) {
      Logger.error('Invalid response data structure');
      return SyncCommunicationResponse(
        success: false,
        isComplete: true,
        error: 'Operation failed',
      );
    }

    final responseData = receivedMessage.data as Map<String, dynamic>;
    final success = responseData['success'] as bool? ?? false;
    final isComplete = responseData['isComplete'] as bool? ?? true;

    if (success) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      Logger.info('Paginated sync transmission successful (${totalTime}ms total)');
      if (!isComplete) {
        Logger.info('Server indicates bidirectional sync needed (isComplete: false)');
      }

      PaginatedSyncDataDto? serverResponseData;
      final paginatedSyncDataDto = responseData['paginatedSyncDataDto'];
      if (paginatedSyncDataDto != null) {
        try {
          serverResponseData = PaginatedSyncDataDto.fromJson(paginatedSyncDataDto as Map<String, dynamic>);
          Logger.info('Received server response data with ${serverResponseData.entityType} entities');
        } catch (e) {
          Logger.error('Failed to parse server response data: $e');
        }
      }

      return SyncCommunicationResponse(
        success: true,
        isComplete: isComplete,
        responseData: serverResponseData,
      );
    } else {
      final error = responseData['error'] as String? ?? 'Unknown error';
      Logger.error('Server reported sync failure: $error');
      return SyncCommunicationResponse(
        success: false,
        isComplete: true,
        error: error,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> convertDtoToJson(PaginatedSyncDataDto dto) async {
    return _dtoSerializer.convertDtoToJson(dto);
  }

  @override
  Future<String> serializeMessage(WebSocketMessage message) async {
    return _messageSerializer.serializeMessage(message);
  }

  @override
  Future<bool> isDeviceReachable(String ipAddress) async {
    try {
      final socket = await WebSocket.connect(getWebSocketUrl(ipAddress)).timeout(const Duration(seconds: 5));
      await socket.close();
      return true;
    } catch (e) {
      Logger.debug('Device $ipAddress is not reachable: $e');
      return false;
    }
  }

  @override
  String getWebSocketUrl(String ipAddress) {
    return 'ws://$ipAddress:$_websocketPort';
  }

  @override
  Future<bool> handleConnectionError(String ipAddress, Exception error) async {
    Logger.warning('WebSocket connection error to $ipAddress: $error');

    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(seconds: (i + 1) * 2));

      if (await isDeviceReachable(ipAddress)) {
        Logger.info('Connection to $ipAddress recovered after ${i + 1} retries');
        return true;
      }
    }

    Logger.error('Failed to recover connection to $ipAddress after 3 retries');
    return false;
  }

  Future<void> _yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }

  void _closeSocket(WebSocket? socket) {
    if (socket == null) return;

    unawaited(socket.close().catchError((Object error, StackTrace stackTrace) {
      Logger.warning('Failed to close WebSocket: $error');
    }));
  }
}
