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

    // Enhanced logging for habit records to help debug sync issues
    if (localEntity is HabitRecord) {
      Logger.debug('🔄 Resolving habit record conflict for ${localEntity.id}:');
      Logger.debug('   Local: deleted=$localIsDeleted, timestamp=$localTimestamp');
      Logger.debug('   Remote: deleted=$remoteIsDeleted, timestamp=$remoteTimestamp');
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

    // Create a copy of the remote task but with the existing task's ID
    // This preserves database consistency while applying remote changes
    final updatedTask = Task(
      id: existingTask.id, // Keep existing ID
      createdDate: remoteTask.createdDate,
      modifiedDate: remoteTask.modifiedDate,
      deletedDate: remoteTask.deletedDate,
      title: remoteTask.title,
      description: remoteTask.description,
      priority: remoteTask.priority,
      plannedDate: remoteTask.plannedDate,
      deadlineDate: remoteTask.deadlineDate,
      estimatedTime: remoteTask.estimatedTime,
      isCompleted: remoteTask.isCompleted,
      parentTaskId: remoteTask.parentTaskId,
      order: remoteTask.order,
      plannedDateReminderTime: remoteTask.plannedDateReminderTime,
      deadlineDateReminderTime: remoteTask.deadlineDateReminderTime,
      recurrenceType: remoteTask.recurrenceType,
      recurrenceInterval: remoteTask.recurrenceInterval,
      recurrenceStartDate: remoteTask.recurrenceStartDate,
      recurrenceEndDate: remoteTask.recurrenceEndDate,
      recurrenceCount: remoteTask.recurrenceCount,
      recurrenceParentId: remoteTask.recurrenceParentId,
    );

    // Copy recurrence days string
    updatedTask.recurrenceDaysString = remoteTask.recurrenceDaysString;

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

    const Duration deletionGracePeriod = Duration(minutes: 5);

    if (localIsDeleted && !remoteIsDeleted) {
      if (localTimestamp.difference(remoteTimestamp) > deletionGracePeriod) {
        return ConflictResolutionResult(
          action: ConflictAction.keepLocal,
          winningEntity: localEntity,
          reason: 'Local deletion ($localTimestamp) occurred significantly after remote modification ($remoteTimestamp)',
        );
      } else {
        return ConflictResolutionResult(
          action: ConflictAction.acceptRemote,
          winningEntity: remoteEntity,
          reason: 'Preferring non-deleted remote entity over recent local deletion (deletion time: $localTimestamp, remote time: $remoteTimestamp)',
        );
      }
    } else if (remoteIsDeleted && !localIsDeleted) {
      if (remoteTimestamp.difference(localTimestamp) > deletionGracePeriod) {
        return ConflictResolutionResult(
          action: ConflictAction.acceptRemote,
          winningEntity: remoteEntity,
          reason: 'Remote deletion ($remoteTimestamp) occurred significantly after local modification ($localTimestamp)',
        );
      } else {
        return ConflictResolutionResult(
          action: ConflictAction.keepLocal,
          winningEntity: localEntity,
          reason: 'Preferring non-deleted local entity over recent remote deletion (deletion time: $remoteTimestamp, local time: $localTimestamp)',
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
      return ConflictResolutionResult(
        action: ConflictAction.acceptRemoteForceUpdate,
        winningEntity: remoteEntity,
        reason: 'Timestamps are identical ($localTimestamp), accepting remote',
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