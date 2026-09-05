import 'package:acore/acore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/infrastructure/shared/features/notification/habit_notification_handler.dart';
import 'package:whph/infrastructure/shared/features/notification/task_notification_handler.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import 'habit_notification_test_support.dart';
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

    group('handleNotificationHabitAction', () {
      test('should send CompleteHabitCommand with correct habit ID', () async {
        final habitId = 'habit-123';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          argThat(isA<CompleteHabitCommand>()),
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        await handler.handleNotificationHabitAction(habitId);

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

        await handler.handleNotificationHabitAction(habitId);

        final afterCall = DateTime.now();

        verify(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          argThat(isA<CompleteHabitCommand>().having(
            (cmd) => cmd.date,
            'date',
            predicate<DateTime>((date) =>
                date.isAfter(beforeCall.subtract(const Duration(seconds: 1))) &&
                date.isBefore(afterCall.add(const Duration(seconds: 1)))),
          )),
        )).called(1);
      });

      test('should call onHabitActionHandled callback after successful completion', () async {
        final habitId = 'habit-789';
        String? callbackHabitId;

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        handler.onHabitActionHandled = (id) {
          callbackHabitId = id;
        };

        await handler.handleNotificationHabitAction(habitId);

        expect(callbackHabitId, equals(habitId));
      });

      test('should not call onHabitActionHandled when callback is null', () async {
        final habitId = 'habit-012';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenAnswer((_) async => CompleteHabitCommandResponse());

        handler.onHabitActionHandled = null;

        expect(
          () async => handler.handleNotificationHabitAction(habitId),
          returnsNormally,
        );
      });

      test('should not throw when mediator throws BusinessException', () async {
        final habitId = 'habit-345';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenThrow(BusinessException('Habit not found', 'habit-not-found'));

        expect(
          () async => handler.handleNotificationHabitAction(habitId),
          returnsNormally,
        );
      });

      test('should not call onHabitActionHandled when BusinessException is thrown', () async {
        final habitId = 'habit-678';
        var callbackCalled = false;

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenThrow(BusinessException('Habit not found', 'habit-not-found'));

        handler.onHabitActionHandled = (_) {
          callbackCalled = true;
        };

        await handler.handleNotificationHabitAction(habitId);

        expect(callbackCalled, isFalse);
      });

      test('should propagate non-BusinessException errors', () async {
        final habitId = 'habit-901';

        when(mockMediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
          any,
        )).thenThrow(Exception('Unexpected error'));

        expect(
          () async => handler.handleNotificationHabitAction(habitId),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('HabitNotificationHandler type-aware outcomes', () {
    late NotificationHabitRepository habitRepository;
    late NotificationHabitRecordRepository habitRecordRepository;
    late HabitNotificationHandler handler;

    setUp(() {
      AppDatabase.resetInstance();
      AppDatabase.setInstanceForTesting(AppDatabase.forTesting());
      habitRepository = NotificationHabitRepository();
      habitRecordRepository = NotificationHabitRecordRepository();
      handler = HabitNotificationHandler(NotificationHabitMediator(
        habitRepository: habitRepository,
        habitRecordRepository: habitRecordRepository,
      ));
    });

    tearDown(() async {
      await AppDatabase.instance().close();
      AppDatabase.resetInstance();
    });

    test('habit notification records type-aware outcome', () async {
      final now = DateTime.now();
      habitRepository
        ..addHabit(Habit(
          id: 'good-habit',
          createdDate: now,
          name: 'Read',
          description: '',
        ))
        ..addHabit(Habit(
          id: 'bad-habit',
          createdDate: now,
          name: 'Smoke',
          description: '',
          type: HabitType.bad,
        ));

      await handler.handleNotificationHabitAction('good-habit');
      await handler.handleNotificationHabitAction('bad-habit');

      expect(
        habitRecordRepository.records
            .where((record) => record.habitId == 'good-habit' && record.status == HabitRecordStatus.complete),
        hasLength(1),
      );
      expect(
        habitRecordRepository.records
            .where((record) => record.habitId == 'bad-habit' && record.status == HabitRecordStatus.notDone),
        hasLength(1),
      );
    });

    test('duplicate bad habit action is idempotent', () async {
      habitRepository.addHabit(Habit(
        id: 'bad-habit',
        createdDate: DateTime.now(),
        name: 'Smoke',
        description: '',
        type: HabitType.bad,
      ));

      await handler.handleNotificationHabitAction('bad-habit');
      await handler.handleNotificationHabitAction('bad-habit');

      expect(
        habitRecordRepository.records
            .where((record) => record.habitId == 'bad-habit' && record.status == HabitRecordStatus.notDone),
        hasLength(1),
      );
    });

    test('missing habit logs notification action failure', () async {
      final messages = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = originalDebugPrint);

      await handler.handleNotificationHabitAction('missing-habit');

      expect(
        messages.any((message) =>
            message.contains('notification_action_failed') &&
            message.contains('missing-habit') &&
            message.contains('notification action')),
        isTrue,
      );
    });
  });
}
