// New Bidirectional Sync Protocol - v3
/// 
/// Flow:
/// 1. PHASE_1_INIT → Both sides prepare for data exchange
/// 2. PHASE_1_DATA → Exchange all data to memory buffers
/// 3. PHASE_1_COMPLETE → Confirm all data received
/// 4. PHASE_2_INIT → Begin controlled write-back
/// 5. PHASE_2_COMMIT → Atomic database writes
/// 6. PHASE_2_COMPLETE → Confirm successful writes
/// 7. SYNC_COMPLETE → Final cleanup and confirmation

enum SyncPhase {
  // Phase 1: Data Exchange (Memory Only)
  phase1Init('PHASE_1_INIT'),
  phase1Data('PHASE_1_DATA'), 
  phase1Complete('PHASE_1_COMPLETE'),
  
  // Phase 2: Controlled Write-Back
  phase2Init('PHASE_2_INIT'),
  phase2Commit('PHASE_2_COMMIT'),
  phase2Complete('PHASE_2_COMPLETE'),
  
  // Final States
  syncComplete('SYNC_COMPLETE'),
  syncFailed('SYNC_FAILED'),
  syncRollback('SYNC_ROLLBACK');

  const SyncPhase(this.value);
  final String value;

  static SyncPhase fromValue(String value) {
    return SyncPhase.values.firstWhere(
      (phase) => phase.value == value,
      orElse: () => throw ArgumentError('Unknown sync phase: $value'),
    );
  }
}

enum SyncRole {
  initiator('INITIATOR'),    // The device that starts sync
  responder('RESPONDER');    // The device that responds

  const SyncRole(this.value);
  final String value;

  static SyncRole fromValue(String value) {
    return SyncRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => throw ArgumentError('Unknown sync role: $value'),
    );
  }
}

/// Sync session state
class SyncSession {
  final String sessionId;
  final SyncPhase currentPhase;
  final SyncRole myRole;
  final String remoteDeviceId;
  final DateTime startTime;
  final Map<String, int> expectedDataCounts;
  final Map<String, int> receivedDataCounts;
  final List<String> completedEntities;
  final String? errorMessage;

  const SyncSession({
    required this.sessionId,
    required this.currentPhase,
    required this.myRole,
    required this.remoteDeviceId,
    required this.startTime,
    this.expectedDataCounts = const {},
    this.receivedDataCounts = const {},
    this.completedEntities = const [],
    this.errorMessage,
  });

  /// Create new session
  factory SyncSession.create({
    required SyncRole role,
    required String remoteDeviceId,
  }) {
    return SyncSession(
      sessionId: _generateSessionId(),
      currentPhase: SyncPhase.phase1Init,
      myRole: role,
      remoteDeviceId: remoteDeviceId,
      startTime: DateTime.now(),
    );
  }

  /// Update session phase
  SyncSession updatePhase(SyncPhase newPhase, {String? error}) {
    return SyncSession(
      sessionId: sessionId,
      currentPhase: newPhase,
      myRole: myRole,
      remoteDeviceId: remoteDeviceId,
      startTime: startTime,
      expectedDataCounts: expectedDataCounts,
      receivedDataCounts: receivedDataCounts,
      completedEntities: completedEntities,
      errorMessage: error,
    );
  }

  /// Update data counts
  SyncSession updateDataCounts({
    Map<String, int>? expected,
    Map<String, int>? received,
    List<String>? completed,
  }) {
    return SyncSession(
      sessionId: sessionId,
      currentPhase: currentPhase,
      myRole: myRole,
      remoteDeviceId: remoteDeviceId,
      startTime: startTime,
      expectedDataCounts: expected ?? expectedDataCounts,
      receivedDataCounts: received ?? receivedDataCounts,
      completedEntities: completed ?? completedEntities,
      errorMessage: errorMessage,
    );
  }

  /// Check if phase 1 is complete
  bool get isPhase1Complete {
    if (expectedDataCounts.isEmpty) return false;
    
    for (final entityType in expectedDataCounts.keys) {
      final expected = expectedDataCounts[entityType] ?? 0;
      final received = receivedDataCounts[entityType] ?? 0;
      if (received < expected) return false;
    }
    return true;
  }

  /// Get sync progress percentage
  double get progressPercentage {
    if (expectedDataCounts.isEmpty) return 0.0;
    
    int totalExpected = expectedDataCounts.values.fold(0, (sum, count) => sum + count);
    int totalReceived = receivedDataCounts.values.fold(0, (sum, count) => sum + count);
    
    if (totalExpected == 0) return 100.0;
    return (totalReceived / totalExpected * 100).clamp(0.0, 100.0);
  }

  /// Generate unique session ID
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000).toString().padLeft(5, '0');
    return 'sync_session_${timestamp}_$random';
  }

  /// Get elapsed time
  Duration get elapsedTime => DateTime.now().difference(startTime);

  @override
  String toString() => 'SyncSession(id: $sessionId, phase: ${currentPhase.value}, role: ${myRole.value}, progress: ${progressPercentage.toStringAsFixed(1)}%)';
}