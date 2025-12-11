import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

void main() {
  group('TaskRecurrenceService Error Handling Tests', () {
    late TaskRecurrenceService service;
    late MockMediator mockMediator;

    setUp(() {
      mockMediator = MockMediator();
      service = TaskRecurrenceService(TestLogger());
    });

    group('handleCompletedRecurringTask Error Scenarios', () {
      test('should return null when GetTaskQuery throws an exception', () async {
        // Arrange
        const taskId = 'task-1';
        const errorMessage = 'Task not found';
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => throw Exception(errorMessage),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
        // Verify error was logged (we can't directly test the logger, but the method should complete without crashing)
      });

      test('should return null when task does not exist', () async {
        // Arrange
        const taskId = 'non-existent-task';
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => throw Exception('Task not found'),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });

      test('should return null when task is not completed', () async {
        // Arrange
        const taskId = 'task-1';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Incomplete Recurring Task',
          completedAt: null, // Not completed
          recurrenceType: RecurrenceType.daily,
          parentTaskId: null,
        );
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });

      test('should return null when task is not recurring', () async {
        // Arrange
        const taskId = 'task-1';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Non-recurring Completed Task',
          completedAt: DateTime.now().toUtc(),
          recurrenceType: RecurrenceType.none, // Not recurring
          parentTaskId: null,
        );
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });

      test('should return null when max recurrence count is reached', () async {
        // Arrange
        const taskId = 'task-1';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Recurrence Limit Reached Task',
          completedAt: DateTime.now().toUtc(),
          recurrenceType: RecurrenceType.daily,
          recurrenceCount: 0, // Count is 0, so no more instances should be created
          parentTaskId: null,
        );
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            recurrenceCount: task.recurrenceCount,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });
    });

    group('Mediator Exception Scenarios', () {
      test('should handle exception when getting task tags', () async {
        // Arrange
        const taskId = 'task-1';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Recurring Task with Tags',
          completedAt: DateTime.now().toUtc(),
          recurrenceType: RecurrenceType.daily,
          parentTaskId: null,
        );

        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        mockMediator.addResponse<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          (query) => throw Exception('Database connection failed'),
        );

        // Act & Assert
        expect(
          () => service.handleCompletedRecurringTask(taskId, mockMediator),
          returnsNormally,
        );
      });

      test('should handle exception when saving new task', () async {
        // Arrange
        const taskId = 'task-1';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Recurring Task',
          completedAt: DateTime.now().toUtc(),
          recurrenceType: RecurrenceType.daily,
          parentTaskId: null,
        );

        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        mockMediator.addResponse<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          (query) => GetListTaskTagsQueryResponse(
            items: [],
            totalItemCount: 0,
            pageIndex: 0,
            pageSize: 10,
          ),
        );

        // Mock the SaveTaskCommand handler to throw an exception
        mockMediator.addHandler<SaveTaskCommand, SaveTaskCommandResponse>(
          (command) => throw Exception('Save task failed'),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });

      test('should handle exception during entire recurrence creation process', () async {
        // Arrange
        const taskId = 'task-1';
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => throw Exception('Critical error in task retrieval'),
        );

        // Act & Assert
        expect(
          () => service.handleCompletedRecurringTask(taskId, mockMediator),
          returnsNormally,
        );
      });
    });

    group('Task Creation Failure Scenarios', () {
      test('should return null when task creation fails due to validation errors', () async {
        // Arrange
        const taskId = 'task-1';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Recurring Task',
          completedAt: DateTime.now().toUtc(),
          recurrenceType: RecurrenceType.daily,
          parentTaskId: null,
        );

        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        mockMediator.addResponse<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          (query) => GetListTaskTagsQueryResponse(
            items: [],
            totalItemCount: 0,
            pageIndex: 0,
            pageSize: 10,
          ),
        );

        // Mock the SaveTaskCommand handler to throw validation error
        mockMediator.addHandler<SaveTaskCommand, SaveTaskCommandResponse>(
          (command) => throw Exception('Task validation failed'),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });

      test('should handle scenario where recurrence end date is reached', () async {
        // Arrange
        const taskId = 'task-1';
        final now = DateTime.now().toUtc();
        final task = Task(
          id: taskId,
          createdDate: now,
          title: 'Task with End Date',
          completedAt: now,
          recurrenceType: RecurrenceType.daily,
          recurrenceEndDate: now.subtract(const Duration(days: 1)), // End date already passed
          parentTaskId: null,
        );

        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            recurrenceEndDate: task.recurrenceEndDate,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        // Act
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);

        // Assert
        expect(result, isNull);
      });

      test('should handle scenario where recurrence count reaches zero', () async {
        // Arrange
        const taskId = 'task-1';
        final now = DateTime.now().toUtc();
        final task = Task(
          id: taskId,
          createdDate: now,
          title: 'Task with Count Limit',
          completedAt: now,
          recurrenceType: RecurrenceType.daily,
          recurrenceCount: 1, // Only one occurrence allowed, and this is the last one
          parentTaskId: null,
        );

        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: task.id,
            createdDate: task.createdDate,
            title: task.title,
            completedAt: task.completedAt,
            recurrenceType: task.recurrenceType,
            recurrenceCount: task.recurrenceCount,
            parentTaskId: task.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        mockMediator.addResponse<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          (query) => GetListTaskTagsQueryResponse(
            items: [],
            totalItemCount: 0,
            pageIndex: 0,
            pageSize: 10,
          ),
        );

        // When the task is created, the recurrence count will be decremented to 0
        // So the next time it won't create another instance
        mockMediator.addHandler<SaveTaskCommand, SaveTaskCommandResponse>(
          (command) => SaveTaskCommandResponse(
            id: 'new-task-id',
            createdDate: DateTime.now().toUtc(),
          ),
        );

        // Create the first recurrence instance
        final result = await service.handleCompletedRecurringTask(taskId, mockMediator);
        expect(result, isNotNull); // Should create the next instance

        // Now try to create another instance with the new task that has recurrenceCount = 0
        final newTask = task.copyWith(recurrenceCount: 0);
        mockMediator.addResponse<GetTaskQuery, GetTaskQueryResponse>(
          (query) => GetTaskQueryResponse(
            id: newTask.id,
            createdDate: newTask.createdDate,
            title: newTask.title,
            completedAt: newTask.completedAt,
            recurrenceType: newTask.recurrenceType,
            recurrenceCount: newTask.recurrenceCount,
            parentTaskId: newTask.parentTaskId,
            totalDuration: 0,
            subTasksCompletionPercentage: 0,
            subTasks: [],
          ),
        );

        final result2 = await service.handleCompletedRecurringTask('new-task-id', mockMediator);
        expect(result2, isNull); // Should not create another instance
      });
    });
  });
}

// Mock classes for testing
class MockMediator implements Mediator {
  final Map<Type, Function> _handlers = {};

  void addHandler<TRequest, TResponse>(TResponse Function(TRequest request) handler) {
    _handlers[TRequest] = handler;
  }

  void addResponse<TRequest, TResponse>(TResponse Function(TRequest request) responseBuilder) {
    _handlers[TRequest] = responseBuilder;
  }

  @override
  final handlers = <Type, HandlerCreator>{};
  @override
  final eventHandlers = <Type, List<IEventHandler>>{};
  @override
  final eventFuncHandler = <Type, List<FuncEventHandler>>{};

  // Use noSuchMethod to handle all other methods that aren't directly implemented
  @override
  noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final handler = _handlers[T];
    if (handler != null) {
      try {
        return handler(request);
      } catch (e) {
        rethrow;
      }
    }
    throw Exception('No handler registered for request type: ${T.toString()}');
  }

  @override
  Future<void> publish<E extends IDomainEvent>(E event) async {
    // For this test, we don't need to implement this
  }

  Future<void> verifyTimes() async {
    // For this test, we don't need to implement this
  }
}

// Test logger that discards all log messages
class TestLogger implements ILogger {
  const TestLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}
