import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/infrastructure/mobile/features/notification/mobile_notification_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';

import 'mobile_notification_service_test.mocks.dart';

@GenerateMocks([
  Mediator,
  ITaskRecurrenceService,
  TasksService,
])
void main() {
  group('MobileNotificationService', () {
    late MobileNotificationService service;
    late MockMediator mockMediator;
    late MockITaskRecurrenceService mockRecurrenceService;
    late MockTasksService mockTasksService;

    setUp(() {
      mockMediator = MockMediator();
      mockRecurrenceService = MockITaskRecurrenceService();
      mockTasksService = MockTasksService();

      // Set up default recurrence service behavior
      when(mockRecurrenceService.getRecurrenceDays(any)).thenReturn(null);
    });

    group('handleNotificationTaskCompletion', () {
      test('should complete task when valid task ID is provided', () async {
        // Arrange
        final taskId = 'test-task-id';
        final now = DateTime.now().toUtc();

        final queryResponse = GetTaskQueryResponse(
          id: taskId,
          createdDate: now,
          title: 'Test Task',
          description: 'Test Description',
          priority: EisenhowerPriority.urgentImportant,
          estimatedTime: 30,
          totalDuration: 0,
          completedAt: null,
          parentTaskId: null,
          subTasksCompletionPercentage: 0.0,
          subTasks: [],
        );

        final commandResponse = SaveTaskCommandResponse(
          id: taskId,
          createdDate: now,
        );

        when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).thenAnswer((_) async => queryResponse);

        when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(isA<SaveTaskCommand>()),
        )).thenAnswer((_) async => commandResponse);

        service = MobileNotificationService(mockMediator, mockRecurrenceService, mockTasksService);

        // Act
        await service.handleNotificationTaskCompletion(taskId);

        // Assert
        verify(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).called(1);

        verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(
            predicate<SaveTaskCommand>(
                (cmd) => cmd.id == taskId && cmd.title == 'Test Task' && cmd.completedAt != null),
          ),
        )).called(1);
      });

      test('should preserve all task properties when completing', () async {
        // Arrange
        final taskId = 'test-task-with-recurrence';
        final now = DateTime.now().toUtc();

        final queryResponse = GetTaskQueryResponse(
          id: taskId,
          createdDate: now,
          title: 'Recurring Task',
          description: 'Task with recurrence',
          priority: EisenhowerPriority.notUrgentImportant,
          plannedDate: now.add(const Duration(days: 1)),
          deadlineDate: now.add(const Duration(days: 7)),
          estimatedTime: 60,
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 1,
          recurrenceStartDate: now,
          totalDuration: 0,
          parentTaskId: null,
          subTasksCompletionPercentage: 0.0,
          subTasks: [],
        );

        final commandResponse = SaveTaskCommandResponse(
          id: taskId,
          createdDate: now,
        );

        when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).thenAnswer((_) async => queryResponse);

        when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(isA<SaveTaskCommand>()),
        )).thenAnswer((_) async => commandResponse);

        when(mockRecurrenceService.getRecurrenceDays(any)).thenReturn([WeekDays.monday, WeekDays.wednesday]);

        service = MobileNotificationService(mockMediator, mockRecurrenceService, mockTasksService);

        // Act
        await service.handleNotificationTaskCompletion(taskId);

        // Assert
        final captured = verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          captureAny,
        )).captured.last as SaveTaskCommand;

        expect(captured.id, equals(taskId));
        expect(captured.title, equals('Recurring Task'));
        expect(captured.description, equals('Task with recurrence'));
        expect(captured.priority, equals(EisenhowerPriority.notUrgentImportant));
        expect(captured.plannedDate, isNotNull);
        expect(captured.deadlineDate, isNotNull);
        expect(captured.estimatedTime, equals(60));
        expect(captured.completedAt, isNotNull);
        expect(captured.recurrenceType, equals(RecurrenceType.weekly));
        expect(captured.recurrenceInterval, equals(1));
        expect(captured.recurrenceDays, equals([WeekDays.monday, WeekDays.wednesday]));
        expect(captured.recurrenceStartDate, equals(now));
      });

      test('should handle task with reminder times', () async {
        // Arrange
        final taskId = 'task-with-reminders';
        final now = DateTime.now().toUtc();

        final queryResponse = GetTaskQueryResponse(
          id: taskId,
          createdDate: now,
          title: 'Task with Reminders',
          plannedDateReminderTime: ReminderTime.fifteenMinutesBefore,
          deadlineDateReminderTime: ReminderTime.oneHourBefore,
          totalDuration: 0,
          parentTaskId: null,
          subTasksCompletionPercentage: 0.0,
          subTasks: [],
        );

        final commandResponse = SaveTaskCommandResponse(
          id: taskId,
          createdDate: now,
        );

        when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).thenAnswer((_) async => queryResponse);

        when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(isA<SaveTaskCommand>()),
        )).thenAnswer((_) async => commandResponse);

        service = MobileNotificationService(mockMediator, mockRecurrenceService, mockTasksService);

        // Act
        await service.handleNotificationTaskCompletion(taskId);

        // Assert
        final captured = verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          captureAny,
        )).captured.last as SaveTaskCommand;

        expect(captured.plannedDateReminderTime, equals(ReminderTime.fifteenMinutesBefore));
        expect(captured.deadlineDateReminderTime, equals(ReminderTime.oneHourBefore));
      });

      test('should handle mediator errors gracefully', () async {
        // Arrange
        final taskId = 'error-task';
        final now = DateTime.now().toUtc();

        final queryResponse = GetTaskQueryResponse(
          id: taskId,
          createdDate: now,
          title: 'Error Task',
          totalDuration: 0,
          parentTaskId: null,
          subTasksCompletionPercentage: 0.0,
          subTasks: [],
        );

        when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).thenAnswer((_) async => queryResponse);

        when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(isA<SaveTaskCommand>()),
        )).thenThrow(Exception('Database error'));

        service = MobileNotificationService(mockMediator, mockRecurrenceService, mockTasksService);

        // Act & Assert - should not throw
        await expectLater(
          () => service.handleNotificationTaskCompletion(taskId),
          returnsNormally,
        );
      });

      test('should handle task not found error', () async {
        // Arrange
        final taskId = 'non-existent-task';

        when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).thenThrow(Exception('Task not found'));

        service = MobileNotificationService(mockMediator, mockRecurrenceService, mockTasksService);

        // Act & Assert - should not throw
        await expectLater(
          () => service.handleNotificationTaskCompletion(taskId),
          returnsNormally,
        );
      });

      test('should set completedAt to current UTC time', () async {
        // Arrange
        final taskId = 'timing-test';
        final now = DateTime.now().toUtc();
        final beforeCompletion = now.subtract(const Duration(seconds: 1));

        final queryResponse = GetTaskQueryResponse(
          id: taskId,
          createdDate: now,
          title: 'Timing Test',
          totalDuration: 0,
          parentTaskId: null,
          subTasksCompletionPercentage: 0.0,
          subTasks: [],
        );

        final commandResponse = SaveTaskCommandResponse(
          id: taskId,
          createdDate: now,
        );

        when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(
          argThat(isA<GetTaskQuery>()),
        )).thenAnswer((_) async => queryResponse);

        when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          argThat(isA<SaveTaskCommand>()),
        )).thenAnswer((_) async => commandResponse);

        service = MobileNotificationService(mockMediator, mockRecurrenceService, mockTasksService);

        // Act
        await service.handleNotificationTaskCompletion(taskId);

        // Assert
        final captured = verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          captureAny,
        )).captured.last as SaveTaskCommand;

        expect(captured.completedAt, isNotNull);
        expect(captured.completedAt!.isAfter(beforeCompletion), isTrue);
        expect(captured.completedAt!.isBefore(now.add(const Duration(minutes: 1))), isTrue);
      });
    });
  });
}
