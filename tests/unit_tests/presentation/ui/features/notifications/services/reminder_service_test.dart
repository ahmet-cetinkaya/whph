import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:infrastructure_shared/features/notification/abstractions/i_notification_payload_handler.dart';

import 'reminder_service_test.mocks.dart';

@GenerateMocks([
  IReminderService,
  Mediator,
  TasksService,
  HabitsService,
  ITranslationService,
  INotificationPayloadHandler,
  IReminderCalculationService,
])
void main() {
  late ReminderService reminderService;
  late MockIReminderService mockReminderService;
  late MockMediator mockMediator;
  late MockTasksService mockTasksService;
  late MockHabitsService mockHabitsService;
  late MockITranslationService mockTranslationService;
  late MockINotificationPayloadHandler mockNotificationPayloadHandler;
  late MockIReminderCalculationService mockReminderCalculationService;

  setUp(() {
    mockReminderService = MockIReminderService();
    mockMediator = MockMediator();
    mockTasksService = MockTasksService();
    mockHabitsService = MockHabitsService();
    mockTranslationService = MockITranslationService();
    mockNotificationPayloadHandler = MockINotificationPayloadHandler();
    mockReminderCalculationService = MockIReminderCalculationService();

    // Setup default stubs
    when(mockTranslationService.translate(any, namedArgs: anyNamed('namedArgs')))
        .thenAnswer((invocation) => invocation.positionalArguments.first as String);

    when(mockNotificationPayloadHandler.createNavigationPayload(
      route: anyNamed('route'),
      arguments: anyNamed('arguments'),
    )).thenReturn('payload');

    when(mockReminderService.init()).thenAnswer((_) async {});
    when(mockReminderService.cancelReminders(
      idFilter: anyNamed('idFilter'),
      startsWith: anyNamed('startsWith'),
      contains: anyNamed('contains'),
      equals: anyNamed('equals'),
    )).thenAnswer((_) async {});

    // Mock ValueNotifiers for services
    when(mockTasksService.onTaskCreated).thenReturn(ValueNotifier(null));
    when(mockTasksService.onTaskUpdated).thenReturn(ValueNotifier(null));
    when(mockTasksService.onTaskDeleted).thenReturn(ValueNotifier(null));
    when(mockTasksService.onTaskCompleted).thenReturn(ValueNotifier(null));

    when(mockHabitsService.onHabitCreated).thenReturn(ValueNotifier(null));
    when(mockHabitsService.onHabitUpdated).thenReturn(ValueNotifier(null));
    when(mockHabitsService.onHabitDeleted).thenReturn(ValueNotifier(null));

    reminderService = ReminderService(
      mockReminderService,
      mockMediator,
      mockTasksService,
      mockHabitsService,
      mockTranslationService,
      mockNotificationPayloadHandler,
      mockReminderCalculationService,
    );
  });

  test('scheduleTaskReminder schedules notification for custom reminder', () async {
    // Arrange
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: futureDate,
      plannedDateReminderTime: ReminderTime.custom,
      plannedDateReminderCustomOffset: 30, // 30 minutes before
    );

    // Mock the reminder calculation service
    when(mockReminderCalculationService.calculateReminderDateTime(
      baseDate: anyNamed('baseDate'),
      reminderTime: anyNamed('reminderTime'),
      customOffset: anyNamed('customOffset'),
    )).thenReturn(futureDate.subtract(const Duration(minutes: 30)));

    // Act
    await reminderService.scheduleTaskReminder(task);

    // Assert
    final expectedReminderTime = futureDate.subtract(const Duration(minutes: 30));

    // Verify that scheduleReminder was called on the underlying service
    verify(mockReminderService.scheduleReminder(
      id: 'task_planned_${task.id}',
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: argThat(
        predicate<DateTime>((date) {
          // Allow for small difference due to milliseconds/microsecond precision
          return date.difference(expectedReminderTime).abs().inSeconds < 2;
        }),
        named: 'scheduledDate',
      ),
      payload: anyNamed('payload'),
    )).called(1);
  });

  test('scheduleTaskReminder cancels existing reminder when scheduling a new future one', () async {
    // Arrange
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: futureDate,
      plannedDateReminderTime: ReminderTime.atTime,
    );

    // Mock calculation to return a future date
    when(mockReminderCalculationService.calculateReminderDateTime(
      baseDate: anyNamed('baseDate'),
      reminderTime: anyNamed('reminderTime'),
      customOffset: anyNamed('customOffset'),
    )).thenReturn(futureDate);

    // Act
    await reminderService.scheduleTaskReminder(task);

    // Assert
    // Should cancel the specific reminder ID before scheduling
    verify(mockReminderService.cancelReminders(equals: 'task_planned_${task.id}')).called(1);

    // Should schedule the new one
    verify(mockReminderService.scheduleReminder(
      id: 'task_planned_${task.id}',
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: anyNamed('scheduledDate'),
      payload: anyNamed('payload'),
    )).called(1);
  });

  test('scheduleTaskReminder does NOT cancel existing reminder when reminder time is in the past', () async {
    // Arrange
    final pastDate = DateTime.now().subtract(const Duration(hours: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now().subtract(const Duration(days: 1)),
      plannedDate: pastDate,
      plannedDateReminderTime: ReminderTime.atTime,
    );

    // Mock calculation to return a past date
    when(mockReminderCalculationService.calculateReminderDateTime(
      baseDate: anyNamed('baseDate'),
      reminderTime: anyNamed('reminderTime'),
      customOffset: anyNamed('customOffset'),
    )).thenReturn(pastDate);

    // Act
    await reminderService.scheduleTaskReminder(task);

    // Assert
    // Should NOT cancel the reminder (preserving the notification in tray)
    verifyNever(mockReminderService.cancelReminders(equals: 'task_planned_${task.id}'));

    // Should NOT schedule a new reminder
    verifyNever(mockReminderService.scheduleReminder(
      id: anyNamed('id'),
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: anyNamed('scheduledDate'),
      payload: anyNamed('payload'),
    ));
  });

  test('scheduleTaskReminder cancels existing reminder when reminder is disabled', () async {
    // Arrange - Task with NO reminder
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: futureDate,
      plannedDateReminderTime: ReminderTime.none, // DISABLED
    );

    // Act
    await reminderService.scheduleTaskReminder(task);

    // Assert
    // Should explicitly cancel the reminder
    verify(mockReminderService.cancelReminders(equals: 'task_planned_${task.id}')).called(1);

    // Should NOT schedule anything
    verifyNever(mockReminderService.scheduleReminder(
      id: anyNamed('id'),
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: anyNamed('scheduledDate'),
      payload: anyNamed('payload'),
    ));
  });
}
