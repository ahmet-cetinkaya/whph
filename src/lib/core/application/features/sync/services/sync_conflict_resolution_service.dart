import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';

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

    if (localEntity is HabitRecord && remoteEntity is HabitRecord) {
      final localRecord = localEntity as HabitRecord;
      final remoteRecord = remoteEntity as HabitRecord;
      Logger.debug('Resolving habit record conflict for ${localEntity.id}:');
      Logger.debug(
          '   Local: deleted=$localIsDeleted, timestamp=$localTimestamp, occurredAt=${localRecord.occurredAt}');
      Logger.debug(
          '   Remote: deleted=$remoteIsDeleted, timestamp=$remoteTimestamp, occurredAt=${remoteRecord.occurredAt}');
      Logger.debug('habitId: local=${localRecord.habitId}, remote=${remoteRecord.habitId}');

      if (localRecord.occurredAt == remoteRecord.occurredAt && localRecord.habitId != remoteRecord.habitId) {
        Logger.warning('Habit record with same occurredAt but different habitId - potential data corruption');
      }

      if (localRecord.habitId == remoteRecord.habitId && localRecord.occurredAt == remoteRecord.occurredAt) {
        Logger.debug('Same habit occurrence detected, using latest timestamp');

        if (localIsDeleted == remoteIsDeleted) {
          if (localTimestamp.isAtSameMomentAs(remoteTimestamp)) {
            return ConflictResolutionResult(
              action: ConflictAction.acceptRemoteForceUpdate,
              winningEntity: remoteEntity,
              reason:
                  'Same habit occurrence, timestamps identical ($localTimestamp), using remote with force update for consistent behavior',
            );
          }

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
      }
    }

    final deletionConflict = _resolveDeletionConflict(
      localEntity,
      remoteEntity,
      localTimestamp,
      remoteTimestamp,
    );
    if (deletionConflict != null) {
      return deletionConflict;
    }

    final recurringTaskConflict = _resolveRecurringTaskConflict(
      localEntity,
      remoteEntity,
      localTimestamp,
      remoteTimestamp,
    );
    if (recurringTaskConflict != null) {
      return recurringTaskConflict;
    }

    return _resolveByTimestamp(
      localEntity,
      remoteEntity,
      localTimestamp,
      remoteTimestamp,
    );
  }

  /// Copies all remote task data to an existing task while preserving the existing task's ID.
  ///
  /// Used during sync conflict resolution when accepting remote changes for a recurring task.
  /// Leverages Task.copyWith's sentinel pattern to properly handle nullable fields.
  /// **Issue #257:** Prior to this fix, plannedDateReminderCustomOffset, deadlineDateReminderCustomOffset,
  /// and recurrenceConfiguration were missing from the copy operation, causing reminders to drop after sync.
  T copyRemoteDataToExistingTask<T extends BaseEntity<String>>(
    T existingTask,
    T remoteTask,
  ) {
    // Only works for Task entities
    if (existingTask is! Task || remoteTask is! Task) {
      Logger.warning(
        'copyRemoteDataToExistingTask called with non-Task entities: '
        'existingType=${existingTask.runtimeType}, remoteType=${remoteTask.runtimeType} [$TaskErrorIds.syncCopyRemoteDataInvalidType]',
        component: DomainLogComponents.task,
      );
      return existingTask; // Return unchanged if not tasks
    }

    final existing = existingTask as Task;
    final remote = remoteTask as Task;

    if (existing.id != remote.id) {
      throw StateError(
        'copyRemoteDataToExistingTask: ID mismatch - existing=${existing.id}, remote=${remote.id}. '
        'ID must match to preserve task identity. [$TaskErrorIds.syncCopyRemoteDataFailed]',
      );
    }

    final updatedTask = existing.copyWith(
      createdDate: remote.createdDate,
      modifiedDate: remote.modifiedDate,
      deletedDate: remote.deletedDate,
      title: remote.title,
      description: remote.description,
      priority: remote.priority,
      plannedDate: remote.plannedDate,
      deadlineDate: remote.deadlineDate,
      estimatedTime: remote.estimatedTime,
      completedAt: remote.completedAt,
      parentTaskId: remote.parentTaskId,
      order: remote.order,
      plannedDateReminderTime: remote.plannedDateReminderTime,
      plannedDateReminderCustomOffset: remote.plannedDateReminderCustomOffset,
      deadlineDateReminderTime: remote.deadlineDateReminderTime,
      deadlineDateReminderCustomOffset: remote.deadlineDateReminderCustomOffset,
      recurrenceType: remote.recurrenceType,
      recurrenceInterval: remote.recurrenceInterval,
      recurrenceDaysString: remote.recurrenceDaysString,
      recurrenceStartDate: remote.recurrenceStartDate,
      recurrenceEndDate: remote.recurrenceEndDate,
      recurrenceCount: remote.recurrenceCount,
      recurrenceParentId: remote.recurrenceParentId,
      recurrenceConfiguration: remote.recurrenceConfiguration,
    );

    if (updatedTask.id != existing.id) {
      throw StateError(
        'copyRemoteDataToExistingTask: Critical - ID changed during copy! '
        'expected=${existing.id}, got=${updatedTask.id}. '
        'This indicates a bug in Task.copyWith. [$TaskErrorIds.syncCopyRemoteDataFailed]',
      );
    }

    if (updatedTask.completedAt != null && updatedTask.completedAt!.isBefore(updatedTask.createdDate)) {
      throw StateError(
        'copyRemoteDataToExistingTask: completedAt (${updatedTask.completedAt}) is before createdDate (${updatedTask.createdDate}). '
        'This violates data invariants and indicates data corruption. [$TaskErrorIds.syncCopyRemoteDataFailed]',
      );
    }

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

    if (localIsDeleted == remoteIsDeleted) {
      return null;
    }

    Duration determineLocalDeletionGracePeriod() {
      if (localEntity is HabitRecord || remoteEntity is HabitRecord) {
        return const Duration(minutes: 8);
      } else {
        return const Duration(minutes: 5);
      }
    }

    Duration determineRemoteDeletionGracePeriod() {
      if (localEntity is HabitRecord || remoteEntity is HabitRecord) {
        return const Duration(minutes: 8);
      } else {
        return const Duration(minutes: 1, seconds: 30);
      }
    }

    final Duration localDeletionGracePeriod = determineLocalDeletionGracePeriod();
    final Duration remoteDeletionGracePeriod = determineRemoteDeletionGracePeriod();

    if (localIsDeleted && !remoteIsDeleted) {
      final timeDifference = localTimestamp.difference(remoteTimestamp);
      if (timeDifference.abs() > localDeletionGracePeriod) {
        return ConflictResolutionResult(
          action: ConflictAction.keepLocal,
          winningEntity: localEntity,
          reason:
              'Local deletion ($localTimestamp) occurred significantly after remote modification ($remoteTimestamp)',
        );
      } else {
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
        return ConflictResolutionResult(
          action: ConflictAction.acceptRemote,
          winningEntity: remoteEntity,
          reason:
              'Remote deletion ($remoteTimestamp) occurred significantly after local modification ($localTimestamp)',
        );
      } else {
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

      // Use entity ID for deterministic resolution to prevent random behavior when syncing
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
