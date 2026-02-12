import 'package:application/shared/models/websocket_request.dart';
import 'package:domain/shared/utils/logger.dart';

const int maxMessageSizeBytes = 1024 * 1024;

/// Message types supported by the desktop sync server
const validMessageTypes = {
  'device_info',
  'test',
  'client_connect',
  'heartbeat',
  'sync',
  'paginated_sync_start',
  'paginated_sync_request',
  'paginated_sync',
};

/// Validates WebSocket messages for the desktop sync server.
class WebSocketMessageValidator {
  const WebSocketMessageValidator();

  /// Validate message size
  bool isMessageSizeValid(String message) {
    if (message.length > maxMessageSizeBytes) {
      DomainLogger.warning('Message rejected: size ${message.length} exceeds limit $maxMessageSizeBytes');
      return false;
    }
    return true;
  }

  /// Validate WebSocket message structure
  bool isValidWebSocketMessage(WebSocketMessage message) {
    if (message.type.isEmpty) return false;

    if (!validMessageTypes.contains(message.type)) {
      DomainLogger.debug('Unknown message type: ${message.type}');
      return false;
    }

    return true;
  }
}
