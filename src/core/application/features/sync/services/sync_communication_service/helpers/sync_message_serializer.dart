import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:domain/shared/utils/logger.dart';

/// Handles WebSocket message serialization and deserialization
class SyncMessageSerializer {
  /// Serializes a WebSocket message with isolate support for large payloads
  Future<String> serializeMessage(WebSocketMessage message) async {
    DomainLogger.debug('Starting WebSocket message serialization');
    await _yieldToUIThread();

    try {
      final messageData = message.data;
      if (messageData is Map<String, dynamic>) {
        final estimatedSize = _estimateJsonDataSize(messageData);

        if (estimatedSize > 200) {
          DomainLogger.debug('Using isolate for large WebSocket message serialization ($estimatedSize items)');
          try {
            return await compute(_serializeMessageInIsolate, {
              'type': message.type,
              'data': messageData,
            });
          } catch (e) {
            DomainLogger.warning('Isolate serialization failed, using main thread: $e');
          }
        }
      }

      // Fallback to main thread with yielding
      await _yieldToUIThread();

      final result = json.encode(message.toJson());

      DomainLogger.debug('WebSocket message serialization completed');
      return result;
    } catch (e) {
      DomainLogger.error('WebSocket message serialization failed: $e');
      rethrow;
    }
  }

  /// Deserializes a WebSocket message from raw data
  Future<WebSocketMessage?> deserializeMessage(dynamic message) async {
    try {
      await _yieldToUIThread();

      final messageString = message.toString();
      final messageMap = json.decode(messageString) as Map<String, dynamic>;

      return WebSocketMessage(
        type: messageMap['type'] as String,
        data: messageMap['data'],
      );
    } catch (e) {
      DomainLogger.error('Failed to deserialize WebSocket message: $e');
      return null;
    }
  }

  /// Validates message integrity before transmission
  bool validateMessageIntegrity(Map<String, dynamic> data, String entityType) {
    try {
      if (data.isEmpty) return false;
      if (!data.containsKey('entityType')) return false;
      if (data['entityType'] != entityType) return false;

      DomainLogger.debug('Message integrity validation passed');
      return true;
    } catch (e) {
      DomainLogger.error('Message integrity validation failed: $e');
      return false;
    }
  }

  /// Estimates JSON data size for choosing processing strategy
  int _estimateJsonDataSize(Map<String, dynamic> data) {
    int size = data.length;
    for (final value in data.values) {
      if (value is List) {
        size += value.length;
      } else if (value is Map) {
        size += value.length;
      }
    }
    return size;
  }

  Future<void> _yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }

  // Static isolate function for message serialization
  static String _serializeMessageInIsolate(Map<String, dynamic> messageData) {
    try {
      final type = messageData['type'] as String?;
      if (type == null) {
        throw ArgumentError('Message type is required and cannot be null');
      }

      final data = messageData['data'];

      final message = {
        'type': type,
        'data': data,
      };

      return json.encode(message);
    } catch (e) {
      rethrow;
    }
  }
}
