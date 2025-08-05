import 'dart:async';
import 'package:whph/src/core/application/features/sync/models/v3/sync_protocol.dart';
import 'package:whph/src/core/application/features/sync/models/v3/bidirectional_sync_message.dart';
import 'package:whph/src/core/application/features/sync/services/v3/sync_memory_buffer.dart';
import 'package:whph/src/core/application/features/sync/registry/sync_entity_registry.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// Two-Phase Bidirectional Sync Engine
/// 
/// Phase 1: Data Exchange (Memory Only)
/// - Both sides exchange all data to memory buffers
/// - No database writes during this phase
/// - Atomic data collection
/// 
/// Phase 2: Controlled Write-Back  
/// - Both sides write buffered data to database
/// - Atomic transaction-based writes
/// - Rollback capability on failure
class BidirectionalSyncEngine {
  final SyncEntityRegistry _registry;
  final Map<String, SyncSession> _activeSessions = {};
  final Map<String, SyncMemoryBuffer> _memoryBuffers = {};
  final StreamController<BidirectionalSyncMessage> _outgoingMessages = StreamController.broadcast();
  final StreamController<SyncSession> _sessionUpdates = StreamController.broadcast();

  BidirectionalSyncEngine(this._registry);

  /// Stream of outgoing messages
  Stream<BidirectionalSyncMessage> get outgoingMessages => _outgoingMessages.stream;

  /// Stream of session updates
  Stream<SyncSession> get sessionUpdates => _sessionUpdates.stream;

  /// Initiate sync as the primary device
  Future<String> initiateBidirectionalSync({
    required SyncDevice syncDevice,
    required String remoteDeviceId,
    required DateTime lastSyncDate,
  }) async {
    Logger.info('🔄 BidirectionalSyncEngine: Initiating sync as INITIATOR');

    try {
      // Create new sync session
      final session = SyncSession.create(
        role: SyncRole.initiator,
        remoteDeviceId: remoteDeviceId,
      );

      // Create memory buffer
      final memoryBuffer = SyncMemoryBuffer(session.sessionId);
      
      // Store session and buffer
      _activeSessions[session.sessionId] = session;
      _memoryBuffers[session.sessionId] = memoryBuffer;

      // Calculate expected data counts for all entities
      final expectedDataCounts = <String, int>{};
      for (final entityType in _registry.entityTypes) {
        final descriptor = _registry.getDescriptor(entityType);
        if (descriptor != null) {
          final syncData = await descriptor.getPaginatedSyncData(
            lastSyncDate,
            pageIndex: 0,
            pageSize: 1000, // Large page size for counting
          );
          expectedDataCounts[entityType] = syncData.totalItems;
          
          // Prepare memory buffer for this entity
          memoryBuffer.addEntityBuffer(entityType);
        }
      }

      // Update session with expected counts
      final updatedSession = session.updateDataCounts(expected: expectedDataCounts);
      _activeSessions[session.sessionId] = updatedSession;
      _sessionUpdates.add(updatedSession);

      // Send Phase 1 Init message
      final initMessage = BidirectionalSyncMessage.phase1Init(
        sessionId: session.sessionId,
        senderRole: SyncRole.initiator,
        syncDevice: syncDevice,
        expectedDataCounts: expectedDataCounts,
      );

      _outgoingMessages.add(initMessage);
      Logger.info('🔄 BidirectionalSyncEngine: Sent Phase 1 Init for session ${session.sessionId}');

      return session.sessionId;

    } catch (e, stackTrace) {
      Logger.error('🔄 BidirectionalSyncEngine: Failed to initiate sync: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Process incoming bidirectional sync message
  Future<void> processIncomingMessage(BidirectionalSyncMessage message) async {
    Logger.debug('🔄 BidirectionalSyncEngine: Processing ${message.phase.value} message from ${message.senderRole.value}');

    try {
      switch (message.phase) {
        case SyncPhase.phase1Init:
          await _handlePhase1Init(message);
          break;
          
        case SyncPhase.phase1Data:
          await _handlePhase1Data(message);
          break;
          
        case SyncPhase.phase1Complete:
          await _handlePhase1Complete(message);
          break;
          
        case SyncPhase.phase2Init:
          await _handlePhase2Init(message);
          break;
          
        case SyncPhase.phase2Commit:
          await _handlePhase2Commit(message);
          break;
          
        case SyncPhase.phase2Complete:
          await _handlePhase2Complete(message);
          break;
          
        case SyncPhase.syncComplete:
          await _handleSyncComplete(message);
          break;
          
        case SyncPhase.syncFailed:
          await _handleSyncFailed(message);
          break;
          
        case SyncPhase.syncRollback:
          await _handleSyncRollback(message);
          break;
      }
    } catch (e, stackTrace) {
      Logger.error('🔄 BidirectionalSyncEngine: Error processing message ${message.messageId}: $e');
      Logger.error('StackTrace: $stackTrace');
      
      // Send failure message
      await _sendFailureMessage(message.sessionId, message.syncDevice, e.toString());
    }
  }

  /// Handle Phase 1 Init - Respond as RESPONDER
  Future<void> _handlePhase1Init(BidirectionalSyncMessage message) async {
    Logger.info('🔄 BidirectionalSyncEngine: Handling Phase 1 Init as RESPONDER');

    // Create response session with same session ID as initiator

    // Use the same session ID as initiator
    final responseSession = SyncSession(
      sessionId: message.sessionId,
      currentPhase: SyncPhase.phase1Init,
      myRole: SyncRole.responder,
      remoteDeviceId: message.syncDevice.fromDeviceId,
      startTime: DateTime.now(),
    );

    // Create memory buffer
    final memoryBuffer = SyncMemoryBuffer(message.sessionId);
    
    // Store session and buffer
    _activeSessions[message.sessionId] = responseSession;
    _memoryBuffers[message.sessionId] = memoryBuffer;

    // Prepare our own expected data counts
    final expectedDataCounts = <String, int>{};
    for (final entityType in _registry.entityTypes) {
      final descriptor = _registry.getDescriptor(entityType);
      if (descriptor != null) {
        final syncData = await descriptor.getPaginatedSyncData(
          DateTime(1970, 1, 1), // Full sync for now
          pageIndex: 0,
          pageSize: 1000,
        );
        expectedDataCounts[entityType] = syncData.totalItems;
        
        // Prepare memory buffer
        memoryBuffer.addEntityBuffer(entityType);
      }
    }

    // Send our Phase 1 Init response
    final responseMessage = BidirectionalSyncMessage.phase1Init(
      sessionId: message.sessionId,
      senderRole: SyncRole.responder,
      syncDevice: message.syncDevice, // Use provided sync device
      expectedDataCounts: expectedDataCounts,
    );

    _outgoingMessages.add(responseMessage);
    
    // Update session
    final updatedSession = responseSession.updateDataCounts(expected: expectedDataCounts);
    _activeSessions[message.sessionId] = updatedSession;
    _sessionUpdates.add(updatedSession);

    Logger.info('🔄 BidirectionalSyncEngine: Sent Phase 1 Init response for session ${message.sessionId}');
  }

  /// Handle Phase 1 Data - Buffer incoming data in memory
  Future<void> _handlePhase1Data(BidirectionalSyncMessage message) async {
    Logger.debug('🔄 BidirectionalSyncEngine: Buffering Phase 1 data for ${message.entityType}');

    final memoryBuffer = _memoryBuffers[message.sessionId];
    if (memoryBuffer == null) {
      throw Exception('No memory buffer found for session ${message.sessionId}');
    }

    final syncData = message.syncData;
    if (syncData == null) {
      throw Exception('No sync data in Phase 1 Data message');
    }

    // Buffer the data in memory (don't write to database yet)
    if (syncData['createSync'] != null) {
      final createData = syncData['createSync'] as List;
      memoryBuffer.addBatchData(message.entityType, 'create', 
          createData.cast<Map<String, dynamic>>());
    }

    if (syncData['updateSync'] != null) {
      final updateData = syncData['updateSync'] as List;
      memoryBuffer.addBatchData(message.entityType, 'update', 
          updateData.cast<Map<String, dynamic>>());
    }

    if (syncData['deleteSync'] != null) {
      final deleteData = syncData['deleteSync'] as List;
      memoryBuffer.addBatchData(message.entityType, 'delete', 
          deleteData.cast<Map<String, dynamic>>());
    }

    // Update received counts
    final session = _activeSessions[message.sessionId]!;
    final entityBuffer = memoryBuffer.getEntityBuffer(message.entityType)!;
    final newReceivedCounts = Map<String, int>.from(session.receivedDataCounts);
    newReceivedCounts[message.entityType] = entityBuffer.totalItemCount;

    final updatedSession = session.updateDataCounts(received: newReceivedCounts);
    _activeSessions[message.sessionId] = updatedSession;
    _sessionUpdates.add(updatedSession);

    Logger.debug('🔄 BidirectionalSyncEngine: Buffered ${entityBuffer.totalItemCount} items for ${message.entityType} (${entityBuffer.operationSummary})');
  }

  /// Handle Phase 1 Complete - Check if ready for Phase 2
  Future<void> _handlePhase1Complete(BidirectionalSyncMessage message) async {
    Logger.info('🔄 BidirectionalSyncEngine: Phase 1 Complete received from ${message.senderRole.value}');

    final session = _activeSessions[message.sessionId];
    if (session == null) return;

    // Check if both sides have completed Phase 1
    if (session.isPhase1Complete) {
      Logger.info('🔄 BidirectionalSyncEngine: Both sides ready for Phase 2');
      
      // Initiate Phase 2
      final phase2Message = BidirectionalSyncMessage.phase2Init(
        sessionId: message.sessionId,
        senderRole: session.myRole,
        syncDevice: message.syncDevice,
      );

      _outgoingMessages.add(phase2Message);
      
      // Update session phase
      final updatedSession = session.updatePhase(SyncPhase.phase2Init);
      _activeSessions[message.sessionId] = updatedSession;
      _sessionUpdates.add(updatedSession);
    }
  }

  /// Handle Phase 2 Init - Begin controlled write-back
  Future<void> _handlePhase2Init(BidirectionalSyncMessage message) async {
    Logger.info('🔄 BidirectionalSyncEngine: Starting Phase 2 - Controlled Write-Back');

    await _performControlledWriteback(message.sessionId, message.syncDevice);
  }

  /// Handle Phase 2 Commit - Confirm write success
  Future<void> _handlePhase2Commit(BidirectionalSyncMessage message) async {
    final success = message.payload['success'] as bool;
    Logger.info('🔄 BidirectionalSyncEngine: Phase 2 Commit - Success: $success');

    if (success) {
      // Send sync complete
      final session = _activeSessions[message.sessionId]!;
      final memoryBuffer = _memoryBuffers[message.sessionId]!;
      
      final completeMessage = BidirectionalSyncMessage.syncComplete(
        sessionId: message.sessionId,
        senderRole: session.myRole,
        syncDevice: message.syncDevice,
        elapsedTime: session.elapsedTime,
        totalItemsProcessed: memoryBuffer.totalItemCount,
      );

      _outgoingMessages.add(completeMessage);
    } else {
      // Handle failure - should trigger rollback
      final errorMessage = message.payload['errorMessage'] as String?;
      await _sendFailureMessage(message.sessionId, message.syncDevice, errorMessage ?? 'Phase 2 commit failed');
    }
  }

  /// Handle Phase 2 Complete - Final cleanup
  Future<void> _handlePhase2Complete(BidirectionalSyncMessage message) async {
    Logger.info('🔄 BidirectionalSyncEngine: Phase 2 Complete');
    await _cleanupSession(message.sessionId);
  }

  /// Handle Sync Complete - Final success
  Future<void> _handleSyncComplete(BidirectionalSyncMessage message) async {
    Logger.info('🔄 BidirectionalSyncEngine: Sync Complete - Success!');
    await _cleanupSession(message.sessionId);
  }

  /// Handle Sync Failed - Error cleanup
  Future<void> _handleSyncFailed(BidirectionalSyncMessage message) async {
    final errorMessage = message.payload['errorMessage'] as String;
    Logger.error('🔄 BidirectionalSyncEngine: Sync Failed - $errorMessage');
    await _cleanupSession(message.sessionId);
  }

  /// Handle Sync Rollback - Undo changes
  Future<void> _handleSyncRollback(BidirectionalSyncMessage message) async {
    Logger.warning('🔄 BidirectionalSyncEngine: Sync Rollback requested');
    // TODO: Implement rollback logic
    await _cleanupSession(message.sessionId);
  }

  /// Perform controlled write-back from memory buffer to database
  Future<void> _performControlledWriteback(String sessionId, SyncDevice syncDevice) async {
    Logger.info('🔄 BidirectionalSyncEngine: Performing controlled write-back for session $sessionId');

    final memoryBuffer = _memoryBuffers[sessionId];
    if (memoryBuffer == null) {
      throw Exception('No memory buffer found for session $sessionId');
    }

    final writtenCounts = <String, int>{};
    bool allSuccessful = true;
    String? errorMessage;

    try {
      // Write each entity type atomically
      for (final entityType in memoryBuffer.entityTypes) {
        final descriptor = _registry.getDescriptor(entityType);
        if (descriptor == null) continue;

        final entityBuffer = memoryBuffer.getEntityBuffer(entityType)!;
        if (entityBuffer.isEmpty) continue;

        Logger.debug('🔄 BidirectionalSyncEngine: Writing $entityType data (${entityBuffer.operationSummary})');

        // Convert buffer data to SyncData format
        final syncData = _convertBufferToSyncData(entityBuffer, entityType);
        
        // Process the sync data atomically
        await descriptor.processSyncData(syncData);
        
        writtenCounts[entityType] = entityBuffer.totalItemCount;
        Logger.debug('🔄 BidirectionalSyncEngine: Successfully wrote ${entityBuffer.totalItemCount} items for $entityType');
      }

    } catch (e, stackTrace) {
      allSuccessful = false;
      errorMessage = e.toString();
      Logger.error('🔄 BidirectionalSyncEngine: Write-back failed: $e');
      Logger.error('StackTrace: $stackTrace');
    }

    // Send Phase 2 Commit message
    final commitMessage = BidirectionalSyncMessage.phase2Commit(
      sessionId: sessionId,
      senderRole: _activeSessions[sessionId]!.myRole,
      syncDevice: syncDevice,
      writtenCounts: writtenCounts,
      success: allSuccessful,
      errorMessage: errorMessage,
    );

    _outgoingMessages.add(commitMessage);
  }

  /// Convert memory buffer to SyncData format
  dynamic _convertBufferToSyncData(SyncEntityBuffer entityBuffer, String entityType) {
    final descriptor = _registry.getDescriptor(entityType);
    if (descriptor == null) throw Exception('No descriptor for $entityType');

    // Convert JSON data back to entity objects
    final createEntities = entityBuffer.createData.map((json) => descriptor.deserialize(json)).toList();
    final updateEntities = entityBuffer.updateData.map((json) => descriptor.deserialize(json)).toList();
    final deleteEntities = entityBuffer.deleteData.map((json) => descriptor.deserialize(json)).toList();

    // Create SyncData object
    return descriptor.runtimeType.toString().contains('Task') 
        ? _createTaskSyncData(createEntities, updateEntities, deleteEntities, entityType)
        : _createGenericSyncData(createEntities, updateEntities, deleteEntities, entityType);
  }

  /// Create generic sync data (placeholder - will be replaced with proper generic implementation)
  dynamic _createGenericSyncData(List<dynamic> creates, List<dynamic> updates, List<dynamic> deletes, String entityType) {
    // This is a simplified implementation - in real code, we'd use the generic SyncData<T>
    return {
      'createSync': creates,
      'updateSync': updates, 
      'deleteSync': deletes,
      'entityType': entityType,
    };
  }

  /// Create Task-specific sync data (temporary until generic implementation)
  dynamic _createTaskSyncData(List<dynamic> creates, List<dynamic> updates, List<dynamic> deletes, String entityType) {
    return _createGenericSyncData(creates, updates, deletes, entityType);
  }

  /// Send failure message
  Future<void> _sendFailureMessage(String sessionId, SyncDevice syncDevice, String errorMessage) async {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    final failMessage = BidirectionalSyncMessage.syncFailed(
      sessionId: sessionId,
      senderRole: session.myRole,
      syncDevice: syncDevice,
      errorMessage: errorMessage,
      errorCode: 'SYNC_ENGINE_ERROR',
      failedAtPhase: session.currentPhase,
    );

    _outgoingMessages.add(failMessage);
  }

  /// Cleanup session and memory buffers
  Future<void> _cleanupSession(String sessionId) async {
    Logger.debug('🔄 BidirectionalSyncEngine: Cleaning up session $sessionId');

    final memoryBuffer = _memoryBuffers[sessionId];
    if (memoryBuffer != null) {
      Logger.debug(memoryBuffer.summary);
      memoryBuffer.clear();
      _memoryBuffers.remove(sessionId);
    }

    _activeSessions.remove(sessionId);
    Logger.debug('🔄 BidirectionalSyncEngine: Session $sessionId cleaned up');
  }

  /// Get active session count
  int get activeSessionCount => _activeSessions.length;

  /// Get total memory usage across all buffers
  int get totalMemoryUsage {
    return _memoryBuffers.values.fold(0, (sum, buffer) => sum + buffer.estimatedMemoryUsage);
  }

  /// Dispose engine and cleanup resources
  Future<void> dispose() async {
    Logger.info('🔄 BidirectionalSyncEngine: Disposing engine');
    
    // Cleanup all active sessions
    for (final sessionId in _activeSessions.keys.toList()) {
      await _cleanupSession(sessionId);
    }

    await _outgoingMessages.close();
    await _sessionUpdates.close();
  }

  @override
  String toString() => 'BidirectionalSyncEngine(sessions: $activeSessionCount, memory: ${(totalMemoryUsage / 1024).toStringAsFixed(2)} KB)';
}