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
  final Map<String, String>? errorParams;
  final DateTime? lastSyncTime;
  final bool isManual;

  /// Share of the current session that is done, 0..1; `null` while it is not known.
  final double? progress;

  const SyncStatus({
    required this.state,
    this.currentDeviceId,
    this.errorMessage,
    this.errorParams,
    this.lastSyncTime,
    this.isManual = false,
    this.progress,
  });

  SyncStatus copyWith({
    SyncState? state,
    String? currentDeviceId,
    String? errorMessage,
    Map<String, String>? errorParams,
    DateTime? lastSyncTime,
    bool? isManual,
    double? progress,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      errorMessage: errorMessage ?? this.errorMessage,
      errorParams: errorParams ?? this.errorParams,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isManual: isManual ?? this.isManual,
      progress: progress ?? this.progress,
    );
  }

  bool get isSyncing => state == SyncState.syncing;
  bool get isIdle => state == SyncState.idle;
  bool get hasError => state == SyncState.error;
  bool get isCompleted => state == SyncState.completed;

  @override
  String toString() {
    return 'SyncStatus(state: $state, currentDeviceId: $currentDeviceId, errorMessage: $errorMessage, errorParams: $errorParams, lastSyncTime: $lastSyncTime, isManual: $isManual, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncStatus &&
        other.state == state &&
        other.currentDeviceId == currentDeviceId &&
        other.errorMessage == errorMessage &&
        other.lastSyncTime == lastSyncTime &&
        other.isManual == isManual &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(
        state,
        currentDeviceId,
        errorMessage,
        lastSyncTime,
        isManual,
        progress,
      );
}
