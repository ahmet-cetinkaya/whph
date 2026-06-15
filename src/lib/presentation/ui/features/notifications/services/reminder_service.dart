import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/notification_translation_service.dart';

class ReminderService {
  final IReminderService _reminderService;
  final Mediator _mediator;
  final TasksService _tasksService;
  final HabitsService _habitsService;
  final ITranslationService _translationService;
  final INotificationPayloadHandler _notificationPayloadHandler;
  final IReminderCalculationService _reminderCalculationService;
  late final NotificationTranslationService _notificationTranslationService;

  ReminderService(
    this._reminderService,
    this._mediator,
    this._tasksService,
    this._habitsService,
    this._translationService,
    this._notificationPayloadHandler,
    this._reminderCalculationService,
  ) {
    _notificationTranslationService = NotificationTranslationService(_translationService);
  }

  Future<void> initialize() async {
    await _reminderService.init();
    await _notificationTranslationService.initialize();

    _tasksService.onTaskCreated.addListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.addListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.addListener(_handleTaskDeleted);
    _tasksService.onTaskCompleted.addListener(_handleTaskCompleted);

    _habitsService.onHabitCreated.addListener(_handleHabitCreated);
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
    _habitsService.onHabitDeleted.addListener(_handleHabitDeleted);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordAdded);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordRemoved);

    await _scheduleExistingHabitReminders();
    await _scheduleExistingTaskReminders();
  }

  void dispose() {
    _tasksService.onTaskCreated.removeListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.removeListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.removeListener(_handleTaskDeleted);
    _tasksService.onTaskCompleted.removeListener(_handleTaskCompleted);

    _habitsService.onHabitCreated.removeListener(_handleHabitCreated);
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
    _habitsService.onHabitDeleted.removeListener(_handleHabitDeleted);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordAdded);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordRemoved);
  }

  Future<void> _scheduleExistingHabitReminders() async {
    try {
      final habitsResponse = await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(
        GetListHabitsQuery(pageIndex: 0, pageSize: 1000),
      );

      for (final habitItem in habitsResponse.items) {
        if (habitItem.isArchived) continue;

        if (habitItem.hasReminder && habitItem.reminderTime != null) {
          final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
            GetHabitQuery(id: habitItem.id),
          );

          if (await _isHabitDailyTargetMet(habitResponse)) continue;

          await scheduleHabitReminder(habitResponse, cancelExisting: false);
        }
      }
    } catch (e) {
      // Silently skip errors during initial reminder scheduling
    }
  }

  Future<void> _scheduleExistingTaskReminders() async {
    try {
      final tasksResponse = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(pageIndex: 0, pageSize: 1000),
      );

      for (final taskItem in tasksResponse.items) {
        if (taskItem.isCompleted) continue;

        final hasPlannedDateReminder =
            taskItem.plannedDate != null && taskItem.plannedDateReminderTime != ReminderTime.none;
        final hasDeadlineDateReminder =
            taskItem.deadlineDate != null && taskItem.deadlineDateReminderTime != ReminderTime.none;

        if (hasPlannedDateReminder || hasDeadlineDateReminder) {
          final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
            GetTaskQuery(id: taskItem.id),
          );

          await scheduleTaskReminder(taskResponse);
        }
      }
    } catch (e) {
      // Silently skip errors during initial reminder scheduling
    }
  }

  void _handleTaskCreated() async {
    final taskId = _tasksService.onTaskCreated.value;
    if (taskId == null) return;

    final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );

    await scheduleTaskReminder(taskResponse);
  }

  void _handleTaskUpdated() async {
    final taskId = _tasksService.onTaskUpdated.value;
    if (taskId == null) return;

    final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );

    await scheduleTaskReminder(taskResponse);
  }

  void _handleTaskDeleted() async {
    final taskId = _tasksService.onTaskDeleted.value;
    if (taskId == null) return;

    await cancelTaskReminders(taskId);
  }

  void _handleHabitCreated() async {
    final habitId = _habitsService.onHabitCreated.value;
    if (habitId == null) return;

    final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
      GetHabitQuery(id: habitId),
    );

    await scheduleHabitReminder(habitResponse);
  }

  void _handleHabitUpdated() async {
    final habitId = _habitsService.onHabitUpdated.value;
    if (habitId == null) return;

    final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
      GetHabitQuery(id: habitId),
    );

    if (habitResponse.hasReminder) {
      if (habitResponse.getReminderDaysAsList().isEmpty) {
        habitResponse.setReminderDaysFromList(List.generate(7, (index) => index + 1));
      }
    }

    await scheduleHabitReminder(habitResponse);
  }

  void _handleHabitDeleted() async {
    final habitId = _habitsService.onHabitDeleted.value;
    if (habitId == null) return;

    await cancelHabitReminders(habitId);
  }

  void _handleHabitRecordAdded() async {
    final habitId = _habitsService.onHabitRecordAdded.value;
    if (habitId == null) return;

    try {
      final habit = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
        GetHabitQuery(id: habitId),
      );

      if (!habit.hasReminder || habit.reminderTime == null) return;

      if (await _isHabitDailyTargetMet(habit)) {
        await cancelHabitReminders(habitId);
        Logger.debug('ReminderService: Cancelled habit reminder for $habitId — daily target met');
      }
    } catch (e) {
      Logger.error('ReminderService: Error handling habit record added: $e');
    }
  }

  void _handleHabitRecordRemoved() async {
    final habitId = _habitsService.onHabitRecordRemoved.value;
    if (habitId == null) return;

    try {
      final habit = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
        GetHabitQuery(id: habitId),
      );

      if (!habit.hasReminder || habit.reminderTime == null) return;

      if (!(await _isHabitDailyTargetMet(habit))) {
        await scheduleHabitReminder(habit);
        Logger.debug('ReminderService: Re-scheduled habit reminder for $habitId — daily target no longer met');
      }
    } catch (e) {
      Logger.error('ReminderService: Error handling habit record removed: $e');
    }
  }

  void _handleTaskCompleted() async {
    final taskId = _tasksService.onTaskCompleted.value;
    if (taskId == null) return;

    await cancelRemindersForCompletedTask(taskId);

    Logger.debug('ReminderService: Completed task reminder cancellation for task: $taskId');
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.isCompleted || task.isDeleted) {
      await cancelTaskReminders(task.id);
      return;
    }

    if (task.plannedDate != null && task.plannedDateReminderTime != ReminderTime.none) {
      final reminderTime = _reminderCalculationService.calculateReminderDateTime(
        baseDate: task.plannedDate,
        reminderTime: task.plannedDateReminderTime,
        customOffset: task.plannedDateReminderCustomOffset,
      );

      if (reminderTime == null) {
        Logger.warning('ReminderService: Failed to calculate planned reminder time for task ${task.id}');
        Logger.debug('ReminderService: Cancelling planned reminder for task ${task.id} due to calculation failure');
        await cancelEntityReminders(equals: _plannedReminderKey(task.id));
        return;
      }

      if (reminderTime.isAfter(DateTime.now())) {
        // Cancel existing reminder only when scheduling a new future one (preserves past notifications)
        await cancelEntityReminders(equals: _plannedReminderKey(task.id));

        final notificationStrings = _notificationTranslationService.preTranslateNotificationStrings(
          titleKey: TaskTranslationKeys.notificationReminderTitle,
          bodyKey: TaskTranslationKeys.notificationPlannedMessage,
          titleArgs: {'title': task.title},
          bodyArgs: {'time': _formatTime(task.plannedDate!)},
        );

        await scheduleReminder(
          id: _plannedReminderKey(task.id),
          title: notificationStrings.title,
          body: notificationStrings.body,
          scheduledDate: reminderTime,
          payload: _notificationPayloadHandler.createNavigationPayload(
            route: TasksPage.route,
            arguments: {'taskId': task.id},
          ),
        );
      } else {
        Logger.debug('ReminderService: Skipping planned scheduling for task ${task.id} because time is in the past.');
      }
    } else {
      Logger.debug(
          'ReminderService: Cancelling planned reminder for task ${task.id} because it is disabled or invalid. PlannedDate: ${task.plannedDate}, ReminderTime: ${task.plannedDateReminderTime}');
      await cancelEntityReminders(equals: _plannedReminderKey(task.id));
    }

    if (task.deadlineDate != null && task.deadlineDateReminderTime != ReminderTime.none) {
      final reminderTime = _reminderCalculationService.calculateReminderDateTime(
        baseDate: task.deadlineDate,
        reminderTime: task.deadlineDateReminderTime,
        customOffset: task.deadlineDateReminderCustomOffset,
      );

      if (reminderTime == null) {
        Logger.warning('ReminderService: Failed to calculate deadline reminder time for task ${task.id}');
        Logger.debug('ReminderService: Cancelling deadline reminder for task ${task.id} due to calculation failure');
        await cancelEntityReminders(equals: _deadlineReminderKey(task.id));
        return;
      }

      if (reminderTime.isAfter(DateTime.now())) {
        // Cancel existing reminder only when scheduling a new future one (preserves past notifications)
        await cancelEntityReminders(equals: _deadlineReminderKey(task.id));

        final notificationStrings = _notificationTranslationService.preTranslateNotificationStrings(
          titleKey: TaskTranslationKeys.notificationDeadlineTitle,
          bodyKey: TaskTranslationKeys.notificationDeadlineMessage,
          titleArgs: {'title': task.title},
          bodyArgs: {'time': _formatTime(task.deadlineDate!)},
        );

        await scheduleReminder(
          id: _deadlineReminderKey(task.id),
          title: notificationStrings.title,
          body: notificationStrings.body,
          scheduledDate: reminderTime,
          payload: _notificationPayloadHandler.createNavigationPayload(
            route: TasksPage.route,
            arguments: {'taskId': task.id},
          ),
        );
      } else {
        Logger.debug('ReminderService: Skipping deadline scheduling for task ${task.id} because time is in the past.');
      }
    } else {
      Logger.debug(
          'ReminderService: Cancelling deadline reminder for task ${task.id} because it is disabled or invalid. DeadlineDate: ${task.deadlineDate}, ReminderTime: ${task.deadlineDateReminderTime}');
      await cancelEntityReminders(equals: _deadlineReminderKey(task.id));
    }
  }

  Future<void> scheduleHabitReminder(Habit habit, {bool cancelExisting = true}) async {
    if (cancelExisting) {
      await cancelHabitReminders(habit.id);
    }

    if (habit.isArchived || habit.isDeleted) return;

    if (await _isHabitDailyTargetMet(habit)) return;

    if (habit.hasReminder && habit.reminderTime != null) {
      final reminderDaysList = habit.getReminderDaysAsList();
      if (reminderDaysList.isEmpty) return;

      final timeOfDay = habit.getReminderTimeOfDay();
      if (timeOfDay != null) {
        try {
          // Pre-translate for background notification delivery
          final notificationStrings = _notificationTranslationService.preTranslateNotificationStrings(
            titleKey: HabitTranslationKeys.notificationReminderTitle,
            bodyKey: HabitTranslationKeys.notificationReminderMessage,
            titleArgs: {'name': habit.name},
            bodyArgs: {'name': habit.name},
          );

          await scheduleRecurringReminder(
            id: 'habit_${habit.id}',
            title: notificationStrings.title,
            body: notificationStrings.body,
            time: timeOfDay,
            days: reminderDaysList,
            payload: _notificationPayloadHandler.createNavigationPayload(
              route: HabitsPage.route,
              arguments: {'habitId': habit.id},
            ),
          );
        } catch (e) {
          // Silently skip errors during habit reminder scheduling
        }
      }
    }
  }

  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final localScheduledDate = DateTimeHelper.toLocalDateTime(scheduledDate);
    if (localScheduledDate.isAfter(DateTime.now())) {
      await _reminderService.scheduleReminder(
        id: id,
        title: title,
        body: body,
        scheduledDate: localScheduledDate,
        payload: payload,
      );
    }
  }

  Future<void> scheduleRecurringReminder({
    required String id,
    required String title,
    required String body,
    required TimeOfDay time,
    required List<int> days,
    String? payload,
  }) async {
    if (days.isNotEmpty) {
      await _reminderService.scheduleRecurringReminder(
        id: id,
        title: title,
        body: body,
        time: time,
        days: days,
        payload: payload,
      );
    }
  }

  Future<void> cancelEntityReminders({
    bool Function(String id)? idFilter,
    String? startsWith,
    String? contains,
    String? equals,
  }) async {
    await _reminderService.cancelReminders(
      idFilter: idFilter,
      startsWith: startsWith,
      contains: contains,
      equals: equals,
    );
  }

  Future<void> cancelTaskReminders(String taskId) async {
    await cancelEntityReminders(contains: taskId);
    await cancelEntityReminders(equals: _plannedReminderKey(taskId));
    await cancelEntityReminders(equals: _deadlineReminderKey(taskId));
  }

  Future<void> cancelHabitReminders(String habitId) async {
    await cancelEntityReminders(startsWith: 'habit_$habitId');
  }

  Future<bool> _isHabitDailyTargetMet(Habit habit) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    final recordsResponse = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
      GetListHabitRecordsQuery(
        habitId: habit.id,
        startDate: startOfDay,
        endDate: endOfDay,
        pageIndex: 0,
        pageSize: 1000,
      ),
    );

    final completedCount = recordsResponse.items.where((r) => r.status == HabitRecordStatus.complete).length;
    return habit.isDailyTargetMet(completedCount);
  }

  Future<void> cancelRemindersForCompletedTask(String taskId) async {
    await cancelTaskReminders(taskId);
    await _reminderService.cancelReminders(equals: _plannedReminderKey(taskId));
    await _reminderService.cancelReminders(equals: _deadlineReminderKey(taskId));
    await _reminderService.cancelReminders(startsWith: 'task_', contains: taskId);
  }

  Future<void> refreshAllRemindersForLanguageChange() async {
    try {
      await _notificationTranslationService.initialize();
      // Don't cancel existing notifications — that would remove visible past reminders from the tray.
      // scheduleTaskReminder cancels & reschedules each future reminder, preserving past ones.
      await _scheduleExistingHabitReminders();
      await _scheduleExistingTaskReminders();
    } catch (e) {
      Logger.error('ReminderService: Error refreshing reminders for language change: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);
    return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }

  String _plannedReminderKey(String taskId) => 'task_planned_$taskId';

  String _deadlineReminderKey(String taskId) => 'task_deadline_$taskId';
}
