import 'package:whph/src/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';

/// Unified sync message format - replaces the 17-field PaginatedSyncDataDto
class SyncMessage {
  final String messageId;
  final SyncMessageType type;
  final String entityType;
  final String appVersion;
  final SyncDevice syncDevice;
  final SyncProgress? progress;
  final Map<String, dynamic> data;

  const SyncMessage({
    required this.messageId,
    required this.type,
    required this.entityType,
    required this.appVersion,
    required this.syncDevice,
    this.progress,
    required this.data,
  });

  /// Create sync data message
  factory SyncMessage.syncData({
    required String entityType,
    required String appVersion,
    required SyncDevice syncDevice,
    required Map<String, dynamic> syncData,
    SyncProgress? progress,
  }) {
    return SyncMessage(
      messageId: _generateMessageId(),
      type: SyncMessageType.syncData,
      entityType: entityType,
      appVersion: appVersion,
      syncDevice: syncDevice,
      progress: progress,
      data: syncData,
    );
  }

  /// Create connectivity test message
  factory SyncMessage.connectivityTest({
    required String appVersion,
    required SyncDevice syncDevice,
  }) {
    return SyncMessage(
      messageId: _generateMessageId(),
      type: SyncMessageType.connectivityTest,
      entityType: 'system',
      appVersion: appVersion,
      syncDevice: syncDevice,
      data: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Create error response
  factory SyncMessage.error({
    required String entityType,
    required String appVersion,
    required SyncDevice syncDevice,
    required String errorMessage,
    String? errorCode,
  }) {
    return SyncMessage(
      messageId: _generateMessageId(),
      type: SyncMessageType.error,
      entityType: entityType,
      appVersion: appVersion,
      syncDevice: syncDevice,
      data: {
        'errorMessage': errorMessage,
        'errorCode': errorCode,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'type': type.value,
      'entityType': entityType,
      'appVersion': appVersion,
      'syncDevice': syncDevice.toJson(),
      'progress': progress?.toJson(),
      'data': data,
    };
  }

  /// Create from JSON
  factory SyncMessage.fromJson(Map<String, dynamic> json) {
    return SyncMessage(
      messageId: json['messageId'] as String,
      type: SyncMessageType.fromValue(json['type'] as String),
      entityType: json['entityType'] as String,
      appVersion: json['appVersion'] as String,
      syncDevice: SyncDevice.fromJson(json['syncDevice'] as Map<String, dynamic>),
      progress: json['progress'] != null 
          ? SyncProgress.fromJson(json['progress'] as Map<String, dynamic>)
          : null,
      data: json['data'] as Map<String, dynamic>,
    );
  }

  /// Generate unique message ID
  static String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'sync_${timestamp}_$random';
  }

  @override
  String toString() => 'SyncMessage(id: $messageId, type: ${type.value}, entity: $entityType)';
}

/// Sync message types
enum SyncMessageType {
  syncData('sync_data'),
  connectivityTest('connectivity_test'),
  error('error'),
  ack('acknowledgment');

  const SyncMessageType(this.value);
  final String value;

  static SyncMessageType fromValue(String value) {
    return SyncMessageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Unknown sync message type: $value'),
    );
  }
}