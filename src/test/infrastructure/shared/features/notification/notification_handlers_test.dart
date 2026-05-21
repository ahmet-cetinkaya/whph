import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/infrastructure/shared/features/notification/habit_notification_handler.dart';
import 'package:whph/infrastructure/shared/features/notification/task_notification_handler.dart';

import 'notification_handlers_test.mocks.dart';

@GenerateMocks([Mediator])
void main() {
  group('TaskNotificationHandler', () {
    late MockMediator mockMediator;
    late TaskNotificationHandler handler;

    setUp(() {
      mockMediator = MockMediator();
      handler = TaskNotificationHandler(mockMediator);
    });

    group('handleNotificationTaskCompletion', () {
      test('should send CompleteTaskCommand with correct task ID', () async {
        final taskId = 'task-123';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).thenAnswer((_) async => CompleteTaskCommandResponse(taskId: taskId));

        await handler.handleNotificationTaskCompletion(taskId);

        verify(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>().having(
            (cmd) => cmd.id,
            'id',
            taskId,
          )),
        )).called(1);
      });

      test('should not throw when mediator throws BusinessException', () async {
        final taskId = 'task-456';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          any,
        )).thenThrow(BusinessException('Task not found', 'task-not-found'));

        expect(
          () async => handler.handleNotificationTaskCompletion(taskId),
          returnsNormally,
        );
      });

      test('should propagate non-BusinessException errors', () async {
        final taskId = 'task-789';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          any,
        )).thenThrow(Exception('Unexpected error'));

        expect(
          () async => handler.handleNotificationTaskCompletion(taskId),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('HabitNotificationHandler', () {
    late MockMediator mockMediator;
    late HabitNotificationHandler handler;

    setUp(() {
      mockMediator = MockMediator();
      handler = HabitNotificationHandler(mockMediator);
    });

    group('handleNotificationHabitCompletion', () {
      test('should send CompleteHabitCommand with correct habit ID', () async {
        final habitId = 'habit-123';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          argThat(isA<CompleteHabitCommand>()),
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        await handler.handleNotificationHabitCompletion(habitId);

        verify(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          argThat(isA<CompleteHabitCommand>().having(
            (cmd) => cmd.habitId,
            'habitId',
            habitId,
          )),
        )).called(1);
      });

      test('should send CompleteHabitCommand with current date', () async {
        final habitId = 'habit-456';
        final beforeCall = DateTime.now();

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        await handler.handleNotificationHabitCompletion(habitId);

        final afterCall = DateTime.now();

        verify(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          argThat(isA<CompleteHabitCommand>().having(
            (cmd) => cmd.date,
            'date',
            predicate<DateTime>((date) => date.isAfter(beforeCall.subtract(const Duration(seconds: 1))) &&
                date.isBefore(afterCall.add(const Duration(seconds: 1)))),
          )),
        )).called(1);
      });

      test('should call onHabitCompleted callback after successful completion', () async {
        final habitId = 'habit-789';
        String? callbackHabitId;

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        handler.onHabitCompleted = (id) {
          callbackHabitId = id;
        };

        await handler.handleNotificationHabitCompletion(habitId);

        expect(callbackHabitId, equals(habitId));
      });

      test('should not call onHabitCompleted when callback is null', () async {
        final habitId = 'habit-012';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        handler.onHabitCompleted = null;

        expect(
          () async => handler.handleNotificationHabitCompletion(habitId),
          returnsNormally,
        );
      });

      test('should not throw when mediator throws BusinessException', () async {
        final habitId = 'habit-345';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenThrow(BusinessException('Habit not found', 'habit-not-found'));

        expect(
          () async => handler.handleNotificationHabitCompletion(habitId),
          returnsNormally,
        );
      });

      test('should not call onHabitCompleted when BusinessException is thrown', () async {
        final habitId = 'habit-678';
        var callbackCalled = false;

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenThrow(BusinessException('Habit not found', 'habit-not-found'));

        handler.onHabitCompleted = (_) {
          callbackCalled = true;
        };

        await handler.handleNotificationHabitCompletion(habitId);

        expect(callbackCalled, isFalse);
      });

      test('should propagate non-BusinessException errors', () async {
        final habitId = 'habit-901';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenThrow(Exception('Unexpected error'));

        expect(
          () async => handler.handleNotificationHabitCompletion(habitId),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
