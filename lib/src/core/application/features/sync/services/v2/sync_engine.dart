import 'package:whph/src/core/application/features/sync/models/v2/sync_message.dart';
import 'package:whph/src/core/application/features/sync/models/v2/sync_data.dart';
import 'package:whph/src/core/application/features/sync/registry/sync_entity_registry.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// New generic sync engine - replaces the 40,000+ line monolithic command
class SyncEngine {
  final SyncEntityRegistry _registry;
  static const int _defaultPageSize = 100;

  SyncEngine(this._registry);

  /// Initiate sync for a specific entity type
  Future<SyncMessage> createSyncMessage({
    required String entityType,
    required SyncDevice syncDevice,
    required DateTime lastSyncDate,
    int pageIndex = 0,
    int pageSize = _defaultPageSize,
  }) async {
    Logger.info('🔄 SyncEngine: Creating sync message for $entityType (page $pageIndex)');

    try {
      // Get entity descriptor
      final descriptor = _registry.getDescriptor(entityType);
      if (descriptor == null) {
        throw SyncEngineException('Entity descriptor not found for $entityType');
      }

      // Get sync data from descriptor
      final syncData = await descriptor.getPaginatedSyncData(
        lastSyncDate,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );

      // Create unified sync message
      final message = SyncMessage.syncData(
        entityType: entityType,
        appVersion: AppInfo.version,
        syncDevice: syncDevice,
        syncData: syncData.toJson(descriptor.serialize),
      );

      Logger.info('🔄 SyncEngine: Created sync message for $entityType with ${syncData.itemCount} items');
      return message;

    } catch (e, stackTrace) {
      Logger.error('🔄 SyncEngine: Error creating sync message for $entityType: $e');
      Logger.error('StackTrace: $stackTrace');

      // Return error message
      return SyncMessage.error(
        entityType: entityType,
        appVersion: AppInfo.version,
        syncDevice: syncDevice,
        errorMessage: e.toString(),
        errorCode: 'SYNC_CREATE_ERROR',
      );
    }
  }

  /// Process incoming sync message
  Future<SyncMessage> processSyncMessage(SyncMessage message) async {
    Logger.info('🔄 SyncEngine: Processing sync message ${message.messageId} for ${message.entityType}');

    try {
      switch (message.type) {
        case SyncMessageType.syncData:
          return await _processSyncData(message);
        
        case SyncMessageType.connectivityTest:
          return await _processConnectivityTest(message);
        
        case SyncMessageType.error:
          Logger.error('🔄 SyncEngine: Received error message: ${message.data['errorMessage']}');
          return _createAckMessage(message);
        
        case SyncMessageType.ack:
          Logger.debug('🔄 SyncEngine: Received acknowledgment for ${message.messageId}');
          return _createAckMessage(message);
      }
    } catch (e, stackTrace) {
      Logger.error('🔄 SyncEngine: Error processing sync message ${message.messageId}: $e');
      Logger.error('StackTrace: $stackTrace');

      return SyncMessage.error(
        entityType: message.entityType,
        appVersion: AppInfo.version,
        syncDevice: message.syncDevice,
        errorMessage: e.toString(),
        errorCode: 'SYNC_PROCESS_ERROR',
      );
    }
  }

  /// Process sync data message
  Future<SyncMessage> _processSyncData(SyncMessage message) async {
    final entityType = message.entityType;
    Logger.debug('🔄 SyncEngine: Processing sync data for $entityType');

    // Get entity descriptor
    final descriptor = _registry.getDescriptor(entityType);
    if (descriptor == null) {
      throw SyncEngineException('Entity descriptor not found for $entityType');
    }

    // Deserialize sync data
    final syncData = SyncData.fromJson(
      message.data,
      descriptor.deserialize,
    );

    // Process the sync data
    await descriptor.processSyncData(syncData);

    // Create acknowledgment
    return _createAckMessage(message);
  }

  /// Process connectivity test
  Future<SyncMessage> _processConnectivityTest(SyncMessage message) async {
    Logger.debug('🔄 SyncEngine: Processing connectivity test');

    return SyncMessage.fromJson({
      'messageId': _generateMessageId(),
      'type': SyncMessageType.ack.value,
      'entityType': message.entityType,
      'appVersion': AppInfo.version,
      'syncDevice': message.syncDevice.toJson(),
      'data': {
        'originalMessageId': message.messageId,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'connectivity_ok',
      },
    });
  }

  /// Create acknowledgment message
  SyncMessage _createAckMessage(SyncMessage originalMessage) {
    return SyncMessage.fromJson({
      'messageId': _generateMessageId(),
      'type': SyncMessageType.ack.value,
      'entityType': originalMessage.entityType,
      'appVersion': AppInfo.version,
      'syncDevice': originalMessage.syncDevice.toJson(),
      'data': {
        'originalMessageId': originalMessage.messageId,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'processed',
      },
    });
  }

  /// Get all registered entity types
  List<String> get registeredEntityTypes => _registry.entityTypes;

  /// Get registry summary
  String get registrySummary => _registry.summary;

  /// Generate unique message ID
  static String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'sync_${timestamp}_$random';
  }
}

/// Sync engine specific exception
class SyncEngineException implements Exception {
  final String message;
  final String? code;

  SyncEngineException(this.message, [this.code]);

  @override
  String toString() => 'SyncEngineException: $message${code != null ? ' (code: $code)' : ''}';
}