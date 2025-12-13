import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Handles WebSocket connection management and communication
class SyncWebSocketClient {
  static const int maxRetries = 3;
  static const int baseTimeoutSeconds = 15;
  static const int websocketPort = 44040;

  /// Gets the WebSocket endpoint URL for a given IP address
  String getWebSocketUrl(String ipAddress) {
    return 'ws://$ipAddress:$websocketPort';
  }

  /// Checks if a device is reachable at the given IP address
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

  /// Handles WebSocket connection errors with retry logic
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

  /// Establishes a WebSocket connection with timeout
  Future<WebSocket> connect(String ipAddress, {int attempt = 0}) async {
    final timeout = Duration(seconds: baseTimeoutSeconds * (attempt + 1));
    return await WebSocket.connect(getWebSocketUrl(ipAddress)).timeout(timeout);
  }

  /// Sends serialized data and waits for response
  Future<SyncCommunicationResponse> sendAndReceive({
    required String ipAddress,
    required String serializedMessage,
    required String entityType,
    required int pageIndex,
    required int attempt,
  }) async {
    final timeout = Duration(seconds: baseTimeoutSeconds * (attempt + 1));
    WebSocket? socket;

    try {
      socket = await connect(ipAddress, attempt: attempt);

      final completer = Completer<SyncCommunicationResponse>();
      Timer? timeoutTimer;

      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          Logger.error('⏰ WebSocket timeout after ${timeout.inSeconds} seconds (attempt ${attempt + 1}/$maxRetries)');
          completer.complete(SyncCommunicationResponse(
            success: false,
            isComplete: true,
            error: 'Operation failed',
          ));
          socket?.close();
        }
      });

      Logger.debug('Sending message via WebSocket (${serializedMessage.length} bytes)');
      socket.add(serializedMessage);

      await for (final message in socket) {
        final response = await _processResponse(message, timeoutTimer);
        if (response != null) {
          completer.complete(response);
          break;
        }
      }

      return await completer.future;
    } finally {
      await socket?.close();
    }
  }

  /// Processes WebSocket response message
  Future<SyncCommunicationResponse?> _processResponse(dynamic message, Timer timeoutTimer) async {
    try {
      Logger.debug('Received WebSocket response (${message.toString().length} bytes)');

      final messageMap = _parseMessage(message);
      if (messageMap == null) {
        return SyncCommunicationResponse(
          success: false,
          isComplete: true,
          error: 'Failed to parse response',
        );
      }

      final type = messageMap['type'] as String?;
      final data = messageMap['data'] as Map<String, dynamic>?;

      if (type == 'paginated_sync_complete' || type == 'paginated_sync') {
        timeoutTimer.cancel();

        if (data == null) {
          return SyncCommunicationResponse(
            success: false,
            isComplete: true,
            error: 'Invalid response data structure',
          );
        }

        final success = data['success'] as bool? ?? false;
        final isComplete = data['isComplete'] as bool? ?? true;

        if (success) {
          Logger.info('Paginated sync transmission successful');
          if (!isComplete) {
            Logger.info('Server indicates bidirectional sync needed (isComplete: false)');
          }

          PaginatedSyncDataDto? serverResponseData;
          final paginatedSyncDataDto = data['paginatedSyncDataDto'];
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
          final error = data['error'] as String? ?? 'Unknown error';
          Logger.error('Server reported sync failure: $error');
          return SyncCommunicationResponse(
            success: false,
            isComplete: true,
            error: error,
          );
        }
      } else if (type == 'error') {
        timeoutTimer.cancel();
        final error = data?['message'] ?? 'Unknown error';
        Logger.error('Server error during sync: $error');
        return SyncCommunicationResponse(
          success: false,
          isComplete: true,
          error: 'Operation failed',
        );
      }

      return null; // Continue waiting for correct message type
    } catch (e) {
      Logger.error('Error processing WebSocket response: $e');
      return SyncCommunicationResponse(
        success: false,
        isComplete: true,
        error: 'Operation failed',
      );
    }
  }

  /// Parses raw message to Map
  Map<String, dynamic>? _parseMessage(dynamic message) {
    try {
      final messageString = message.toString();
      return Map<String, dynamic>.from(
        (message is String ? message : messageString).isEmpty ? {} : _decodeJson(messageString),
      );
    } catch (e) {
      Logger.error('Failed to parse WebSocket message: $e');
      return null;
    }
  }

  dynamic _decodeJson(String jsonString) {
    try {
      return json.decode(jsonString);
    } catch (e) {
      return {};
    }
  }
}
