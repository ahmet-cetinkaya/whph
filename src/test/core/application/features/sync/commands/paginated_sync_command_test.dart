import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/sync/services/sync_conflict_resolution_service.dart';

void main() {
  group('SyncConflictResolutionService Tests', () {
    late SyncConflictResolutionService conflictResolutionService;

    setUp(() {
      conflictResolutionService = SyncConflictResolutionService();
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
        final result = conflictResolutionService.resolveConflict(localHabitRecord, remoteHabitRecord);

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
        final result = conflictResolutionService.resolveConflict(localHabitRecord, remoteHabitRecord);

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
        final result = conflictResolutionService.resolveConflict(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('non-deleted remote entity'));
        expect(result.winningEntity, remoteHabitRecord);
      });
    });

    group('Recurring Task Sync Conflicts', () {
      // NOTE: These tests cover same-ID recurring task conflicts that can occur when
      // the same recurring task instance is modified on different devices before sync.
      // Different-ID deduplication (when devices independently create instances for
      // the same recurrence) is now handled separately in the create logic.

      test('should prefer task with earlier planned date when same ID and recurrence parent', () {
        // Arrange - Same task ID modified on different devices with different planned dates
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));
        final dayAfterTomorrow = now.add(const Duration(days: 2));

        final localTask = Task(
          id: 'task-instance-1', // Same ID
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-1', // Same ID - conflict scenario
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: dayAfterTomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1', // Same parent
        );

        // Act
        final result = conflictResolutionService.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.reason, contains('earlier planned date'));
        expect(result.winningEntity, localTask);
      });

      test('should prefer remote task with earlier planned date when same ID', () {
        // Arrange - Same task ID modified on different devices with different planned dates
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));
        final dayAfterTomorrow = now.add(const Duration(days: 2));

        final localTask = Task(
          id: 'task-instance-1', // Same ID
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: dayAfterTomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-1', // Same ID - conflict scenario
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1', // Same parent
        );

        // Act
        final result = conflictResolutionService.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('earlier planned date'));
        expect(result.winningEntity, remoteTask);
      });

      test('should fall back to timestamp resolution when planned dates are same', () {
        // Arrange - Same task ID modified on different devices with same planned date
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));
        final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

        final localTask = Task(
          id: 'task-instance-1', // Same ID
          createdDate: oneMinuteAgo,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-1', // Same ID - conflict scenario
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow, // Same planned date
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        // Act
        final result = conflictResolutionService.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('newer than'));
      });

      test('should not apply recurring task logic for different parents', () {
        // Arrange - Same task ID but different recurrence parents
        final now = DateTime.now().toUtc();
        final tomorrow = now.add(const Duration(days: 1));

        final localTask = Task(
          id: 'task-instance-1', // Same ID
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-1',
        );

        final remoteTask = Task(
          id: 'task-instance-1', // Same ID - conflict scenario
          createdDate: now,
          title: 'Recurring Task',
          isCompleted: false,
          plannedDate: tomorrow,
          recurrenceType: RecurrenceType.daily,
          recurrenceParentId: 'parent-task-2', // Different parent
        );

        // Act
        final result = conflictResolutionService.resolveConflict(localTask, remoteTask);

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
        final result = conflictResolutionService.resolveConflict(localHabitRecord, remoteHabitRecord);

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
        final result = conflictResolutionService.resolveConflict(localHabitRecord, remoteHabitRecord);

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
        final result = conflictResolutionService.resolveConflict(localHabitRecord, remoteHabitRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemoteForceUpdate);
        expect(result.reason, contains('identical'));
      });
    });
  });
}

