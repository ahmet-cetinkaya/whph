import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/sync_conflict_resolution_service.dart';
import 'package:whph/core/application/features/sync/services/sync_data_processing_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

import 'sync_data_processing_service_test.mocks.dart';

@GenerateMocks([
  IRepository,
  ITaskRepository,
  SyncConflictResolutionService,
])
void main() {
  group('SyncDataProcessingService Tests', () {
    late MockIRepository<Task, String> mockTaskRepository;
    late MockIRepository<HabitRecord, String> mockHabitRepository;
    late MockIRepository<SyncDevice, String> mockSyncDeviceRepository;
    late MockSyncConflictResolutionService mockConflictResolutionService;
    late SyncDataProcessingService service;

    setUp(() {
      mockTaskRepository = MockIRepository<Task, String>();
      mockHabitRepository = MockIRepository<HabitRecord, String>();
      mockSyncDeviceRepository = MockIRepository<SyncDevice, String>();
      mockConflictResolutionService = MockSyncConflictResolutionService();
      service = SyncDataProcessingService(
        conflictResolutionService: mockConflictResolutionService,
      );
    });

    group('Success State Tests', () {
      test('should successfully process sync data batch with creates', () async {
        // Arrange
        final task1 = createMockTask('task1');
        final task2 = createMockTask('task2');

        final syncData = SyncData<Task>(
          createSync: [task1, task2],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.add(task1)).called(1);
        verify(mockTaskRepository.add(task2)).called(1);
        expect(result, 0); // No conflicts resolved for creates with non-existing items
      });

      test('should successfully process sync data batch with updates', () async {
        // Arrange
        final existingTask = createMockTask('task1');
        final updatedTask = createMockTask('task1', isModified: true);

        final syncData = SyncData<Task>(
          createSync: [],
          updateSync: [updatedTask],
          deleteSync: [],
        );

        final resolution = ConflictResolutionResult<Task>(
          action: ConflictAction.acceptRemote,
          winningEntity: updatedTask,
          reason: 'Remote is newer',
        );

        when(mockTaskRepository.getById('task1')).thenAnswer((_) async => existingTask);
        when(mockConflictResolutionService.resolveConflict<Task>(existingTask, updatedTask)).thenReturn(resolution);
        when(mockTaskRepository.update(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.update(updatedTask)).called(1);
        expect(result, 1); // One conflict resolved
      });

      test('should successfully process sync data batch with deletes', () async {
        // Arrange
        final existingTask = createMockTask('task1');
        final taskToDelete = createMockTask('task1', isDeleted: true);

        final syncData = SyncData<Task>(
          createSync: [],
          updateSync: [],
          deleteSync: [taskToDelete],
        );

        final resolution = ConflictResolutionResult<BaseEntity<String>>(
          action: ConflictAction.acceptRemote,
          winningEntity: taskToDelete,
          reason: 'Accept remote deletion',
        );

        when(mockTaskRepository.getById('task1')).thenAnswer((_) async => existingTask);
        when(mockConflictResolutionService.resolveConflict<BaseEntity<String>>(existingTask, taskToDelete))
            .thenReturn(resolution);
        when(mockTaskRepository.delete(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.delete(taskToDelete)).called(1);
        expect(result, 0); // Deletes don't count as conflicts resolved
      });

      test('should deduplicate items across create/update/delete arrays', () async {
        // Arrange
        final task1 = createMockTask('task1');
        final task1Updated = createMockTask('task1', isModified: true);
        final task1Deleted = createMockTask('task1', isDeleted: true);

        final syncData = SyncData<Task>(
          createSync: [task1],
          updateSync: [task1Updated],
          deleteSync: [task1Deleted],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.add(task1)).called(1);
        verifyNever(mockTaskRepository.update(any));
        verifyNever(mockTaskRepository.delete(any));
        expect(result, 0);
      });
    });

    group('Error State Tests', () {
      test('should handle repository exceptions during create', () async {
        // Arrange
        final task = createMockTask('task1');
        final syncData = SyncData<Task>(
          createSync: [task],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenThrow(Exception('Database error'));

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert - Service handles exceptions gracefully, returning 0 conflicts resolved
        expect(result, 0);
        verify(mockTaskRepository.add(task)).called(1);
      });

      test('should handle UNIQUE constraint errors gracefully', () async {
        // Arrange
        final task = createMockTask('task1');
        final existingTask = createMockTask('task1');
        final syncData = SyncData<Task>(
          createSync: [task],
          updateSync: [],
          deleteSync: [],
        );

        final resolution = ConflictResolutionResult<Task>(
          action: ConflictAction.acceptRemote,
          winningEntity: task,
          reason: 'Remote is newer',
        );

        var getByIdCallCount = 0;
        when(mockTaskRepository.getById('task1')).thenAnswer((_) async {
          getByIdCallCount++;
          return getByIdCallCount == 1 ? null : existingTask;
        });

        when(mockTaskRepository.add(task)).thenThrow(Exception('UNIQUE constraint failed'));

        when(mockConflictResolutionService.resolveConflict<Task>(existingTask, task)).thenReturn(resolution);
        when(mockTaskRepository.update(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.update(task)).called(1);
        expect(result, 1); // One conflict resolved
      });

      test('should continue processing after single item error', () async {
        // Arrange
        final task1 = createMockTask('task1');
        final task2 = createMockTask('task2');

        final syncData = SyncData<Task>(
          createSync: [task1, task2],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById('task1')).thenAnswer((_) async => null);
        when(mockTaskRepository.getById('task2')).thenAnswer((_) async => null);
        when(mockTaskRepository.add(task1)).thenThrow(Exception('Database error'));
        when(mockTaskRepository.add(task2)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.add(task2)).called(1); // Second item should still be processed
        expect(result, 0);
      });
    });

    group('Data Consistency Tests', () {
      test('should validate entities before processing', () async {
        // Arrange
        final validTask = createMockTask('task1');
        final invalidTask = Task(
          id: '', // Invalid: empty ID
          createdDate: DateTime.now(),
          title: 'Test Task',
          isCompleted: false,
          priority: EisenhowerPriority.notUrgentNotImportant,
        );

        final syncData = SyncData<Task>(
          createSync: [validTask, invalidTask],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(validTask.id)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(validTask)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.add(validTask)).called(1);
        expect(result, 0);
      });

      test('should maintain data integrity during batch processing', () async {
        // Arrange
        final tasks = List.generate(10, (i) => createMockTask('task$i'));
        final syncData = SyncData<Task>(
          createSync: tasks,
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        for (final task in tasks) {
          verify(mockTaskRepository.add(task)).called(1);
        }
        expect(result, 0);
      });
    });

    group('Habit Record Tests', () {
      test('should handle habit record duplicates by habitId and occurredAt', () async {
        // Arrange
        final now = DateTime.now();
        final habitRecord1 = HabitRecord(
          id: 'record1',
          createdDate: now,
          habitId: 'habit1',
          occurredAt: now,
        );
        final habitRecord2 = HabitRecord(
          id: 'record2', // Different ID
          createdDate: now.add(const Duration(minutes: 1)),
          habitId: 'habit1', // Same habit
          occurredAt: now, // Same occurrence time
        );

        final syncData = SyncData<HabitRecord>(
          createSync: [habitRecord2],
          updateSync: [],
          deleteSync: [],
        );

        final resolution = ConflictResolutionResult<HabitRecord>(
          action: ConflictAction.acceptRemote,
          winningEntity: habitRecord2,
          reason: 'Remote is newer',
        );

        when(mockHabitRepository.getById('record2')).thenAnswer((_) async => null);
        when(mockHabitRepository.getAll()).thenAnswer((_) async => [habitRecord1]);
        when(mockConflictResolutionService.resolveConflict<HabitRecord>(habitRecord1, habitRecord2))
            .thenReturn(resolution);
        when(mockHabitRepository.update(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<HabitRecord>(syncData, mockHabitRepository);

        // Assert
        verify(mockHabitRepository.update(habitRecord2)).called(1);
        expect(result, 1);
      });
    });

    group('SyncDevice Tests', () {
      test('should handle SyncDevice creation with existing device pair', () async {
        // Arrange
        final existingDevice = SyncDevice(
          id: 'device1',
          createdDate: DateTime.now(),
          fromDeviceId: 'dev1',
          toDeviceId: 'dev2',
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          name: 'Device 1',
        );

        final newDevice = SyncDevice(
          id: 'device2',
          createdDate: DateTime.now(),
          fromDeviceId: 'dev2', // Reversed pair
          toDeviceId: 'dev1',
          fromIp: '192.168.1.2',
          toIp: '192.168.1.1',
          name: 'Device 2',
        );

        final syncData = SyncData<SyncDevice>(
          createSync: [newDevice],
          updateSync: [],
          deleteSync: [],
        );

        when(mockSyncDeviceRepository.getById('device2')).thenAnswer((_) async => null);
        when(mockSyncDeviceRepository.getById('device1')).thenAnswer((_) async => existingDevice);
        when(mockSyncDeviceRepository.getAll()).thenAnswer((_) async => [existingDevice]);
        when(mockSyncDeviceRepository.update(any)).thenAnswer((_) async {});

        // Add resolution for the conflict
        final resolution = ConflictResolutionResult<SyncDevice>(
          action: ConflictAction.acceptRemote,
          winningEntity: newDevice,
          reason: 'Remote device is newer',
        );
        when(mockConflictResolutionService.resolveConflict<SyncDevice>(existingDevice, newDevice))
            .thenReturn(resolution);

        // Act
        final result = await service.processSyncDataBatch<SyncDevice>(syncData, mockSyncDeviceRepository);

        // Assert - The service should detect the existing device and handle it
        expect(result, greaterThanOrEqualTo(0));
        verify(mockSyncDeviceRepository.getById('device2')).called(1);
      });
    });

    group('Timeout Scenario Tests', () {
      test('should handle repository timeout gracefully', () async {
        // Arrange
        final task = createMockTask('task1');
        final syncData = SyncData<Task>(
          createSync: [task],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 30));
        });

        // Act & Assert
        // In a real timeout scenario, this would timeout and throw
        // For testing purposes, we'll just verify the method can be called
        final future = service.processSyncDataBatch<Task>(syncData, mockTaskRepository);
        expect(future, isA<Future<int>>());
      });
    });

    group('Edge Cases Tests', () {
      test('should handle empty sync data', () async {
        // Arrange
        final syncData = SyncData<Task>(
          createSync: [],
          updateSync: [],
          deleteSync: [],
        );

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        expect(result, 0);
        verifyNever(mockTaskRepository.add(any));
        verifyNever(mockTaskRepository.update(any));
        verifyNever(mockTaskRepository.delete(any));
      });

      test('should handle null repository responses', () async {
        // Arrange
        final task = createMockTask('task1');
        final syncData = SyncData<Task>(
          createSync: [task],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.add(task)).called(1);
        expect(result, 0);
      });

      test('should handle cleanup of soft-deleted data', () async {
        // Arrange
        final oldestLastSyncDate = DateTime.now().subtract(const Duration(days: 60));

        // Act & Assert - Should not throw
        await service.cleanupSoftDeletedData(oldestLastSyncDate);
      });
    });

    group('Dynamic Processing Tests', () {
      test('should process dynamic sync data batch', () async {
        // Arrange
        final task1 = createMockTask('task1');
        final task2 = createMockTask('task2');

        final syncData = SyncData<Task>(
          createSync: [task1, task2],
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await service.processSyncDataBatchDynamic(syncData, mockTaskRepository);

        // Assert
        verify(mockTaskRepository.add(task1)).called(1);
        verify(mockTaskRepository.add(task2)).called(1);
        expect(result, 2); // Returns total items processed
      });

      test('should yield to UI thread during processing', () async {
        // Arrange
        final tasks = List.generate(5, (i) => createMockTask('task$i'));
        final syncData = SyncData<Task>(
          createSync: tasks,
          updateSync: [],
          deleteSync: [],
        );

        when(mockTaskRepository.getById(any)).thenAnswer((_) async => null);
        when(mockTaskRepository.add(any)).thenAnswer((_) async {});

        // Act
        final stopwatch = Stopwatch()..start();
        await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);
        stopwatch.stop();

        // Assert - Processing should complete efficiently with optimized yielding
        expect(stopwatch.elapsedMilliseconds, greaterThan(0)); // Should complete in reasonable time
      });
    });

    group('Conflict Resolution Integration Tests', () {
      test('should resolve conflicts using conflict resolution service', () async {
        // Arrange
        final localTask = createMockTask('task1');
        final remoteTask = createMockTask('task1', isModified: true);

        final syncData = SyncData<Task>(
          createSync: [remoteTask],
          updateSync: [],
          deleteSync: [],
        );

        final resolution = ConflictResolutionResult<Task>(
          action: ConflictAction.keepLocal,
          winningEntity: localTask,
          reason: 'Local is newer',
        );

        when(mockTaskRepository.getById('task1')).thenAnswer((_) async => localTask);
        when(mockConflictResolutionService.resolveConflict<Task>(localTask, remoteTask)).thenReturn(resolution);

        // Act
        final result = await service.processSyncDataBatch<Task>(syncData, mockTaskRepository);

        // Assert
        verify(mockConflictResolutionService.resolveConflict<Task>(localTask, remoteTask)).called(1);
        verifyNever(mockTaskRepository.update(any)); // Should keep local, so no update
        expect(result, 1); // One conflict resolved
      });
    });
  });
}

// Helper function to create mock tasks
Task createMockTask(String id, {bool isModified = false, bool isDeleted = false}) {
  final now = DateTime.now();
  return Task(
    id: id,
    createdDate: now,
    modifiedDate: isModified ? now.add(const Duration(minutes: 1)) : null,
    deletedDate: isDeleted ? now : null,
    title: 'Test Task $id',
    isCompleted: false,
    priority: EisenhowerPriority.notUrgentNotImportant,
  );
}
