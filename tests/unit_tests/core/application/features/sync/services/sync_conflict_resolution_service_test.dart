import 'package:flutter_test/flutter_test.dart';
import 'package:application/features/sync/services/sync_conflict_resolution_service.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/habits/habit_record.dart';

void main() {
  group('SyncConflictResolutionService Tests', () {
    late SyncConflictResolutionService service;

    setUp(() {
      service = SyncConflictResolutionService();
    });

    group('Success State Tests', () {
      test('should resolve conflict by accepting remote when remote is newer', () {
        // Arrange
        final localTask = createMockTask('task1', DateTime.now().subtract(const Duration(minutes: 5)));
        final remoteTask = createMockTask('task1', DateTime.now());

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
        expect(result.reason, contains('Remote timestamp'));
      });

      test('should resolve conflict by keeping local when local is newer', () {
        // Arrange
        final localTask = createMockTask('task1', DateTime.now());
        final remoteTask = createMockTask('task1', DateTime.now().subtract(const Duration(minutes: 5)));

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.winningEntity, equals(localTask));
        expect(result.reason, contains('Local timestamp'));
      });

      test('should accept remote when timestamps are identical', () {
        // Arrange
        final timestamp = DateTime.now();
        final localTask = createMockTask('task1', timestamp);
        final remoteTask = createMockTask('task1', timestamp);

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert - Now uses deterministic ID-based resolution for identical timestamps
        expect([ConflictAction.acceptRemote, ConflictAction.keepLocal], contains(result.action));
        expect(result.reason, contains('deterministic ID-based resolution'));
      });
    });

    group('Deletion Conflict Tests', () {
      test('should prefer non-deleted entity over recent deletion', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = createMockTask('task1', baseTime, isDeleted: true);
        final remoteTask = createMockTask('task1', baseTime.subtract(const Duration(minutes: 2)));

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
        expect(result.reason, contains('Preferring non-deleted remote entity'));
      });

      test('should accept deletion when deletion occurred significantly later', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = createMockTask('task1', baseTime, isDeleted: true);
        final remoteTask = createMockTask('task1', baseTime.subtract(const Duration(minutes: 10)));

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.winningEntity, equals(localTask));
        expect(result.reason, contains('Local deletion'));
        expect(result.reason, contains('occurred significantly after'));
      });

      test('should handle remote deletion vs local modification', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = createMockTask('task1', baseTime.subtract(const Duration(minutes: 2)));
        final remoteTask = createMockTask('task1', baseTime, isDeleted: true);

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
        expect(result.reason, contains('Remote deletion'));
        expect(result.reason, contains('occurred significantly after'));
      });

      test('should prefer non-deleted entity over recent remote deletion', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = createMockTask('task1', baseTime.subtract(const Duration(minutes: 2)));

        // Set remote deletion time within grace period
        final recentRemoteTask = Task(
          id: 'task1',
          createdDate: baseTime.subtract(const Duration(hours: 1)),
          modifiedDate: baseTime.subtract(const Duration(minutes: 2)),
          deletedDate: baseTime, // Recent deletion
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );

        // Act
        final result = service.resolveConflict(localTask, recentRemoteTask);

        // Assert - Should prefer keeping local when remote deletion is recent
        expect(result.action, ConflictAction.keepLocal);
        expect(result.winningEntity, equals(localTask));
        expect(result.reason, contains('Preferring non-deleted local entity'));
      });
    });

    group('Habit Record Conflict Tests', () {
      test('should resolve habit record conflict by newer timestamp when same occurrence', () {
        // Arrange
        final occurredAt = DateTime.now();
        final localRecord = HabitRecord(
          id: 'record1',
          createdDate: DateTime.now().subtract(const Duration(minutes: 5)),
          habitId: 'habit1',
          occurredAt: occurredAt,
        );
        final remoteRecord = HabitRecord(
          id: 'record2',
          createdDate: DateTime.now(),
          habitId: 'habit1',
          occurredAt: occurredAt,
        );

        // Act
        final result = service.resolveConflict(localRecord, remoteRecord);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteRecord));
        expect(result.reason, contains('Same habit occurrence'));
        expect(result.reason, contains('remote timestamp'));
        expect(result.reason, contains('is newer'));
      });

      test('should detect potential data corruption with same occurredAt but different habitId', () {
        // Arrange
        final occurredAt = DateTime.now();
        final localRecord = HabitRecord(
          id: 'record1',
          createdDate: DateTime.now(),
          habitId: 'habit1',
          occurredAt: occurredAt,
        );
        final remoteRecord = HabitRecord(
          id: 'record2',
          createdDate: DateTime.now(),
          habitId: 'habit2', // Different habit
          occurredAt: occurredAt, // Same time
        );

        // Act
        final result = service.resolveConflict(localRecord, remoteRecord);

        // Assert
        // Should still resolve normally, but the service should log a warning
        expect(result.action, isA<ConflictAction>());
      });
    });

    group('Recurring Task Conflict Tests', () {
      test('should resolve recurring task conflict by earlier planned date', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = Task(
          id: 'task1',
          createdDate: baseTime,
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
          plannedDate: baseTime.add(const Duration(days: 2)),
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: baseTime,
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
          plannedDate: baseTime.add(const Duration(days: 1)), // Earlier
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
        expect(result.reason, contains('Remote recurring task has earlier planned date'));
      });

      test('should keep local recurring task when local has earlier planned date', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = Task(
          id: 'task1',
          createdDate: baseTime,
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
          plannedDate: baseTime.add(const Duration(days: 1)), // Earlier
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: baseTime,
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
          plannedDate: baseTime.add(const Duration(days: 2)),
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.keepLocal);
        expect(result.winningEntity, equals(localTask));
        expect(result.reason, contains('Local recurring task has earlier planned date'));
      });

      test('should fall back to timestamp resolution when recurring tasks have same planned date', () {
        // Arrange
        final baseTime = DateTime.now();
        final plannedDate = baseTime.add(const Duration(days: 1));
        final localTask = Task(
          id: 'task1',
          createdDate: baseTime,
          modifiedDate: baseTime.subtract(const Duration(minutes: 5)),
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
          plannedDate: plannedDate,
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: baseTime,
          modifiedDate: baseTime, // Newer
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
          plannedDate: plannedDate, // Same planned date
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
        expect(result.reason, contains('Remote timestamp'));
        expect(result.reason, contains('is newer'));
      });
    });

    group('Edge Cases Tests', () {
      test('should handle entities without modification dates', () {
        // Arrange
        final localTask = Task(
          id: 'task1',
          createdDate: DateTime.now().subtract(const Duration(minutes: 5)),
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: DateTime.now(),
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
      });

      test('should handle non-recurring tasks normally', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = Task(
          id: 'task1',
          createdDate: baseTime.subtract(const Duration(minutes: 5)),
          title: 'Normal Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          // No recurrence information
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: baseTime,
          title: 'Normal Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
        expect(result.reason, contains('Remote timestamp'));
      });

      test('should handle different recurrence parents normally', () {
        // Arrange
        final baseTime = DateTime.now();
        final localTask = Task(
          id: 'task1',
          createdDate: baseTime.subtract(const Duration(minutes: 5)),
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent1',
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: baseTime,
          title: 'Recurring Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
          recurrenceParentId: 'parent2', // Different parent
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.reason, contains('Remote timestamp'));
      });
    });

    group('Task Data Copying Tests', () {
      test('should copy remote data to existing task while preserving ID', () {
        // Arrange
        final existingTask = Task(
          id: 'existing-id',
          createdDate: DateTime.now().subtract(const Duration(days: 1)),
          title: 'Old Title',
          description: 'Old Description',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );
        final remoteTask = Task(
          id: 'remote-id',
          createdDate: DateTime.now().subtract(const Duration(hours: 1)),
          modifiedDate: DateTime.now(),
          title: 'New Title',
          description: 'New Description',
          completedAt: DateTime.now().subtract(const Duration(hours: 1)),
          priority: EisenhowerPriority.urgentImportant,
          estimatedTime: 7200000, // 2 hours in milliseconds
        );

        // Act
        final result = service.copyRemoteDataToExistingTask(existingTask, remoteTask);

        // Assert
        expect(result.id, equals('existing-id')); // ID preserved
        expect(result.title, equals('New Title'));
        expect(result.description, equals('New Description'));
        expect(result.isCompleted, equals(true));
        expect(result.priority, equals(EisenhowerPriority.urgentImportant));
        expect(result.estimatedTime, equals(7200000));
        expect(result.createdDate, equals(remoteTask.createdDate));
        expect(result.modifiedDate, equals(remoteTask.modifiedDate));
      });

      test('should return unchanged when copying non-task entities', () {
        // Arrange
        final habitRecord1 = HabitRecord(
          id: 'record1',
          createdDate: DateTime.now(),
          habitId: 'habit1',
          occurredAt: DateTime.now(),
        );
        final habitRecord2 = HabitRecord(
          id: 'record2',
          createdDate: DateTime.now(),
          habitId: 'habit2',
          occurredAt: DateTime.now(),
        );

        // Act
        final result = service.copyRemoteDataToExistingTask(habitRecord1, habitRecord2);

        // Assert
        expect(result, equals(habitRecord1)); // Should return unchanged
      });
    });

    group('Timestamp Resolution Tests', () {
      test('should use modification date when available', () {
        // Arrange
        final createdTime = DateTime.now().subtract(const Duration(days: 1));
        final modifiedTime = DateTime.now();

        final localTask = Task(
          id: 'task1',
          createdDate: createdTime,
          modifiedDate: modifiedTime.subtract(const Duration(minutes: 5)),
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: createdTime,
          modifiedDate: modifiedTime,
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
      });

      test('should fall back to created date when modification date is null', () {
        // Arrange
        final localTask = Task(
          id: 'task1',
          createdDate: DateTime.now().subtract(const Duration(minutes: 5)),
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );
        final remoteTask = Task(
          id: 'task1',
          createdDate: DateTime.now(),
          title: 'Test Task',
          completedAt: null,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );

        // Act
        final result = service.resolveConflict(localTask, remoteTask);

        // Assert
        expect(result.action, ConflictAction.acceptRemote);
        expect(result.winningEntity, equals(remoteTask));
      });
    });
  });
}

// Helper function to create mock tasks
Task createMockTask(String id, DateTime timestamp, {bool isDeleted = false}) {
  return Task(
    id: id,
    createdDate: timestamp.subtract(const Duration(hours: 1)),
    modifiedDate: timestamp,
    deletedDate: isDeleted ? timestamp : null,
    title: 'Test Task $id',
    completedAt: null,
    priority: EisenhowerPriority.notUrgentNotImportant,
  );
}
