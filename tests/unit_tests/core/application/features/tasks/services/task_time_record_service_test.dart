import 'package:flutter_test/flutter_test.dart';
import 'package:application/features/tasks/services/task_time_record_service.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:application/shared/utils/key_helper.dart';
import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:application/features/sync/models/sync_data.dart';

// Mock repository implementation for testing
class MockTaskTimeRecordRepository implements ITaskTimeRecordRepository {
  final List<TaskTimeRecord> _records = [];

  @override
  Future<TaskTimeRecord?> getFirst(CustomWhereFilter customWhereFilter, {bool includeDeleted = false}) async {
    // The actual call in the service is:
    // final filter = CustomWhereFilter('task_id = ? AND created_date >= ? AND created_date < ?', [taskId, startOfHour, endOfHour]);
    // So we extract values from the filter to find the record
    if (customWhereFilter.query.contains('task_id = ?') && customWhereFilter.variables.length >= 3) {
      final taskId = customWhereFilter.variables[0] as String;
      final startOfHour = customWhereFilter.variables[1] as DateTime;

      final result = _records
          .where(
            (record) => record.taskId == taskId && record.createdDate.isAtSameMomentAs(startOfHour),
          )
          .toList();
      return result.isEmpty ? null : result.first;
    }
    return null;
  }

  @override
  Future<void> add(TaskTimeRecord entity) async {
    _records.add(entity);
  }

  @override
  Future<void> update(TaskTimeRecord entity) async {
    final index = _records.indexWhere((record) => record.id == entity.id);
    if (index != -1) {
      _records[index] = entity;
    }
  }

  // Implementation of acore.IRepository methods
  @override
  Future<List<TaskTimeRecord>> getAll(
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async {
    return _records;
  }

  @override
  Future<TaskTimeRecord?> getById(String id, {bool includeDeleted = false}) async {
    final result = _records.where((record) => record.id == id).toList();
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<PaginatedList<TaskTimeRecord>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async {
    return PaginatedList<TaskTimeRecord>(
      items: _records,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: _records.length,
    );
  }

  @override
  Future<void> delete(TaskTimeRecord id) async {
    _records.removeWhere((record) => record.id == id.id);
  }

  // Implementation of app.IRepository methods
  @override
  Future<PaginatedSyncData<TaskTimeRecord>> getPaginatedSyncData(DateTime lastSyncDate,
      {int pageIndex = 0, int pageSize = 200, String? entityType}) async {
    return PaginatedSyncData<TaskTimeRecord>(
      data: SyncData<TaskTimeRecord>(
        createSync: _records,
        updateSync: [],
        deleteSync: [],
      ),
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalPages: 1,
      totalItems: _records.length,
      isLastPage: true,
      entityType: entityType ?? 'TaskTimeRecord',
    );
  }

  @override
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate) async {}

  @override
  Future<void> truncate() async {
    _records.clear();
  }

  // Implementation of ITaskTimeRecordRepository-specific methods
  @override
  Future<List<TaskTimeRecord>> getByTaskId(String taskId) async {
    return _records.where((record) => record.taskId == taskId).toList();
  }

  @override
  Future<int> getTotalDurationByTaskId(String taskId, {DateTime? startDate, DateTime? endDate}) async {
    final records = await getByTaskId(taskId);
    var total = 0;
    for (final record in records) {
      total += record.duration;
    }
    return total;
  }

  @override
  Future<Map<String, int>> getTotalDurationsByTaskIds(List<String> taskIds,
      {DateTime? startDate, DateTime? endDate}) async {
    final result = <String, int>{};
    for (final taskId in taskIds) {
      result[taskId] = await getTotalDurationByTaskId(taskId, startDate: startDate, endDate: endDate);
    }
    return result;
  }

  // Additional methods to help with testing
  void clear() {
    _records.clear();
  }

  List<TaskTimeRecord> getAllRecords() => _records.toList();
}

// Error throwing repository for testing specific error scenarios
class _ErrorThrowingTaskTimeRecordRepository implements ITaskTimeRecordRepository {
  final String methodToThrow;
  final String errorMessage;

  _ErrorThrowingTaskTimeRecordRepository({
    required this.methodToThrow,
    required this.errorMessage,
  });

  @override
  Future<TaskTimeRecord?> getFirst(CustomWhereFilter customWhereFilter, {bool includeDeleted = false}) async {
    if (methodToThrow == 'getFirst') {
      throw Exception(errorMessage);
    }
    return null;
  }

  @override
  Future<void> add(TaskTimeRecord entity) async {
    if (methodToThrow == 'add') {
      throw Exception(errorMessage);
    }
  }

  @override
  Future<void> update(TaskTimeRecord entity) async {
    if (methodToThrow == 'update') {
      throw Exception(errorMessage);
    }
  }

  // Implementation of acore.IRepository methods
  @override
  Future<List<TaskTimeRecord>> getAll(
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async {
    if (methodToThrow == 'getAll') {
      throw Exception(errorMessage);
    }
    return [];
  }

  @override
  Future<TaskTimeRecord?> getById(String id, {bool includeDeleted = false}) async {
    if (methodToThrow == 'getById') {
      throw Exception(errorMessage);
    }
    return null;
  }

  @override
  Future<PaginatedList<TaskTimeRecord>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async {
    if (methodToThrow == 'getList') {
      throw Exception(errorMessage);
    }
    return PaginatedList<TaskTimeRecord>(
      items: [],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: 0,
    );
  }

  @override
  Future<void> delete(TaskTimeRecord id) async {
    if (methodToThrow == 'delete') {
      throw Exception(errorMessage);
    }
  }

  // Implementation of app.IRepository methods
  @override
  Future<PaginatedSyncData<TaskTimeRecord>> getPaginatedSyncData(DateTime lastSyncDate,
      {int pageIndex = 0, int pageSize = 200, String? entityType}) async {
    if (methodToThrow == 'getPaginatedSyncData') {
      throw Exception(errorMessage);
    }
    return PaginatedSyncData<TaskTimeRecord>(
      data: SyncData<TaskTimeRecord>(
        createSync: [],
        updateSync: [],
        deleteSync: [],
      ),
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalPages: 0,
      totalItems: 0,
      isLastPage: true,
      entityType: entityType ?? 'TaskTimeRecord',
    );
  }

  @override
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate) async {
    if (methodToThrow == 'hardDeleteSoftDeleted') {
      throw Exception(errorMessage);
    }
  }

  @override
  Future<void> truncate() async {
    if (methodToThrow == 'truncate') {
      throw Exception(errorMessage);
    }
  }

  // Implementation of ITaskTimeRecordRepository-specific methods
  @override
  Future<List<TaskTimeRecord>> getByTaskId(String taskId) async {
    if (methodToThrow == 'getByTaskId') {
      throw Exception(errorMessage);
    }
    return [];
  }

  @override
  Future<int> getTotalDurationByTaskId(String taskId, {DateTime? startDate, DateTime? endDate}) async {
    if (methodToThrow == 'getTotalDurationByTaskId') {
      throw Exception(errorMessage);
    }
    return 0;
  }

  @override
  Future<Map<String, int>> getTotalDurationsByTaskIds(List<String> taskIds,
      {DateTime? startDate, DateTime? endDate}) async {
    if (methodToThrow == 'getTotalDurationsByTaskIds') {
      throw Exception(errorMessage);
    }
    return {};
  }
}

void main() {
  late MockTaskTimeRecordRepository mockRepository;

  setUp(() {
    mockRepository = MockTaskTimeRecordRepository();
  });

  group('TaskTimeRecordService Tests', () {
    group('createHourBoundaries', () {
      test('should create correct hour boundaries for a given date', () {
        // Arrange
        final date = DateTime.utc(2024, 1, 15, 14, 30, 45); // 2:30 PM with 45 seconds

        // Act
        final (startOfHour, endOfHour) = TaskTimeRecordService.createHourBoundaries(date);

        // Assert
        expect(startOfHour.year, 2024);
        expect(startOfHour.month, 1);
        expect(startOfHour.day, 15);
        expect(startOfHour.hour, 14); // 2 PM
        expect(startOfHour.minute, 0);
        expect(startOfHour.second, 0);
        expect(startOfHour.millisecond, 0);
        expect(startOfHour.microsecond, 0);

        expect(endOfHour.year, 2024);
        expect(endOfHour.month, 1);
        expect(endOfHour.day, 15);
        expect(endOfHour.hour, 15); // 3 PM
        expect(endOfHour.minute, 0);
        expect(endOfHour.second, 0);
        expect(endOfHour.millisecond, 0);
        expect(endOfHour.microsecond, 0);
      });

      test('should handle midnight correctly', () {
        // Arrange
        final date = DateTime.utc(2024, 1, 15, 0, 15, 30); // 12:15 AM

        // Act
        final (startOfHour, endOfHour) = TaskTimeRecordService.createHourBoundaries(date);

        // Assert
        expect(startOfHour.year, 2024);
        expect(startOfHour.month, 1);
        expect(startOfHour.day, 15);
        expect(startOfHour.hour, 0); // 12 AM
        expect(startOfHour.minute, 0);
        expect(startOfHour.second, 0);

        expect(endOfHour.year, 2024);
        expect(endOfHour.month, 1);
        expect(endOfHour.day, 15);
        expect(endOfHour.hour, 1); // 1 AM
        expect(endOfHour.minute, 0);
        expect(endOfHour.second, 0);
      });

      test('should handle end of day correctly', () {
        // Arrange
        final date = DateTime.utc(2024, 1, 15, 23, 45, 30); // 11:45 PM

        // Act
        final (startOfHour, endOfHour) = TaskTimeRecordService.createHourBoundaries(date);

        // Assert
        expect(startOfHour.year, 2024);
        expect(startOfHour.month, 1);
        expect(startOfHour.day, 15);
        expect(startOfHour.hour, 23); // 11 PM
        expect(startOfHour.minute, 0);
        expect(startOfHour.second, 0);

        expect(endOfHour.year, 2024);
        expect(endOfHour.month, 1);
        expect(endOfHour.day, 16); // Next day
        expect(endOfHour.hour, 0); // 12 AM
        expect(endOfHour.minute, 0);
        expect(endOfHour.second, 0);
      });
    });

    group('findOrCreateTaskTimeRecord', () {
      test('should find existing task time record in same hour bucket', () async {
        // Arrange
        final taskId = 'task-1';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final (startOfHour, _) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final existingRecord = TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          createdDate: startOfHour, // 2 PM (same hour bucket)
          taskId: taskId,
          duration: 120,
        );
        await mockRepository.add(existingRecord);

        // Act
        final result = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
        );

        // Assert
        expect(result.id, existingRecord.id);
        expect(result.duration, 120);
        expect(result.createdDate.hour, 14); // 2 PM
      });

      test('should create new task time record when none exists in hour bucket', () async {
        // Arrange
        final taskId = 'task-2';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final initialDuration = 0;

        // Act
        final result = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          initialDuration: initialDuration,
        );

        // Assert
        expect(result.id, isNotNull);
        expect(result.id, isNot(''));
        expect(result.taskId, taskId);
        expect(result.duration, initialDuration);
        expect(result.createdDate.hour, 14); // Same hour as target date
        expect(result.createdDate.minute, 0); // Start of hour
      });

      test('should use provided initial duration when creating new record', () async {
        // Arrange
        final taskId = 'task-3';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final initialDuration = 180;

        // Act
        final result = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          initialDuration: initialDuration,
        );

        // Assert
        expect(result.duration, initialDuration);
      });

      test('should create record with correct hour bucket for different dates', () async {
        // Arrange
        final taskId = 'task-4';
        final targetDate1 = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final targetDate2 = DateTime.utc(2024, 1, 15, 14, 45, 0); // 2:45 PM (same hour bucket)
        final targetDate3 = DateTime.utc(2024, 1, 15, 15, 10, 0); // 3:10 PM (different hour bucket)

        // Act - Create the first record
        final result1 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate1,
        );

        // Act - Find the existing one in the same hour bucket
        final result2 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate2,
        );

        // Act - Create a new one in a different hour bucket
        final result3 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate3,
        );

        // Assert
        expect(result1.id, result2.id); // Same record since same hour bucket
        expect(result3.id, isNot(result1.id)); // Different record since different hour bucket
        expect(result3.createdDate.hour, 15); // 3 PM
        expect(result1.createdDate.hour, 14); // 2 PM
      });
    });

    group('addDurationToTaskTimeRecord', () {
      test('should add duration to existing task time record', () async {
        // Arrange
        final taskId = 'task-5';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final (startOfHour, _) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final existingRecord = TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          createdDate: startOfHour, // 2 PM bucket
          taskId: taskId,
          duration: 120,
        );
        await mockRepository.add(existingRecord);
        final durationToAdd = 60;

        // Act
        final result = await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          durationToAdd: durationToAdd,
        );

        // Assert
        expect(result.duration, 120 + 60); // Original 120 + added 60
        // Verify the record was updated in the repository
        final (startOfHourCheck, endOfHourCheck) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final filter = CustomWhereFilter(
            'task_id = ? AND created_date >= ? AND created_date < ?', [taskId, startOfHourCheck, endOfHourCheck]);
        final updatedRecord = await mockRepository.getFirst(filter);
        expect(updatedRecord!.duration, 180);
      });

      test('should create new record with specified duration if none exists', () async {
        // Arrange
        final taskId = 'task-6';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final durationToAdd = 90;

        // Act
        final result = await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          durationToAdd: durationToAdd,
        );

        // Assert
        expect(result.duration, durationToAdd); // New record starts with the added duration
        expect(result.createdDate.hour, 14); // Same hour as target date
        expect(result.createdDate.minute, 0); // Start of hour
      });

      test('should handle multiple duration additions correctly', () async {
        // Arrange
        final taskId = 'task-7';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final firstAddition = 100;
        final secondAddition = 50;
        final thirdAddition = 25;

        // Act - First addition
        final result1 = await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          durationToAdd: firstAddition,
        );

        // Act - Second addition
        final result2 = await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          durationToAdd: secondAddition,
        );

        // Act - Third addition
        final result3 = await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          durationToAdd: thirdAddition,
        );

        // Assert
        expect(result1.duration, firstAddition);
        expect(result2.duration, firstAddition + secondAddition);
        expect(result3.duration, firstAddition + secondAddition + thirdAddition);
      });
    });

    group('setTotalDurationForTaskTimeRecord', () {
      test('should set total duration for existing task time record', () async {
        // Arrange
        final taskId = 'task-8';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final (startOfHour, _) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final existingRecord = TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          createdDate: startOfHour, // 2 PM bucket
          taskId: taskId,
          duration: 120,
        );
        await mockRepository.add(existingRecord);
        final newTotalDuration = 240;

        // Act
        final result = await TaskTimeRecordService.setTotalDurationForTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          totalDuration: newTotalDuration,
        );

        // Assert
        expect(result.duration, newTotalDuration);
        // Verify the record was updated in the repository
        final (startOfHourCheck, endOfHourCheck) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final filter = CustomWhereFilter(
            'task_id = ? AND created_date >= ? AND created_date < ?', [taskId, startOfHourCheck, endOfHourCheck]);
        final updatedRecord = await mockRepository.getFirst(filter);
        expect(updatedRecord!.duration, newTotalDuration);
      });

      test('should create new record with specified total duration if none exists', () async {
        // Arrange
        final taskId = 'task-9';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final newTotalDuration = 150;

        // Act
        final result = await TaskTimeRecordService.setTotalDurationForTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          totalDuration: newTotalDuration,
        );

        // Assert
        expect(result.duration, newTotalDuration);
        expect(result.createdDate.hour, 14); // Same hour as target date
        expect(result.createdDate.minute, 0); // Start of hour
      });

      test('should overwrite existing duration with new total', () async {
        // Arrange
        final taskId = 'task-10';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM
        final (startOfHour, _) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final existingRecord = TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          createdDate: startOfHour, // 2 PM bucket
          taskId: taskId,
          duration: 100,
        );
        await mockRepository.add(existingRecord);
        final newTotalDuration = 300;

        // Act
        final result = await TaskTimeRecordService.setTotalDurationForTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          totalDuration: newTotalDuration,
        );

        // Assert
        expect(result.duration, newTotalDuration); // Should be the new total, not original + new
      });
    });

    group('Edge Cases', () {
      test('should handle different minute values in same hour bucket', () async {
        // Arrange
        final taskId = 'task-edge-1';
        final date1 = DateTime.utc(2024, 1, 15, 14, 5, 0); // 2:05 PM
        final date2 = DateTime.utc(2024, 1, 15, 14, 55, 0); // 2:55 PM (same bucket)

        // Act
        final result1 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: date1,
        );
        final result2 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: date2,
        );

        // Assert - Should be the same record since in same hour bucket
        expect(result1.id, result2.id);
        expect(result1.createdDate, DateTime.utc(2024, 1, 15, 14, 0, 0)); // Start of the hour
      });

      test('should handle different second values in same hour bucket', () async {
        // Arrange
        final taskId = 'task-edge-2';
        final date1 = DateTime.utc(2024, 1, 15, 14, 30, 5); // 2:30:05 PM
        final date2 = DateTime.utc(2024, 1, 15, 14, 30, 55); // 2:30:55 PM (same bucket)

        // Act
        final result1 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: date1,
        );
        final result2 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: date2,
        );

        // Assert - Should be the same record since in same hour bucket
        expect(result1.id, result2.id);
        expect(result1.createdDate, DateTime.utc(2024, 1, 15, 14, 0, 0)); // Start of the hour
      });

      test('should handle different tasks in same hour', () async {
        // Arrange
        final taskId1 = 'task-edge-3a';
        final taskId2 = 'task-edge-3b';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM

        // Act
        final result1 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId1,
          targetDate: targetDate,
        );
        final result2 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId2,
          targetDate: targetDate,
        );

        // Assert - Should be different records since different tasks
        expect(result1.id, isNot(result2.id));
        expect(result1.taskId, taskId1);
        expect(result2.taskId, taskId2);
        expect(result1.createdDate.hour, 14); // Same hour
        expect(result2.createdDate.hour, 14); // Same hour
      });

      test('should handle boundary conditions for hour start/end', () async {
        // Arrange
        final taskId = 'task-edge-4';
        final startOfHour = DateTime.utc(2024, 1, 15, 14, 0, 0); // Exactly 2:00 PM
        final endOfHour = DateTime.utc(2024, 1, 15, 14, 59, 59); // 2:59:59 PM

        // Act
        final result1 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: startOfHour,
        );
        final result2 = await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: endOfHour,
        );

        // Assert - Should be the same record since in same hour bucket
        expect(result1.id, result2.id);
        expect(result1.createdDate, DateTime.utc(2024, 1, 15, 14, 0, 0)); // Start of the hour
      });
    });

    group('Performance Scenarios', () {
      test('should efficiently handle multiple operations in same hour bucket', () async {
        // Arrange
        final taskId = 'perf-test-1';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM

        // Act - Perform multiple operations
        final startTime = DateTime.now();
        for (int i = 0; i < 100; i++) {
          await TaskTimeRecordService.addDurationToTaskTimeRecord(
            repository: mockRepository,
            taskId: taskId,
            targetDate: targetDate,
            durationToAdd: 10,
          );
        }
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Assert - Operations should complete quickly
        expect(duration.inMilliseconds, lessThan(2000)); // Less than 2 seconds
        final (startOfHourCheck, endOfHourCheck) = TaskTimeRecordService.createHourBoundaries(targetDate);
        final filter = CustomWhereFilter(
            'task_id = ? AND created_date >= ? AND created_date < ?', [taskId, startOfHourCheck, endOfHourCheck]);
        final finalRecord = await mockRepository.getFirst(filter);
        expect(finalRecord!.duration, 1000); // 100 iterations * 10 duration each
      });

      test('should not create multiple records for same task in same hour across operations', () async {
        // Arrange
        final taskId = 'perf-test-2';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 45, 30); // 2:45:30 PM

        // Act - Multiple operations
        await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          initialDuration: 50,
        );

        await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          durationToAdd: 30,
        );

        await TaskTimeRecordService.setTotalDurationForTaskTimeRecord(
          repository: mockRepository,
          taskId: taskId,
          targetDate: targetDate,
          totalDuration: 200,
        );

        // Assert - Should still have only one record for this task in this hour
        final allRecords = mockRepository.getAllRecords();
        final taskRecords = allRecords.where((record) => record.taskId == taskId);
        expect(taskRecords.length, 1);
        expect(taskRecords.first.duration, 200); // Final duration after set operation
      });
    });

    group('Error Handling', () {
      test('should handle repository errors gracefully in findOrCreateTaskTimeRecord', () async {
        // Create a repository that throws errors
        final errorRepository = _ErrorThrowingTaskTimeRecordRepository(
          methodToThrow: 'getFirst',
          errorMessage: 'Database error',
        );

        final taskId = 'task-error-1';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM

        // Act & Assert
        expect(
          () => TaskTimeRecordService.findOrCreateTaskTimeRecord(
            repository: errorRepository,
            taskId: taskId,
            targetDate: targetDate,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle repository errors in addDurationToTaskTimeRecord', () async {
        // Create a repository that throws errors during update
        final errorRepository = _ErrorThrowingTaskTimeRecordRepository(
          methodToThrow: 'update',
          errorMessage: 'Database error during update',
        );

        final taskId = 'task-error-2';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM

        // Add a record first using a working repository to set up state
        final setupRepository = MockTaskTimeRecordRepository();
        await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: setupRepository,
          taskId: taskId,
          targetDate: targetDate,
        );

        // Act & Assert - This should trigger the error during update
        expect(
          () => TaskTimeRecordService.addDurationToTaskTimeRecord(
            repository: errorRepository,
            taskId: taskId,
            targetDate: targetDate,
            durationToAdd: 60,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle repository errors in setTotalDurationForTaskTimeRecord', () async {
        // Create a repository that throws errors during update
        final errorRepository = _ErrorThrowingTaskTimeRecordRepository(
          methodToThrow: 'update',
          errorMessage: 'Database error during update',
        );

        final taskId = 'task-error-3';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM

        // Add a record first using a working repository to set up state
        final setupRepository = MockTaskTimeRecordRepository();
        await TaskTimeRecordService.findOrCreateTaskTimeRecord(
          repository: setupRepository,
          taskId: taskId,
          targetDate: targetDate,
        );

        // Act & Assert - This should trigger the error during update
        expect(
          () => TaskTimeRecordService.setTotalDurationForTaskTimeRecord(
            repository: errorRepository,
            taskId: taskId,
            targetDate: targetDate,
            totalDuration: 180,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle repository errors when adding new record', () async {
        // Create a repository that throws errors during add
        final errorRepository = _ErrorThrowingTaskTimeRecordRepository(
          methodToThrow: 'add',
          errorMessage: 'Database error during add',
        );

        final taskId = 'task-error-4';
        final targetDate = DateTime.utc(2024, 1, 15, 14, 30, 0); // 2:30 PM

        // Act & Assert - This should trigger the error during add operation
        expect(
          () => TaskTimeRecordService.findOrCreateTaskTimeRecord(
            repository: errorRepository,
            taskId: taskId,
            targetDate: targetDate,
            initialDuration: 100,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
