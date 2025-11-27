/// Immutable state model for lock settings in quick task dialog
/// Provides centralized state management with copyWith functionality
class LockSettingsState {
  final bool lockTags;
  final bool lockPriority;
  final bool lockEstimatedTime;
  final bool lockPlannedDate;
  final bool lockDeadlineDate;

  const LockSettingsState({
    this.lockTags = false,
    this.lockPriority = false,
    this.lockEstimatedTime = false,
    this.lockPlannedDate = false,
    this.lockDeadlineDate = false,
  });

  /// Creates a new LockSettingsState with updated values
  LockSettingsState copyWith({
    bool? lockTags,
    bool? lockPriority,
    bool? lockEstimatedTime,
    bool? lockPlannedDate,
    bool? lockDeadlineDate,
  }) {
    return LockSettingsState(
      lockTags: lockTags ?? this.lockTags,
      lockPriority: lockPriority ?? this.lockPriority,
      lockEstimatedTime: lockEstimatedTime ?? this.lockEstimatedTime,
      lockPlannedDate: lockPlannedDate ?? this.lockPlannedDate,
      lockDeadlineDate: lockDeadlineDate ?? this.lockDeadlineDate,
    );
  }

  /// Creates a new LockSettingsState with all locks cleared
  LockSettingsState copyWithAllCleared() {
    return const LockSettingsState(
      lockTags: false,
      lockPriority: false,
      lockEstimatedTime: false,
      lockPlannedDate: false,
      lockDeadlineDate: false,
    );
  }

  /// Updates a specific lock type by name
  LockSettingsState updateLockType(String lockType, bool value) {
    switch (lockType) {
      case 'tags':
        return copyWith(lockTags: value);
      case 'priority':
        return copyWith(lockPriority: value);
      case 'estimatedTime':
        return copyWith(lockEstimatedTime: value);
      case 'plannedDate':
        return copyWith(lockPlannedDate: value);
      case 'deadlineDate':
        return copyWith(lockDeadlineDate: value);
      default:
        return this; // Return unchanged if lock type not recognized
    }
  }

  /// Returns true if any lock is active
  bool get hasAnyLocks => lockTags || lockPriority || lockEstimatedTime || lockPlannedDate || lockDeadlineDate;

  /// Returns the number of active locks
  int get activeLocksCount {
    int count = 0;
    if (lockTags) count++;
    if (lockPriority) count++;
    if (lockEstimatedTime) count++;
    if (lockPlannedDate) count++;
    if (lockDeadlineDate) count++;
    return count;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LockSettingsState &&
        other.lockTags == lockTags &&
        other.lockPriority == lockPriority &&
        other.lockEstimatedTime == lockEstimatedTime &&
        other.lockPlannedDate == lockPlannedDate &&
        other.lockDeadlineDate == lockDeadlineDate;
  }

  @override
  int get hashCode {
    return lockTags.hashCode ^
        lockPriority.hashCode ^
        lockEstimatedTime.hashCode ^
        lockPlannedDate.hashCode ^
        lockDeadlineDate.hashCode;
  }

  @override
  String toString() {
    return 'LockSettingsState('
        'lockTags: $lockTags, '
        'lockPriority: $lockPriority, '
        'lockEstimatedTime: $lockEstimatedTime, '
        'lockPlannedDate: $lockPlannedDate, '
        'lockDeadlineDate: $lockDeadlineDate)';
  }
}
