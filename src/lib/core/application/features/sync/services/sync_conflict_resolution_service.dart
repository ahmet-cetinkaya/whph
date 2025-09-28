import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Service responsible for resolving sync conflicts between local and remote entities
class SyncConflictResolutionService {
  /// Resolves conflicts between local and remote entities
  ConflictResolutionResult<T> resolveConflict<T extends BaseEntity<String>>(
    T localEntity,
    T remoteEntity,
  ) {
    final DateTime localTimestamp = _getEffectiveTimestamp(localEntity);
    final DateTime remoteTimestamp = _getEffectiveTimestamp(remoteEntity);

    final bool localIsDeleted = localEntity.deletedDate != null;
    final bool remoteIsDeleted = remoteEntity.deletedDate != null;

    // Enhanced logging and special handling for habit records to help debug sync issues
    if (localEntity is HabitRecord && remoteEntity is HabitRecord) {
      final localRecord = localEntity as HabitRecord;
      final remoteRecord = remoteEntity as HabitRecord;
      Logger.debug('🔄 Resolving habit record conflict for ${localEntity.id}:');
      Logger.debug(
          '   Local: deleted=$localIsDeleted, timestamp=$localTimestamp, occurredAt=${localRecord.occurredAt}');
      Logger.debug(
          '   Remote: deleted=$remoteIsDeleted, timestamp=$remoteTimestamp, occurredAt=${remoteRecord.occurredAt}');
      Logger.debug('   habitId: local=${localRecord.habitId}, remote=${remoteRecord.habitId}');

      // Special handling for habit records with same occurredAt but different habitId (edge case)
      if (localRecord.occurredAt == remoteRecord.occurredAt && localRecord.habitId != remoteRecord.habitId) {
        Logger.warning('⚠️ Habit record with same occurredAt but different habitId - potential data corruption');
      }

      // For habit records with same habitId and occurredAt, treat as same record regardless of modification date
      if (localRecord.habitId == remoteRecord.habitId && localRecord.occurredAt == remoteRecord.occurredAt) {
        Logger.debug('   ✅ Same habit occurrence detected, using latest timestamp');

        // If both have same deletion status, use timestamp-based resolution
        if (localIsDeleted == remoteIsDeleted) {
          // Special case: if timestamps are identical, use acceptRemoteForceUpdate for consistency
          if (localTimestamp.isAtSameMomentAs(remoteTimestamp)) {
            return ConflictResolutionResult(
              action: ConflictAction.acceptRemoteForceUpdate,
              winningEntity: remoteEntity,
              reason:
                  'Same habit occurrence, timestamps identical ($localTimestamp), using remote with force update for consistent behavior',
            );
          }

          // In this case, use the latest modification timestamp as the deciding factor
          return localTimestamp.isAfter(remoteTimestamp)
              ? ConflictResolutionResult(
                  action: ConflictAction.keepLocal,
                  winningEntity: localEntity,
                  reason:
                      'Same habit occurrence, local timestamp ($localTimestamp) is newer than remote ($remoteTimestamp)',
                )
              : ConflictResolutionResult(
                  action: ConflictAction.acceptRemote,
                  winningEntity: remoteEntity,
                  reason:
                      'Same habit occurrence, remote timestamp ($remoteTimestamp) is newer than local ($localTimestamp)',
                );
        }
        // If deletion status differs, let general deletion conflict resolution handle it below
      }
    }

    // Handle deletion conflicts specially
    final deletionConflict = _resolveDeletionConflict(
      localEntity,
      remoteEntity,
      localTimestamp,
      remoteTimestamp,
    );
    if (deletionConflict != null) {
      return deletionConflict;
    }

    // Handle recurring task conflicts with special logic
    final recurringTaskConflict = _resolveRecurringTaskConflict(
      localEntity,
      remoteEntity,
      localTimestamp,
      remoteTimestamp,
    );
    if (recurringTaskConflict != null) {
      return recurringTaskConflict;
    }

    // Standard timestamp-based resolution
    return _resolveByTimestamp(
      localEntity,
      remoteEntity,
      localTimestamp,
      remoteTimestamp,
    );
  }

  /// Copies remote data to an existing task while preserving the existing task's ID
  T copyRemoteDataToExistingTask<T extends BaseEntity<String>>(
    T existingTask,
    T remoteTask,
  ) {
    // Only works for Task entities
    if (existingTask is! Task || remoteTask is! Task) {
      return existingTask; // Return unchanged if not tasks
    }

    // Use the copyWith method to create an updated task while preserving the ID
    final updatedTask = (existingTask as Task).copyWith(
      createdDate: remoteTask.createdDate,
      modifiedDate: remoteTask.modifiedDate,
      deletedDate: remoteTask.deletedDate,
      title: remoteTask.title,
      description: remoteTask.description,
      priority: remoteTask.priority,
      plannedDate: remoteTask.plannedDate,
      deadlineDate: remoteTask.deadlineDate,
      estimatedTime: remoteTask.estimatedTime,
      completedAt: remoteTask.completedAt,
      parentTaskId: remoteTask.parentTaskId,
      order: remoteTask.order,
      plannedDateReminderTime: remoteTask.plannedDateReminderTime,
      deadlineDateReminderTime: remoteTask.deadlineDateReminderTime,
      recurrenceType: remoteTask.recurrenceType,
      recurrenceInterval: remoteTask.recurrenceInterval,
      recurrenceDaysString: remoteTask.recurrenceDaysString,
      recurrenceStartDate: remoteTask.recurrenceStartDate,
      recurrenceEndDate: remoteTask.recurrenceEndDate,
      recurrenceCount: remoteTask.recurrenceCount,
      recurrenceParentId: remoteTask.recurrenceParentId,
    );

    return updatedTask as T;
  }

  /// Gets the effective timestamp for conflict resolution
  DateTime _getEffectiveTimestamp<T extends BaseEntity<String>>(T entity) {
    return entity.modifiedDate ?? entity.createdDate;
  }

  /// Resolves deletion conflicts with grace period logic
  ConflictResolutionResult<T>? _resolveDeletionConflict<T extends BaseEntity<String>>(
    T localEntity,
    T remoteEntity,
    DateTime localTimestamp,
    DateTime remoteTimestamp,
  ) {
    final bool localIsDeleted = localEntity.deletedDate != null;
    final bool remoteIsDeleted = remoteEntity.deletedDate != null;

    // Only handle cases where deletion status differs
    if (localIsDeleted == remoteIsDeleted) {
      return null;
    }

    // Determine appropriate grace periods based on entity type and which side is deleted
    Duration determineLocalDeletionGracePeriod() {
      if (localEntity is HabitRecord || remoteEntity is HabitRecord) {
        return const Duration(minutes: 8); // Very conservative for habit records
      } else {
        return const Duration(minutes: 5); // Higher threshold for local deletions in general
      }
    }

    Duration determineRemoteDeletionGracePeriod() {
      if (localEntity is HabitRecord || remoteEntity is HabitRecord) {
        return const Duration(minutes: 8); // Very conservative for habit records
      } else {
        return const Duration(minutes: 1, seconds: 30); // 1.5 minutes for remote deletions
      }
    }

    final Duration localDeletionGracePeriod = determineLocalDeletionGracePeriod();
    final Duration remoteDeletionGracePeriod = determineRemoteDeletionGracePeriod();

    if (localIsDeleted && !remoteIsDeleted) {
      final timeDifference = localTimestamp.difference(remoteTimestamp);
      if (timeDifference.abs() > localDeletionGracePeriod) {
        // Local deletion occurred significantly later, so keep the local deletion
        return ConflictResolutionResult(
          action: ConflictAction.keepLocal,
          winningEntity: localEntity,
          reason:
              'Local deletion ($localTimestamp) occurred significantly after remote modification ($remoteTimestamp)',
        );
      } else {
        // Local deletion is recent relative to remote's modification, prefer the non-deleted remote entity
        return ConflictResolutionResult(
          action: ConflictAction.acceptRemote,
          winningEntity: remoteEntity,
          reason:
              'Preferring non-deleted remote entity over recent local deletion (deletion time: $localTimestamp, remote time: $remoteTimestamp)',
        );
      }
    } else if (remoteIsDeleted && !localIsDeleted) {
      final timeDifference = remoteTimestamp.difference(localTimestamp);
      if (timeDifference.abs() > remoteDeletionGracePeriod) {
        // Remote deletion occurred significantly later, so accept the remote deletion
        return ConflictResolutionResult(
          action: ConflictAction.acceptRemote,
          winningEntity: remoteEntity,
          reason:
              'Remote deletion ($remoteTimestamp) occurred significantly after local modification ($localTimestamp)',
        );
      } else {
        // Remote deletion is recent relative to local's modification, prefer the non-deleted local entity
        return ConflictResolutionResult(
          action: ConflictAction.keepLocal,
          winningEntity: localEntity,
          reason:
              'Preferring non-deleted local entity over recent remote deletion (deletion time: $remoteTimestamp, local time: $localTimestamp)',
        );
      }
    }

    return null;
  }

  /// Resolves recurring task conflicts using planned date logic
  ConflictResolutionResult<T>? _resolveRecurringTaskConflict<T extends BaseEntity<String>>(
    T localEntity,
    T remoteEntity,
    DateTime localTimestamp,
    DateTime remoteTimestamp,
  ) {
    // Only apply to Task entities with the same recurrence parent
    if (localEntity is! Task || remoteEntity is! Task) {
      return null;
    }

    if (localEntity.recurrenceParentId == null ||
        remoteEntity.recurrenceParentId == null ||
        localEntity.recurrenceParentId != remoteEntity.recurrenceParentId) {
      return null;
    }

    final DateTime? localPlannedDate = localEntity.plannedDate;
    final DateTime? remotePlannedDate = remoteEntity.plannedDate;

    if (localPlannedDate != null && remotePlannedDate != null) {
      if (localPlannedDate.isBefore(remotePlannedDate)) {
        return ConflictResolutionResult(
          action: ConflictAction.keepLocal,
          winningEntity: localEntity,
          reason: 'Local recurring task has earlier planned date ($localPlannedDate vs $remotePlannedDate)',
        );
      } else if (remotePlannedDate.isBefore(localPlannedDate)) {
        return ConflictResolutionResult(
          action: ConflictAction.acceptRemote,
          winningEntity: remoteEntity,
          reason: 'Remote recurring task has earlier planned date ($remotePlannedDate vs $localPlannedDate)',
        );
      }
      // If planned dates are the same, fall through to timestamp resolution
    }

    return null;
  }

  /// Resolves conflicts based on timestamps
  ConflictResolutionResult<T> _resolveByTimestamp<T extends BaseEntity<String>>(
    T localEntity,
    T remoteEntity,
    DateTime localTimestamp,
    DateTime remoteTimestamp,
  ) {
    if (localTimestamp.isAfter(remoteTimestamp)) {
      return ConflictResolutionResult(
        action: ConflictAction.keepLocal,
        winningEntity: localEntity,
        reason: 'Local timestamp ($localTimestamp) is newer than remote ($remoteTimestamp)',
      );
    } else if (remoteTimestamp.isAfter(localTimestamp)) {
      return ConflictResolutionResult(
        action: ConflictAction.acceptRemote,
        winningEntity: remoteEntity,
        reason: 'Remote timestamp ($remoteTimestamp) is newer than local ($localTimestamp)',
      );
    } else {
      // For identical timestamps, check if these are tasks with different recurrence parents
      // In such cases, use force update to ensure proper handling
      if (localEntity is Task && remoteEntity is Task) {
        final localTask = localEntity as Task;
        final remoteTask = remoteEntity as Task;

        if (localTask.recurrenceParentId != null &&
            remoteTask.recurrenceParentId != null &&
            localTask.recurrenceParentId != remoteTask.recurrenceParentId) {
          return ConflictResolutionResult(
            action: ConflictAction.acceptRemoteForceUpdate,
            winningEntity: remoteEntity,
            reason:
                'Timestamps are identical ($localTimestamp), different recurrence parents detected - force updating to remote',
          );
        }
      }

      // For other identical timestamp cases, use entity ID for deterministic resolution
      // This prevents random behavior when syncing between devices
      final useLocal = localEntity.id.compareTo(remoteEntity.id) > 0;
      return ConflictResolutionResult(
        action: useLocal ? ConflictAction.keepLocal : ConflictAction.acceptRemote,
        winningEntity: useLocal ? localEntity : remoteEntity,
        reason:
            'Timestamps are identical ($localTimestamp), using deterministic ID-based resolution (chose ${useLocal ? "local" : "remote"})',
      );
    }
  }
}

/// Result of conflict resolution
class ConflictResolutionResult<T extends BaseEntity<String>> {
  final ConflictAction action;
  final T winningEntity;
  final String reason;

  ConflictResolutionResult({
    required this.action,
    required this.winningEntity,
    required this.reason,
  });
}

/// Actions that can be taken to resolve conflicts
enum ConflictAction {
  /// Keep the local entity unchanged
  keepLocal,

  /// Accept the remote entity
  acceptRemote,

  /// Accept the remote entity and force update even if timestamps are identical
  acceptRemoteForceUpdate,
}
