import 'package:whph/src/core/application/features/sync/models/v3/sync_protocol.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';

/// Bidirectional sync message - supports persistent WebSocket communication
class BidirectionalSyncMessage {
  final String messageId;
  final String sessionId;
  final SyncPhase phase;
  final SyncRole senderRole;
  final String entityType;
  final String appVersion;
  final SyncDevice syncDevice;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const BidirectionalSyncMessage({
    required this.messageId,
    required this.sessionId,
    required this.phase,
    required this.senderRole,
    required this.entityType,
    required this.appVersion,
    required this.syncDevice,
    required this.timestamp,
    required this.payload,
  });

  /// Create Phase 1 Init message
  factory BidirectionalSyncMessage.phase1Init({
    required String sessionId,
    required SyncRole senderRole,
    required SyncDevice syncDevice,
    required Map<String, int> expectedDataCounts,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.phase1Init,
      senderRole: senderRole,
      entityType: 'system',
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'expectedDataCounts': expectedDataCounts,
        'message': 'Starting Phase 1: Data Exchange',
      },
    );
  }

  /// Create Phase 1 Data message
  factory BidirectionalSyncMessage.phase1Data({
    required String sessionId,
    required SyncRole senderRole,
    required String entityType,
    required SyncDevice syncDevice,
    required Map<String, dynamic> syncData,
    required int pageIndex,
    required int totalPages,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.phase1Data,
      senderRole: senderRole,
      entityType: entityType,
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'syncData': syncData,
        'pageIndex': pageIndex,
        'totalPages': totalPages,
        'isLastPage': pageIndex >= totalPages - 1,
      },
    );
  }

  /// Create Phase 1 Complete message
  factory BidirectionalSyncMessage.phase1Complete({
    required String sessionId,
    required SyncRole senderRole,
    required SyncDevice syncDevice,
    required Map<String, int> receivedDataCounts,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.phase1Complete,
      senderRole: senderRole,
      entityType: 'system',
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'receivedDataCounts': receivedDataCounts,
        'message': 'Phase 1 completed: All data buffered in memory',
      },
    );
  }

  /// Create Phase 2 Init message
  factory BidirectionalSyncMessage.phase2Init({
    required String sessionId,
    required SyncRole senderRole,
    required SyncDevice syncDevice,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.phase2Init,
      senderRole: senderRole,
      entityType: 'system',
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'message': 'Starting Phase 2: Controlled Write-Back',
      },
    );
  }

  /// Create Phase 2 Commit message
  factory BidirectionalSyncMessage.phase2Commit({
    required String sessionId,
    required SyncRole senderRole,
    required SyncDevice syncDevice,
    required Map<String, int> writtenCounts,
    required bool success,
    String? errorMessage,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.phase2Commit,
      senderRole: senderRole,
      entityType: 'system',
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'writtenCounts': writtenCounts,
        'success': success,
        'errorMessage': errorMessage,
        'message': success 
            ? 'Phase 2 commit successful: Data written to database'
            : 'Phase 2 commit failed: $errorMessage',
      },
    );
  }

  /// Create Sync Complete message
  factory BidirectionalSyncMessage.syncComplete({
    required String sessionId,
    required SyncRole senderRole,
    required SyncDevice syncDevice,
    required Duration elapsedTime,
    required int totalItemsProcessed,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.syncComplete,
      senderRole: senderRole,
      entityType: 'system',
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'elapsedTimeMs': elapsedTime.inMilliseconds,
        'totalItemsProcessed': totalItemsProcessed,
        'message': 'Sync completed successfully',
      },
    );
  }

  /// Create Error/Rollback message
  factory BidirectionalSyncMessage.syncFailed({
    required String sessionId,
    required SyncRole senderRole,
    required SyncDevice syncDevice,
    required String errorMessage,
    required String errorCode,
    SyncPhase? failedAtPhase,
  }) {
    return BidirectionalSyncMessage(
      messageId: _generateMessageId(),
      sessionId: sessionId,
      phase: SyncPhase.syncFailed,
      senderRole: senderRole,
      entityType: 'system',
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      timestamp: DateTime.now(),
      payload: {
        'errorMessage': errorMessage,
        'errorCode': errorCode,
        'failedAtPhase': failedAtPhase?.value,
        'message': 'Sync failed: $errorMessage',
      },
    );
  }

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'sessionId': sessionId,
      'phase': phase.value,
      'senderRole': senderRole.value,
      'entityType': entityType,
      'appVersion': appVersion,
      'syncDevice': syncDevice.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  /// Create from JSON
  factory BidirectionalSyncMessage.fromJson(Map<String, dynamic> json) {
    return BidirectionalSyncMessage(
      messageId: json['messageId'] as String,
      sessionId: json['sessionId'] as String,
      phase: SyncPhase.fromValue(json['phase'] as String),
      senderRole: SyncRole.fromValue(json['senderRole'] as String),
      entityType: json['entityType'] as String,
      appVersion: json['appVersion'] as String,
      syncDevice: SyncDevice.fromJson(json['syncDevice'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  /// Generate unique message ID
  static String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'bsync_${timestamp}_$random';
  }

  /// Check if message is a system control message
  bool get isSystemMessage => entityType == 'system';

  /// Check if message contains actual sync data
  bool get hasDataPayload => payload.containsKey('syncData');

  /// Get sync data from payload (if exists)
  Map<String, dynamic>? get syncData => payload['syncData'] as Map<String, dynamic>?;

  /// Get message age
  Duration get age => DateTime.now().difference(timestamp);

  @override
  String toString() => 'BidirectionalSyncMessage(id: $messageId, session: $sessionId, phase: ${phase.value}, role: ${senderRole.value}, entity: $entityType)';
}