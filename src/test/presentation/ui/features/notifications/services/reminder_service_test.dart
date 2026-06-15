import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';

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

// Minimal Mediator implementation that routes send() calls to a callback.
// Needed because mockito's typed stubs can't return different response types
// from the same method when generic type parameters differ.
class CallbackMediator extends Mediator {
  Future<dynamic> Function(dynamic request)? _handler;

  CallbackMediator() : super(Pipeline());

  void setHandler(Future<dynamic> Function(dynamic request) handler) {
    _handler = handler;
  }

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    if (_handler != null) {
      final result = await _handler!(request);
      return result as R;
    }
    throw UnimplementedError('No handler set for send()');
  }
}

// Test mock for HabitsService that uses real ValueNotifiers for record events.
// Mockito's FakeValueNotifier does not fire listeners, so we need real instances.
class TestHabitsService extends MockHabitsService {
  final ValueNotifier<String?> _onHabitRecordAdded = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _onHabitRecordRemoved = ValueNotifier<String?>(null);

  @override
  ValueNotifier<String?> get onHabitRecordAdded => _onHabitRecordAdded;
  @override
  ValueNotifier<String?> get onHabitRecordRemoved => _onHabitRecordRemoved;

  void setRecordAdded(String? habitId) {
    _onHabitRecordAdded.value = habitId;
  }

  void setRecordRemoved(String? habitId) {
    _onHabitRecordRemoved.value = habitId;
  }
}

void main() {
  late ReminderService reminderService;
  late MockIReminderService mockReminderService;
  late CallbackMediator mockMediator;
  late MockTasksService mockTasksService;
  late TestHabitsService mockHabitsService;
  late MockITranslationService mockTranslationService;
  late MockINotificationPayloadHandler mockNotificationPayloadHandler;
  late MockIReminderCalculationService mockReminderCalculationService;

  HabitStatistics defaultStatistics() => HabitStatistics(
        overallScore: 0,
        monthlyScore: 0,
        yearlyScore: 0,
        totalRecords: 0,
        monthlyScores: [],
        topStreaks: [],
        yearlyFrequency: {},
      );

  GetHabitQueryResponse habitWithReminder({
    String id = 'habit-1',
    String name = 'Test Habit',
    String reminderTime = '20:00',
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    int? dailyTarget,
    bool archived = false,
    bool deleted = false,
  }) =>
      GetHabitQueryResponse(
        id: id,
        createdDate: DateTime.now(),
        name: name,
        description: '',
        hasReminder: true,
        reminderTime: reminderTime,
        reminderDays: reminderDays,
        dailyTarget: dailyTarget,
        archivedDate: archived ? DateTime.now() : null,
        deletedDate: deleted ? DateTime.now() : null,
        statistics: defaultStatistics(),
      );

  GetHabitQueryResponse habitWithoutReminder({String id = 'habit-1'}) => GetHabitQueryResponse(
        id: id,
        createdDate: DateTime.now(),
        name: 'No Reminder Habit',
        description: '',
        statistics: defaultStatistics(),
      );

  HabitListItem habitListItem({
    required String id,
    required String name,
    bool hasReminder = true,
    String reminderTime = '20:00',
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    int? dailyTarget,
    bool archived = false,
  }) =>
      HabitListItem(
        id: id,
        name: name,
        hasReminder: hasReminder,
        reminderTime: reminderTime,
        reminderDays: reminderDays,
        dailyTarget: dailyTarget,
        archivedDate: archived ? DateTime.now() : null,
      );

  /// Sets up the mediator callback to route requests by type for habit-related queries.
  void stubMediatorForHabit(
    GetHabitQueryResponse habit, {
    List<HabitRecordListItem> todayRecords = const [],
  }) {
    mockMediator.setHandler((request) async {
      if (request is GetHabitQuery) return habit;
      if (request is GetListHabitRecordsQuery) {
        return GetListHabitRecordsQueryResponse(
          items: todayRecords,
          totalItemCount: todayRecords.length,
          pageIndex: 0,
          pageSize: 1000,
        );
      }
      if (request is GetListHabitsQuery) {
        return GetListHabitsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1000);
      }
      if (request is GetListTasksQuery) {
        return GetListTasksQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1000);
      }
      return null;
    });
  }

  /// Sets up the mediator callback for _scheduleExistingHabitReminders init tests.
  void stubMediatorForInit({
    required List<HabitListItem> habits,
    required GetHabitQueryResponse habitResponse,
    required List<HabitRecordListItem> todayRecords,
  }) {
    mockMediator.setHandler((request) async {
      if (request is GetListHabitsQuery) {
        return GetListHabitsQueryResponse(
          items: habits,
          totalItemCount: habits.length,
          pageIndex: 0,
          pageSize: 1000,
        );
      }
      if (request is GetListTasksQuery) {
        return GetListTasksQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1000);
      }
      if (request is GetHabitQuery) return habitResponse;
      if (request is GetListHabitRecordsQuery) {
        return GetListHabitRecordsQueryResponse(
          items: todayRecords,
          totalItemCount: todayRecords.length,
          pageIndex: 0,
          pageSize: 1000,
        );
      }
      return null;
    });
  }

  void triggerRecordAdded(String? habitId) {
    mockHabitsService.setRecordAdded(habitId);
  }

  void triggerRecordRemoved(String? habitId) {
    mockHabitsService.setRecordRemoved(habitId);
  }

  setUp(() {
    mockReminderService = MockIReminderService();
    mockMediator = CallbackMediator();
    mockTasksService = MockTasksService();
    mockHabitsService = TestHabitsService();
    mockTranslationService = MockITranslationService();
    mockNotificationPayloadHandler = MockINotificationPayloadHandler();
    mockReminderCalculationService = MockIReminderCalculationService();

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

    when(mockTasksService.onTaskCreated).thenReturn(ValueNotifier(null));
    when(mockTasksService.onTaskUpdated).thenReturn(ValueNotifier(null));
    when(mockTasksService.onTaskDeleted).thenReturn(ValueNotifier(null));
    when(mockTasksService.onTaskCompleted).thenReturn(ValueNotifier(null));

    when(mockHabitsService.onHabitCreated).thenReturn(ValueNotifier(null));
    when(mockHabitsService.onHabitUpdated).thenReturn(ValueNotifier(null));
    when(mockHabitsService.onHabitDeleted).thenReturn(ValueNotifier(null));

    // Default: return empty lists for habit/task queries
    mockMediator.setHandler((request) async {
      if (request is GetListHabitsQuery) {
        return GetListHabitsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1000);
      }
      if (request is GetListTasksQuery) {
        return GetListTasksQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1000);
      }
      return null;
    });

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

  // ── Existing task reminder tests ──

  test('scheduleTaskReminder schedules notification for custom reminder', () async {
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: futureDate,
      plannedDateReminderTime: ReminderTime.custom,
      plannedDateReminderCustomOffset: 30,
    );

    when(mockReminderCalculationService.calculateReminderDateTime(
      baseDate: anyNamed('baseDate'),
      reminderTime: anyNamed('reminderTime'),
      customOffset: anyNamed('customOffset'),
    )).thenReturn(futureDate.subtract(const Duration(minutes: 30)));

    await reminderService.scheduleTaskReminder(task);

    final expectedReminderTime = futureDate.subtract(const Duration(minutes: 30));
    verify(mockReminderService.scheduleReminder(
      id: 'task_planned_${task.id}',
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: argThat(
        predicate<DateTime>((date) => date.difference(expectedReminderTime).abs().inSeconds < 2),
        named: 'scheduledDate',
      ),
      payload: anyNamed('payload'),
    )).called(1);
  });

  test('scheduleTaskReminder cancels existing reminder when scheduling a new future one', () async {
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: futureDate,
      plannedDateReminderTime: ReminderTime.atTime,
    );

    when(mockReminderCalculationService.calculateReminderDateTime(
      baseDate: anyNamed('baseDate'),
      reminderTime: anyNamed('reminderTime'),
      customOffset: anyNamed('customOffset'),
    )).thenReturn(futureDate);

    await reminderService.scheduleTaskReminder(task);

    verify(mockReminderService.cancelReminders(equals: 'task_planned_${task.id}')).called(1);
    verify(mockReminderService.scheduleReminder(
      id: 'task_planned_${task.id}',
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: anyNamed('scheduledDate'),
      payload: anyNamed('payload'),
    )).called(1);
  });

  test('scheduleTaskReminder does NOT cancel existing reminder when reminder time is in the past', () async {
    final pastDate = DateTime.now().subtract(const Duration(hours: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now().subtract(const Duration(days: 1)),
      plannedDate: pastDate,
      plannedDateReminderTime: ReminderTime.atTime,
    );

    when(mockReminderCalculationService.calculateReminderDateTime(
      baseDate: anyNamed('baseDate'),
      reminderTime: anyNamed('reminderTime'),
      customOffset: anyNamed('customOffset'),
    )).thenReturn(pastDate);

    await reminderService.scheduleTaskReminder(task);

    verifyNever(mockReminderService.cancelReminders(equals: 'task_planned_${task.id}'));
    verifyNever(mockReminderService.scheduleReminder(
      id: anyNamed('id'),
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: anyNamed('scheduledDate'),
      payload: anyNamed('payload'),
    ));
  });

  test('scheduleTaskReminder cancels existing reminder when reminder is disabled', () async {
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final task = Task(
      id: 'task-1',
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: futureDate,
      plannedDateReminderTime: ReminderTime.none,
    );

    await reminderService.scheduleTaskReminder(task);

    verify(mockReminderService.cancelReminders(equals: 'task_planned_${task.id}')).called(1);
    verifyNever(mockReminderService.scheduleReminder(
      id: anyNamed('id'),
      title: anyNamed('title'),
      body: anyNamed('body'),
      scheduledDate: anyNamed('scheduledDate'),
      payload: anyNamed('payload'),
    ));
  });

  // ── scheduleHabitReminder: daily target check ──

  group('scheduleHabitReminder skips when daily target is already met', () {
    test('does not schedule when daily target is met (single-occurrence habit, 1 record)', () async {
      final habit = habitWithReminder(dailyTarget: 1);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now.subtract(const Duration(hours: 2)),
        status: HabitRecordStatus.complete,
      );
      stubMediatorForHabit(habit, todayRecords: [record]);

      await reminderService.scheduleHabitReminder(habit);

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });

    test('does not schedule when daily target is met (multi-occurrence habit, 2 of 2)', () async {
      final habit = habitWithReminder(dailyTarget: 2);
      final now = DateTime.now();
      final records = List.generate(
          2,
          (i) => HabitRecordListItem(
                id: 'record-$i',
                date: DateTime(now.year, now.month, now.day),
                occurredAt: now.subtract(Duration(hours: i + 1)),
                status: HabitRecordStatus.complete,
              ));
      stubMediatorForHabit(habit, todayRecords: records);

      await reminderService.scheduleHabitReminder(habit);

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });

    test('schedules when daily target is not met (multi-occurrence habit, 1 of 3)', () async {
      final habit = habitWithReminder(dailyTarget: 3);
      final now = DateTime.now();
      final records = [
        HabitRecordListItem(
          id: 'record-1',
          date: DateTime(now.year, now.month, now.day),
          occurredAt: now.subtract(const Duration(hours: 1)),
          status: HabitRecordStatus.complete,
        )
      ];
      stubMediatorForHabit(habit, todayRecords: records);

      await reminderService.scheduleHabitReminder(habit);

      verify(mockReminderService.scheduleRecurringReminder(
        id: 'habit_habit-1',
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      )).called(1);
    });

    test('schedules when no records exist today', () async {
      final habit = habitWithReminder();
      stubMediatorForHabit(habit, todayRecords: []);

      await reminderService.scheduleHabitReminder(habit);

      verify(mockReminderService.scheduleRecurringReminder(
        id: 'habit_habit-1',
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      )).called(1);
    });

    test('schedules when only notDone/skipped records exist (no complete)', () async {
      final habit = habitWithReminder(dailyTarget: 1);
      final now = DateTime.now();
      final records = [
        HabitRecordListItem(
          id: 'record-1',
          date: DateTime(now.year, now.month, now.day),
          occurredAt: now.subtract(const Duration(hours: 1)),
          status: HabitRecordStatus.notDone,
        )
      ];
      stubMediatorForHabit(habit, todayRecords: records);

      await reminderService.scheduleHabitReminder(habit);

      verify(mockReminderService.scheduleRecurringReminder(
        id: 'habit_habit-1',
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      )).called(1);
    });
  });

  // ── handleHabitRecordAdded ──

  group('handleHabitRecordAdded', () {
    test('cancels habit reminders when daily target becomes met', () async {
      await reminderService.initialize();
      final habit = habitWithReminder(id: 'habit-1', dailyTarget: 1);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now,
        status: HabitRecordStatus.complete,
      );
      stubMediatorForHabit(habit, todayRecords: [record]);

      triggerRecordAdded('habit-1');
      await Future.delayed(Duration.zero);

      verify(mockReminderService.cancelReminders(startsWith: 'habit_habit-1')).called(1);
    });

    test('does not cancel when daily target is not yet met', () async {
      await reminderService.initialize();
      final habit = habitWithReminder(id: 'habit-1', dailyTarget: 3);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now,
        status: HabitRecordStatus.complete,
      );
      stubMediatorForHabit(habit, todayRecords: [record]);

      triggerRecordAdded('habit-1');
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.cancelReminders(startsWith: 'habit_habit-1'));
    });

    test('does nothing when habit has no reminder', () async {
      await reminderService.initialize();
      final habit = habitWithoutReminder(id: 'habit-1');
      stubMediatorForHabit(habit);

      triggerRecordAdded('habit-1');
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.cancelReminders(
        idFilter: anyNamed('idFilter'),
        startsWith: anyNamed('startsWith'),
        contains: anyNamed('contains'),
        equals: anyNamed('equals'),
      ));
    });

    test('does nothing when habitId is null', () async {
      await reminderService.initialize();

      triggerRecordAdded(null);
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.cancelReminders(
        idFilter: anyNamed('idFilter'),
        startsWith: anyNamed('startsWith'),
        contains: anyNamed('contains'),
        equals: anyNamed('equals'),
      ));
    });

    test('cancels reminders for multi-occurrence habit when all completions recorded', () async {
      await reminderService.initialize();
      final habit = habitWithReminder(id: 'habit-1', dailyTarget: 2);
      final now = DateTime.now();
      final records = List.generate(
          2,
          (i) => HabitRecordListItem(
                id: 'record-$i',
                date: DateTime(now.year, now.month, now.day),
                occurredAt: now,
                status: HabitRecordStatus.complete,
              ));
      stubMediatorForHabit(habit, todayRecords: records);

      triggerRecordAdded('habit-1');
      await Future.delayed(Duration.zero);

      verify(mockReminderService.cancelReminders(startsWith: 'habit_habit-1')).called(1);
    });

    test('handles mediator error gracefully', () async {
      await reminderService.initialize();
      mockMediator.setHandler((_) async => throw Exception('DB error'));

      triggerRecordAdded('habit-1');
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.cancelReminders(
        idFilter: anyNamed('idFilter'),
        startsWith: anyNamed('startsWith'),
        contains: anyNamed('contains'),
        equals: anyNamed('equals'),
      ));
    });
  });

  // ── handleHabitRecordRemoved ──

  group('handleHabitRecordRemoved', () {
    test('re-schedules habit reminders when daily target is no longer met', () async {
      await reminderService.initialize();
      final habit = habitWithReminder(id: 'habit-1', dailyTarget: 1);
      stubMediatorForHabit(habit, todayRecords: []);

      triggerRecordRemoved('habit-1');
      await Future.delayed(Duration.zero);

      verify(mockReminderService.scheduleRecurringReminder(
        id: 'habit_habit-1',
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      )).called(1);
    });

    test('does not re-schedule when daily target is still met', () async {
      await reminderService.initialize();
      final habit = habitWithReminder(id: 'habit-1', dailyTarget: 1);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now,
        status: HabitRecordStatus.complete,
      );
      stubMediatorForHabit(habit, todayRecords: [record]);

      triggerRecordRemoved('habit-1');
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });

    test('does nothing when habit has no reminder', () async {
      await reminderService.initialize();
      final habit = habitWithoutReminder(id: 'habit-1');
      stubMediatorForHabit(habit);

      triggerRecordRemoved('habit-1');
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });

    test('does nothing when habitId is null', () async {
      await reminderService.initialize();

      triggerRecordRemoved(null);
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });

    test('re-schedules for multi-occurrence habit when only partial completions remain', () async {
      await reminderService.initialize();
      final habit = habitWithReminder(id: 'habit-1', dailyTarget: 3);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now,
        status: HabitRecordStatus.complete,
      );
      stubMediatorForHabit(habit, todayRecords: [record]);

      triggerRecordRemoved('habit-1');
      await Future.delayed(Duration.zero);

      verify(mockReminderService.scheduleRecurringReminder(
        id: 'habit_habit-1',
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      )).called(1);
    });

    test('handles mediator error gracefully', () async {
      await reminderService.initialize();
      mockMediator.setHandler((_) async => throw Exception('DB error'));

      triggerRecordRemoved('habit-1');
      await Future.delayed(Duration.zero);

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });
  });

  // ── _scheduleExistingHabitReminders: init-time skip ──

  group('_scheduleExistingHabitReminders skips habits with daily target met', () {
    test('skips habits whose daily target is already met at init', () async {
      final habitItem = habitListItem(id: 'habit-1', name: 'Test Habit', dailyTarget: 1);
      final habitResponse = habitWithReminder(id: 'habit-1', dailyTarget: 1);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now,
        status: HabitRecordStatus.complete,
      );

      stubMediatorForInit(habits: [habitItem], habitResponse: habitResponse, todayRecords: [record]);

      await reminderService.initialize();

      verifyNever(mockReminderService.scheduleRecurringReminder(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      ));
    });

    test('schedules habits whose daily target is not yet met at init', () async {
      final habitItem = habitListItem(id: 'habit-1', name: 'Test Habit', dailyTarget: 2);
      final habitResponse = habitWithReminder(id: 'habit-1', dailyTarget: 2);
      final now = DateTime.now();
      final record = HabitRecordListItem(
        id: 'record-1',
        date: DateTime(now.year, now.month, now.day),
        occurredAt: now,
        status: HabitRecordStatus.complete,
      );

      stubMediatorForInit(habits: [habitItem], habitResponse: habitResponse, todayRecords: [record]);

      await reminderService.initialize();

      verify(mockReminderService.scheduleRecurringReminder(
        id: 'habit_habit-1',
        title: anyNamed('title'),
        body: anyNamed('body'),
        time: anyNamed('time'),
        days: anyNamed('days'),
        payload: anyNamed('payload'),
      )).called(1);
    });
  });
}
