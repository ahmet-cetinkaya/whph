import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:acore/acore.dart';

import 'save_task_command_test.mocks.dart';

@GenerateMocks([
  ITaskRepository,
  ITaskTagRepository,
  ITaskTimeRecordRepository,
  TaskTimeRecordService,
])
void main() {
  late SaveTaskCommandHandler handler;
  late MockITaskRepository mockTaskRepository;
  late MockITaskTagRepository mockTaskTagRepository;
  late MockITaskTimeRecordRepository mockTaskTimeRecordRepository;

  setUp(() {
    mockTaskRepository = MockITaskRepository();
    mockTaskTagRepository = MockITaskTagRepository();
    mockTaskTimeRecordRepository = MockITaskTimeRecordRepository();
    handler = SaveTaskCommandHandler(
      taskService: mockTaskRepository,
      taskTagRepository: mockTaskTagRepository,
      taskTimeRecordRepository: mockTaskTimeRecordRepository,
    );
  });

  group('SaveTaskCommandHandler Tests - Create', () {
    test('should create task when id is null', () async {
      // Arrange
      final command = SaveTaskCommand(
        title: 'Test Task',
        description: 'Test Description',
        priority: EisenhowerPriority.urgentImportant,
        estimatedTime: 30,
        completedAt: null,
      );

      when(mockTaskRepository.getList(
        0,
        1,
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).thenAnswer((_) async => PaginatedList<Task>(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      when(mockTaskRepository.add(any)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, isNotNull);
      verify(mockTaskRepository.add(argThat(
        predicate<Task>((task) =>
            task.title == 'Test Task' &&
            task.description == 'Test Description' &&
            task.priority == EisenhowerPriority.urgentImportant &&
            task.estimatedTime == 30 &&
            task.completedAt == null),
      ))).called(1);
    });

    test('should assign correct order when creating a task', () async {
      // Arrange
      final command = SaveTaskCommand(
        title: 'Test Task',
        description: 'Test Description',
        priority: EisenhowerPriority.urgentImportant,
        estimatedTime: 30,
        completedAt: null,
      );

      // Mock an existing task with order 1000
      final lastTask = Task(
        id: 'existing-task-id',
        createdDate: DateTime.now().toUtc(),
        title: 'Existing Task',
        order: 1000.0,
      );

      when(mockTaskRepository.getList(
        0,
        1,
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).thenAnswer((_) async => PaginatedList<Task>(items: [lastTask], totalItemCount: 1, pageIndex: 0, pageSize: 1));

      when(mockTaskRepository.add(any)).thenAnswer((_) async => Future.value());

      // Act
      await handler(command);

      // Assert
      verify(mockTaskRepository.add(argThat(
        predicate<Task>((task) => task.order == 2000.0 // 1000 + 1000 (last order + orderStep)
            ),
      ))).called(1);
    });

    test('should use provided order when creating a task', () async {
      // Arrange
      final command = SaveTaskCommand(
        title: 'Test Task',
        description: 'Test Description',
        priority: EisenhowerPriority.urgentImportant,
        estimatedTime: 30,
        completedAt: null,
        order: 500.0,
      );

      when(mockTaskRepository.getList(
        0,
        1,
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).thenAnswer((_) async => PaginatedList<Task>(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      when(mockTaskRepository.add(any)).thenAnswer((_) async => Future.value());

      // Act
      await handler(command);

      // Assert
      verify(mockTaskRepository.add(argThat(
        predicate<Task>((task) => task.order == 500.0 // Should use the provided order
            ),
      ))).called(1);
    });

    test('should handle completed task creation with time record', () async {
      // Arrange
      final command = SaveTaskCommand(
        title: 'Test Task',
        description: 'Test Description',
        priority: EisenhowerPriority.urgentImportant,
        estimatedTime: 30, // 30 minutes -> 1800 seconds
        completedAt: DateTime.now().toUtc(),
      );

      when(mockTaskRepository.getList(
        0,
        1,
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).thenAnswer((_) async => PaginatedList<Task>(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      when(mockTaskRepository.add(any)).thenAnswer((_) async => Future.value());

      // Simulate no existing time records for this task
      when(mockTaskTimeRecordRepository.getList(
        0,
        1,
        customWhereFilter: anyNamed('customWhereFilter'),
      )).thenAnswer((_) async => PaginatedList(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      // Mock getFirst to return null (no existing time record) - used by TaskTimeRecordService.findOrCreateTaskTimeRecord
      when(mockTaskTimeRecordRepository.getFirst(any, includeDeleted: false)).thenAnswer((_) async => null);

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, isNotNull);
      verify(mockTaskRepository.add(argThat(
        predicate<Task>(
            (task) => task.title == 'Test Task' && task.description == 'Test Description' && task.completedAt != null),
      ))).called(1);

      // Verify that repository methods were called to add and update time records
      // The TaskTimeRecordService.addDurationToTaskTimeRecord will call:
      // 1. getFirst to check if a record exists for the hour
      // 2. add to create a new record if none exists
      // 3. update to update the duration
      verify(mockTaskTimeRecordRepository.getFirst(any, includeDeleted: false)).called(1);
      verify(mockTaskTimeRecordRepository.add(any)).called(1); // Creating the new time record
      verify(mockTaskTimeRecordRepository.update(any)).called(1); // Updating the duration
    });
  });

  group('SaveTaskCommandHandler Tests - Update', () {
    test('should update existing task when id is provided', () async {
      // Arrange
      const taskId = 'task-1';
      final existingTask = Task(
        id: taskId,
        createdDate: DateTime.now().toUtc(),
        title: 'Old Title',
        description: 'Old Description',
        priority: EisenhowerPriority.urgentImportant,
        estimatedTime: 15,
        completedAt: null,
      );

      final command = SaveTaskCommand(
        id: taskId,
        title: 'New Title',
        description: 'New Description',
        priority: EisenhowerPriority.notUrgentImportant,
        estimatedTime: 45,
        completedAt: null,
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => existingTask);

      when(mockTaskRepository.update(any)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, taskId);
      verify(mockTaskRepository.getById(taskId)).called(1);
      verify(mockTaskRepository.update(argThat(
        predicate<Task>((task) =>
            task.id == taskId &&
            task.title == 'New Title' &&
            task.description == 'New Description' &&
            task.priority == EisenhowerPriority.notUrgentImportant &&
            task.estimatedTime == 45 &&
            task.completedAt == null),
      ))).called(1);
    });

    test('should complete task when completedAt is provided', () async {
      // Arrange
      const taskId = 'task-1';
      final existingTask = Task(
        id: taskId,
        createdDate: DateTime.now().toUtc(),
        title: 'Test Task',
        completedAt: null,
      );

      final command = SaveTaskCommand(
        id: taskId,
        title: 'Test Task',
        completedAt: DateTime.now().toUtc(),
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => existingTask);

      when(mockTaskRepository.update(any)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, taskId);
      verify(mockTaskRepository.getById(taskId)).called(1);
      verify(mockTaskRepository.update(argThat(
        predicate<Task>((task) => task.id == taskId && task.completedAt != null),
      ))).called(1);
    });

    test('should mark task as incomplete when completedAt is null', () async {
      // Arrange
      const taskId = 'task-1';
      final existingTask = Task(
        id: taskId,
        createdDate: DateTime.now().toUtc(),
        title: 'Test Task',
        completedAt: DateTime.now().toUtc(),
      );

      final command = SaveTaskCommand(
        id: taskId,
        title: 'Test Task',
        completedAt: null,
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => existingTask);

      when(mockTaskRepository.update(any)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, taskId);
      verify(mockTaskRepository.getById(taskId)).called(1);
      verify(mockTaskRepository.update(argThat(
        predicate<Task>((task) => task.id == taskId && task.completedAt == null),
      ))).called(1);
    });

    test('should throw BusinessException when updating non-existent task', () async {
      // Arrange
      const taskId = 'task-1';
      final command = SaveTaskCommand(
        id: taskId,
        title: 'New Title',
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => handler(command),
        throwsA(
          predicate((e) => e is BusinessException && e.message.contains('Task with id $taskId not found')),
        ),
      );
      verify(mockTaskRepository.getById(taskId)).called(1);
      verifyNever(mockTaskRepository.update(any));
    });

    test('should add tags to task when tagIdsToAdd is provided', () async {
      // Arrange
      const taskId = 'task-1';
      final existingTask = Task(
        id: taskId,
        createdDate: DateTime.now().toUtc(),
        title: 'Test Task',
        completedAt: null,
      );

      final command = SaveTaskCommand(
        id: taskId,
        title: 'Test Task',
        completedAt: null,
        tagIdsToAdd: ['tag-1', 'tag-2'],
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => existingTask);

      when(mockTaskRepository.update(any)).thenAnswer((_) async => Future.value());

      when(mockTaskTagRepository.add(any)).thenAnswer((_) async => Future.value());

      // Act
      await handler(command);

      // Assert - Using properly typed predicate for task tag verification
      verify(mockTaskTagRepository.add(argThat(predicate((obj) =>
          obj is Object &&
          obj.runtimeType.toString().contains('TaskTag') &&
          (obj as dynamic).taskId == taskId &&
          (obj as dynamic).tagId == 'tag-1')))).called(1);
      verify(mockTaskTagRepository.add(argThat(predicate((obj) =>
          obj is Object &&
          obj.runtimeType.toString().contains('TaskTag') &&
          (obj as dynamic).taskId == taskId &&
          (obj as dynamic).tagId == 'tag-2')))).called(1);
    });
  });

  group('SaveTaskCommandHandler Tests - Error Handling', () {
    test('should propagate repository exceptions', () async {
      // Arrange
      const taskId = 'task-1';
      final command = SaveTaskCommand(
        id: taskId,
        title: 'New Title',
      );

      when(mockTaskRepository.getById(taskId)).thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => handler(command),
        throwsException,
      );
      verify(mockTaskRepository.getById(taskId)).called(1);
      verifyNever(mockTaskRepository.update(any));
    });

    test('should handle null values correctly', () async {
      // Arrange
      final command = SaveTaskCommand(
        title: 'Test Task',
        description: null,
        priority: null,
        estimatedTime: null,
        completedAt: null,
      );

      when(mockTaskRepository.getList(
        0,
        1,
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).thenAnswer((_) async => PaginatedList<Task>(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1));

      when(mockTaskRepository.add(any)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, isNotNull);
      verify(mockTaskRepository.add(argThat(
        predicate<Task>((task) =>
                task.title == 'Test Task' &&
                task.description == null &&
                task.priority == null &&
                task.estimatedTime == TaskConstants.defaultEstimatedTime // Default value used
            ),
      ))).called(1);
    });
  });

  group('SaveTaskCommandHandler Tests - Recurrence Settings', () {
    test('should update recurrence settings correctly', () async {
      // Arrange
      const taskId = 'task-1';
      final existingTask = Task(
        id: taskId,
        createdDate: DateTime.now().toUtc(),
        title: 'Test Task',
        recurrenceType: RecurrenceType.none,
      );

      final recurrenceStartDate = DateTime(2023, 1, 1);
      final recurrenceEndDate = DateTime(2023, 12, 31);

      final command = SaveTaskCommand(
        id: taskId,
        title: 'Test Task',
        completedAt: null,
        recurrenceType: RecurrenceType.weekly,
        recurrenceInterval: 2,
        recurrenceDays: [WeekDays.monday, WeekDays.friday],
        recurrenceStartDate: recurrenceStartDate,
        recurrenceEndDate: recurrenceEndDate,
        recurrenceCount: 10,
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => existingTask);

      when(mockTaskRepository.update(any)).thenAnswer((_) async => Future.value());

      // Act
      await handler(command);

      // Assert
      verify(mockTaskRepository.update(argThat(
        predicate<Task>((task) =>
            task.id == taskId &&
            task.recurrenceType == RecurrenceType.weekly &&
            task.recurrenceInterval == 2 &&
            task.recurrenceStartDate == DateTimeHelper.toUtcDateTime(recurrenceStartDate) &&
            task.recurrenceEndDate == DateTimeHelper.toUtcDateTime(recurrenceEndDate) &&
            task.recurrenceCount == 10),
      ))).called(1);
    });

    test('should clear recurrence settings when recurrence type is none', () async {
      // Arrange
      const taskId = 'task-1';
      final existingTask = Task(
        id: taskId,
        createdDate: DateTime.now().toUtc(),
        title: 'Test Task',
        recurrenceType: RecurrenceType.weekly,
        recurrenceInterval: 2,
        recurrenceStartDate: DateTime(2023, 1, 1),
        recurrenceEndDate: DateTime(2023, 12, 31),
        recurrenceCount: 10,
      );

      final command = SaveTaskCommand(
        id: taskId,
        title: 'Test Task',
        completedAt: null,
        recurrenceType: RecurrenceType.none,
      );

      when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => existingTask);

      when(mockTaskRepository.update(any)).thenAnswer((_) async => Future.value());

      // Act
      await handler(command);

      // Assert
      verify(mockTaskRepository.update(argThat(
        predicate<Task>((task) =>
            task.id == taskId &&
            task.recurrenceType == RecurrenceType.none &&
            task.recurrenceInterval == null &&
            task.recurrenceStartDate == null &&
            task.recurrenceEndDate == null &&
            task.recurrenceCount == null),
      ))).called(1);
    });
  });
}
