import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';

/// Response from sending paginated sync data
class SyncCommunicationResponse {
  final bool success;
  final bool isComplete;
  final String? error;
  final PaginatedSyncDataDto? responseData;

  SyncCommunicationResponse({
    required this.success,
    required this.isComplete,
    this.error,
    this.responseData,
  });
}

/// Service responsible for managing sync communication with remote devices
abstract class ISyncCommunicationService {
  /// Sends paginated sync data to a remote device via WebSocket
  ///
  /// Returns communication response with success status and completion flag
  Future<SyncCommunicationResponse> sendPaginatedDataToDevice(String ipAddress, PaginatedSyncDataDto dto);

  /// Converts a PaginatedSyncDataDto to JSON format with proper yielding for UI responsiveness
  ///
  /// Returns the JSON representation of the DTO
  Future<Map<String, dynamic>> convertDtoToJson(PaginatedSyncDataDto dto);

  /// Serializes a WebSocket message with yielding to prevent UI blocking
  ///
  /// Returns the serialized message string
  Future<String> serializeMessage(WebSocketMessage message);

  /// Checks if a device is reachable at the given IP address
  ///
  /// Returns true if the device responds, false otherwise
  Future<bool> isDeviceReachable(String ipAddress);

  /// Gets the WebSocket endpoint URL for a given IP address
  ///
  /// Returns the formatted WebSocket URL
  String getWebSocketUrl(String ipAddress);

  /// Handles WebSocket connection errors and implements retry logic
  ///
  /// Returns true if connection was recovered, false otherwise
  Future<bool> handleConnectionError(String ipAddress, Exception error);
}
