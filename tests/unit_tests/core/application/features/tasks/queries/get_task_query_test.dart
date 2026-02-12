import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:application/features/tasks/queries/get_task_query.dart';
import 'package:application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

import 'get_task_query_test.mocks.dart';

@GenerateMocks([
  ITaskRepository,
  ITaskTimeRecordRepository,
])
void main() {
  group('GetTaskQuery Tests', () {
    late MockITaskRepository taskRepository;
    late MockITaskTimeRecordRepository timeRecordRepository;
    late GetTaskQueryHandler handler;

    setUp(() {
      taskRepository = MockITaskRepository();
      timeRecordRepository = MockITaskTimeRecordRepository();
      handler = GetTaskQueryHandler(
        taskRepository: taskRepository,
        taskTimeRecordRepository: timeRecordRepository,
      );
    });

    group('Query Creation', () {
      test('should create query with required ID', () {
        // Arrange
        const taskId = 'test-task-id';

        // Act
        final query = GetTaskQuery(id: taskId);

        // Assert
        expect(query.id, taskId);
      });
    });

    group('Handler Execution - Nominal Behavior', () {
      test('should return task with all properties correctly mapped', () async {
        // Arrange
        const taskId = 'task-123';
        final mockTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Test Task',
          description: 'Test Description',
          priority: EisenhowerPriority.urgentImportant,
          plannedDate: DateTime.utc(2024, 1, 15),
          deadlineDate: DateTime.utc(2024, 1, 20),
          estimatedTime: 3600,
          completedAt: DateTime.utc(2024, 1, 10, 14, 30),
          parentTaskId: 'parent-123',
          plannedDateReminderTime: ReminderTime.fiveMinutesBefore,
          deadlineDateReminderTime: ReminderTime.oneHourBefore,
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 2,
          recurrenceDaysString: 'monday,wednesday,friday',
          recurrenceStartDate: DateTime.utc(2024, 1, 1),
          recurrenceEndDate: DateTime.utc(2024, 12, 31),
          recurrenceCount: 10,
          recurrenceParentId: 'recurring-parent',
        );

        when(taskRepository.getById(taskId)).thenAnswer((_) async => mockTask);
        when(taskRepository.getById('parent-123')).thenAnswer((_) async => null); // Parent task doesn't exist
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenAnswer((_) async => 1800);

        // Mock empty subtasks
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetTaskQuery(id: taskId));

        // Assert
        expect(result.id, taskId);
        expect(result.createdDate, mockTask.createdDate);
        expect(result.title, mockTask.title);
        expect(result.description, mockTask.description);
        expect(result.priority, mockTask.priority);
        expect(result.plannedDate, mockTask.plannedDate);
        expect(result.deadlineDate, mockTask.deadlineDate);
        expect(result.estimatedTime, mockTask.estimatedTime);
        expect(result.totalDuration, 1800);
        expect(result.completedAt, mockTask.completedAt);
        expect(result.parentTaskId, mockTask.parentTaskId);
        expect(result.plannedDateReminderTime, mockTask.plannedDateReminderTime);
        expect(result.deadlineDateReminderTime, mockTask.deadlineDateReminderTime);
        expect(result.recurrenceType, mockTask.recurrenceType);
        expect(result.recurrenceInterval, mockTask.recurrenceInterval);
        expect(result.recurrenceDaysString, mockTask.recurrenceDaysString);
        expect(result.recurrenceStartDate, mockTask.recurrenceStartDate);
        expect(result.recurrenceEndDate, mockTask.recurrenceEndDate);
        expect(result.recurrenceCount, mockTask.recurrenceCount);
        expect(result.recurrenceParentId, mockTask.recurrenceParentId);
      });

      test('should calculate subtasks completion percentage correctly', () async {
        // Arrange
        const taskId = 'task-with-subtasks';
        final mockTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Parent Task',
          parentTaskId: null,
        );

        final subTasks = [
          Task(
            id: 'subtask-1',
            createdDate: DateTime.utc(2024, 1, 2),
            title: 'Subtask 1',
            parentTaskId: taskId,
            completedAt: DateTime.utc(2024, 1, 2, 10, 0),
          ),
          Task(
            id: 'subtask-2',
            createdDate: DateTime.utc(2024, 1, 3),
            title: 'Subtask 2',
            parentTaskId: taskId,
            completedAt: null,
          ),
          Task(
            id: 'subtask-3',
            createdDate: DateTime.utc(2024, 1, 4),
            title: 'Subtask 3',
            parentTaskId: taskId,
            completedAt: DateTime.utc(2024, 1, 4, 10, 0),
          ),
        ];

        when(taskRepository.getById(taskId)).thenAnswer((_) async => mockTask);
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenAnswer((_) async => 0);
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => subTasks);

        // Act
        final result = await handler(GetTaskQuery(id: taskId));

        // Assert
        expect(result.subTasks.length, 3);
        expect(result.subTasksCompletionPercentage, closeTo(66.67, 0.01)); // (2/3) * 100
      });

      test('should fetch parent task if parentTaskId exists', () async {
        // Arrange
        const taskId = 'child-task-123';
        const parentTaskId = 'parent-task-456';
        final childTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Child Task',
          parentTaskId: parentTaskId,
        );
        final parentTask = Task(
          id: parentTaskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Parent Task',
        );

        when(taskRepository.getById(taskId)).thenAnswer((_) async => childTask);
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenAnswer((_) async => 0);
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);
        when(taskRepository.getById(parentTaskId)).thenAnswer((_) async => parentTask);

        // Act
        final result = await handler(GetTaskQuery(id: taskId));

        // Assert
        expect(result.parentTask, isNotNull);
        expect(result.parentTask!.id, parentTaskId);
        expect(result.parentTask!.title, parentTask.title);
      });
    });

    group('Handler Execution - Edge Cases', () {
      test('should return empty subtasks list when no subtasks exist', () async {
        // Arrange
        const taskId = 'task-no-subtasks';
        final mockTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task with no subtasks',
        );

        when(taskRepository.getById(taskId)).thenAnswer((_) async => mockTask);
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenAnswer((_) async => 0);
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetTaskQuery(id: taskId));

        // Assert
        expect(result.subTasks, isEmpty);
        expect(result.subTasksCompletionPercentage, 0);
      });

      test('should handle null parentTaskId gracefully', () async {
        // Arrange
        const taskId = 'task-no-parent';
        final mockTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task with no parent',
          parentTaskId: null,
        );

        when(taskRepository.getById(taskId)).thenAnswer((_) async => mockTask);
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenAnswer((_) async => 0);
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetTaskQuery(id: taskId));

        // Assert
        expect(result.parentTask, isNull);
        expect(result.parentTaskId, isNull);
      });

      test('should return 0 completion percentage when no subtasks exist', () async {
        // Arrange
        const taskId = 'task-no-subtasks-comp';
        final mockTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task',
        );

        when(taskRepository.getById(taskId)).thenAnswer((_) async => mockTask);
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenAnswer((_) async => 0);
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetTaskQuery(id: taskId));

        // Assert
        expect(result.subTasksCompletionPercentage, 0);
      });
    });

    group('Handler Execution - Error Handling', () {
      test('should throw BusinessException when task is not found', () async {
        // Arrange
        const nonExistentTaskId = 'non-existent-task';

        when(taskRepository.getById(nonExistentTaskId)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => handler(GetTaskQuery(id: nonExistentTaskId)),
          throwsA(isA<BusinessException>()),
        );
      });

      test('should handle repository errors gracefully', () async {
        // Arrange
        const taskId = 'error-test-task';

        when(taskRepository.getById(taskId)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => handler(GetTaskQuery(id: taskId)),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle time record repository errors gracefully', () async {
        // Arrange
        const taskId = 'error-test-task';
        final mockTask = Task(
          id: taskId,
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Test Task',
        );

        when(taskRepository.getById(taskId)).thenAnswer((_) async => mockTask);
        when(timeRecordRepository.getTotalDurationByTaskId(taskId)).thenThrow(Exception('Time record error'));
        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act & Assert
        expect(
          () => handler(GetTaskQuery(id: taskId)),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('GetTaskQueryResponse Tests', () {
    test('should create response with all required properties', () {
      // Arrange
      const taskId = 'response-test-task';
      final createdDate = DateTime.utc(2024, 1, 1);
      final mockSubTasks = <Task>[];

      // Act
      final response = GetTaskQueryResponse(
        id: taskId,
        createdDate: createdDate,
        title: 'Response Test Task',
        parentTaskId: null,
        totalDuration: 1800,
        subTasksCompletionPercentage: 50.0,
        subTasks: mockSubTasks,
      );

      // Assert
      expect(response.id, taskId);
      expect(response.createdDate, createdDate);
      expect(response.title, 'Response Test Task');
      expect(response.totalDuration, 1800);
      expect(response.subTasksCompletionPercentage, 50.0);
      expect(response.subTasks, mockSubTasks);
    });
  });
}
