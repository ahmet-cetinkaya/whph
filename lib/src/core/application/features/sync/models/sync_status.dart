enum SyncState {
  idle,
  syncing,
  completed,
  error,
}

class SyncStatus {
  final SyncState state;
  final String? currentDeviceId;
  final String? errorMessage;
  final DateTime? lastSyncTime;
  final bool isManual;

  const SyncStatus({
    required this.state,
    this.currentDeviceId,
    this.errorMessage,
    this.lastSyncTime,
    this.isManual = false,
  });

  SyncStatus copyWith({
    SyncState? state,
    String? currentDeviceId,
    String? errorMessage,
    DateTime? lastSyncTime,
    bool? isManual,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isManual: isManual ?? this.isManual,
    );
  }

  bool get isSyncing => state == SyncState.syncing;
  bool get isIdle => state == SyncState.idle;
  bool get hasError => state == SyncState.error;
  bool get isCompleted => state == SyncState.completed;

  @override
  String toString() {
    return 'SyncStatus(state: $state, currentDeviceId: $currentDeviceId, errorMessage: $errorMessage, lastSyncTime: $lastSyncTime, isManual: $isManual)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncStatus &&
        other.state == state &&
        other.currentDeviceId == currentDeviceId &&
        other.errorMessage == errorMessage &&
        other.lastSyncTime == lastSyncTime &&
        other.isManual == isManual;
  }

  @override
  int get hashCode {
    return state.hashCode ^
        currentDeviceId.hashCode ^
        errorMessage.hashCode ^
        lastSyncTime.hashCode ^
        isManual.hashCode;
  }
}
