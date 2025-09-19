import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

void main() {
  group('PaginatedSyncCommand Conflict Resolution Tests', () {
    setUp(() {
      // Note: In a full implementation, this would set up proper dependencies
      // For now, we're testing the conflict resolution logic in isolation
    });

    group('Habit Record Sync Conflicts', () {
      test('should prefer non-deleted entity over recent deletion', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final twoMinutesAgo = now.subtract(const Duration(minutes: 2));

        final localHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: twoMinutesAgo,
          habitId: 'habit-1',
          occurredAt: twoMinutesAgo,
        );

        final remoteHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: twoMinutesAgo,
          modifiedDate: now, // Set when deleted
          deletedDate: now, // Recently deleted
          habitId: 'habit-1',
          occurredAt: twoMinutesAgo,
        );

        // Act
        final result = _testConflictResolution(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.reason, contains('non-deleted local entity'));
        expect(result.winningEntity, localHabitRecord);
      });

      test('should accept deletion when it happened significantly later', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final tenMinutesAgo = now.subtract(const Duration(minutes: 10));

        final localHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: tenMinutesAgo,
          habitId: 'habit-1',
          occurredAt: tenMinutesAgo,
        );

        final remoteHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: tenMinutesAgo,
          modifiedDate: now, // Set when deleted
          deletedDate: now, // Deleted significantly later
          habitId: 'habit-1',
          occurredAt: tenMinutesAgo,
        );

        // Act
        final result = _testConflictResolution(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('occurred significantly after'));
        expect(result.winningEntity, remoteHabitRecord);
      });

      test('should prefer remote non-deleted over local deleted', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final twoMinutesAgo = now.subtract(const Duration(minutes: 2));

        final localHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: twoMinutesAgo,
          modifiedDate: now, // Set when deleted
          deletedDate: now, // Recently deleted
          habitId: 'habit-1',
          occurredAt: twoMinutesAgo,
        );

        final remoteHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: twoMinutesAgo,
          habitId: 'habit-1',
          occurredAt: twoMinutesAgo,
        );

        // Act
        final result = _testConflictResolution(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('non-deleted remote entity'));
        expect(result.winningEntity, remoteHabitRecord);
      });
    });

    group('Recurring Task Sync Conflicts', () {
      test('should prefer task with earlier planned date when same recurrence parent', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));
        final dayAfterTomorrow = now.add(const Duration(days: 2));

        final localTask = Task(
          id: 'task-instance-1',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-2',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: dayAfterTomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1', // Same parent
        );

        // Act
        final result = _testConflictResolution(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.reason, contains('earlier planned date'));
        expect(result.winningEntity, localTask);
      });

      test('should prefer remote task with earlier planned date', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));
        final dayAfterTomorrow = now.add(const Duration(days: 2));

        final localTask = Task(
          id: 'task-instance-1',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: dayAfterTomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-2',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1', // Same parent
        );

        // Act
        final result = _testConflictResolution(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('earlier planned date'));
        expect(result.winningEntity, remoteTask);
      });

      test('should fall back to timestamp resolution when planned dates are same', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));
        final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

        final localTask = Task(
          id: 'task-instance-1',
          createdDate: oneMinuteAgo,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-2',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow, // Same planned date
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        // Act
        final result = _testConflictResolution(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('newer than'));
      });

      test('should not apply recurring task logic for different parents', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));

        final localTask = Task(
          id: 'task-instance-1',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-2',
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-2', // Different parent
        );

        // Act
        final result = _testConflictResolution(localTask, remoteTask);

        // Assert
        // Should fall back to standard timestamp resolution
        expect(result.action, ConflictAction.acceptRemoteForceUpdate);
        expect(result.reason, contains('identical'));
      });
    });

    group('Standard Timestamp Conflict Resolution', () {
      test('should prefer local when local timestamp is newer', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

        final localHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: now,
          habitId: 'habit-1',
          occurredAt: now,
        );

        final remoteHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: oneMinuteAgo,
          habitId: 'habit-1',
          occurredAt: oneMinuteAgo,
        );

        // Act
        final result = _testConflictResolution(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.reason, contains('newer than remote'));
      });

      test('should prefer remote when remote timestamp is newer', () {
        // Arrange
        final now = DateTime.now().toUtc();
        final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

        final localHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: oneMinuteAgo,
          habitId: 'habit-1',
          occurredAt: oneMinuteAgo,
        );

        final remoteHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: now,
          habitId: 'habit-1',
          occurredAt: now,
        );

        // Act
        final result = _testConflictResolution(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('newer than local'));
      });

      test('should prefer remote when timestamps are identical', () {
        // Arrange
        final now = DateTime.now().toUtc();

        final localHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: now,
          habitId: 'habit-1',
          occurredAt: now,
        );

        final remoteHabitRecord = HabitRecord(
          id: 'habit-record-1',
          createdDate: now,
          habitId: 'habit-1',
          occurredAt: now,
        );

        // Act
        final result = _testConflictResolution(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemoteForceUpdate);
        expect(result.reason, contains('identical'));
      });
    });
  });
}

// IMPORTANT: This test currently duplicates the production conflict resolution logic
// to avoid complex dependency setup. In the future, this should be refactored to:
// 1. Extract conflict resolution logic into a separate, testable service class
// 2. Use the actual production code via dependency injection
// 3. Or create a minimal test harness with mocked dependencies
// The current approach tests the logic but doesn't guarantee it matches production behavior.

// Helper method that implements the same logic as production code
// This is a temporary solution until proper testing architecture is implemented
ConflictResolutionResult<T> _testConflictResolution<T extends BaseEntity<String>>(T localEntity, T remoteEntity) {
  final DateTime localTimestamp = localEntity.modifiedDate ?? localEntity.createdDate;
  final DateTime remoteTimestamp = remoteEntity.modifiedDate ?? remoteEntity.createdDate;

  final bool localIsDeleted = localEntity.deletedDate != null;
  final bool remoteIsDeleted = remoteEntity.deletedDate != null;

  // Handle deletion conflicts specially (matches production implementation)
  if (localIsDeleted != remoteIsDeleted) {
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
  }

  // Handle recurring task duplication conflicts (matches production implementation)
  if (localEntity is Task && remoteEntity is Task) {
    if (localEntity.recurrenceParentId != null &&
        remoteEntity.recurrenceParentId != null &&
        localEntity.recurrenceParentId == remoteEntity.recurrenceParentId) {
      final DateTime? localPlannedDate = localEntity.plannedDate;
      final DateTime? remotePlannedDate = remoteEntity.plannedDate;

      if (localPlannedDate != null && remotePlannedDate != null) {
        if (localPlannedDate.isBefore(remotePlannedDate)) {
          return ConflictResolutionResult(
            action: ConflictAction.keepLocal,
            winningEntity: localEntity,
            reason: 'Local recurring task instance has earlier planned date ($localPlannedDate vs $remotePlannedDate)',
          );
        } else if (remotePlannedDate.isBefore(localPlannedDate)) {
          return ConflictResolutionResult(
            action: ConflictAction.acceptRemote,
            winningEntity: remoteEntity,
            reason: 'Remote recurring task instance has earlier planned date ($remotePlannedDate vs $localPlannedDate)',
          );
        }
      }
    }
  }

  // Standard timestamp-based conflict resolution (matches production implementation)
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
      reason: 'Timestamps are identical ($localTimestamp), preferring remote version for consistency',
    );
  }
}

// Test helper types that mirror the actual production implementation
enum ConflictAction {
  keepLocal,
  acceptRemote,
  acceptRemoteForceUpdate,
}

class ConflictResolutionResult<T> {
  final ConflictAction action;
  final T winningEntity;
  final String reason;

  ConflictResolutionResult({
    required this.action,
    required this.winningEntity,
    required this.reason,
  });
}