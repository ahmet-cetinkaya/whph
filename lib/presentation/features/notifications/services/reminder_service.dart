import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/infrastructure/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// Service to handle scheduling reminders for various entities
class ReminderService {
  final IReminderService _reminderService;
  final Mediator _mediator;
  final TasksService _tasksService;
  final HabitsService _habitsService;
  final ITranslationService _translationService;
  final INotificationPayloadHandler _notificationPayloadHandler;

  ReminderService(
    this._reminderService,
    this._mediator,
    this._tasksService,
    this._habitsService,
    this._translationService,
    this._notificationPayloadHandler,
  );

  /// Initialize the reminder service and set up event listeners
  Future<void> initialize() async {
    // Initialize the reminder service
    await _reminderService.init();

    // Set up event listeners for tasks
    _tasksService.onTaskCreated.addListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.addListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.addListener(_handleTaskDeleted);

    // Set up event listeners for habits
    _habitsService.onHabitCreated.addListener(_handleHabitCreated);
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
    _habitsService.onHabitDeleted.addListener(_handleHabitDeleted);

    // Schedule reminders for existing habits with reminders enabled
    await _scheduleExistingHabitReminders();

    // Schedule reminders for existing tasks with reminders enabled
    await _scheduleExistingTaskReminders();
  }

  /// Dispose event listeners
  void dispose() {
    _tasksService.onTaskCreated.removeListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.removeListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.removeListener(_handleTaskDeleted);

    _habitsService.onHabitCreated.removeListener(_handleHabitCreated);
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
    _habitsService.onHabitDeleted.removeListener(_handleHabitDeleted);
  }

  /// Schedule reminders for all existing habits that have reminders enabled
  Future<void> _scheduleExistingHabitReminders() async {
    try {
      // Get all habits using the application layer query
      final habitsResponse = await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(
        GetListHabitsQuery(pageIndex: 0, pageSize: 1000),
      );

      // Schedule reminders for habits with reminders enabled
      for (final habitItem in habitsResponse.items) {
        if (habitItem.hasReminder && habitItem.reminderTime != null) {
          // Get the full habit details using the application layer query
          final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
            GetHabitQuery(id: habitItem.id),
          );

          await scheduleHabitReminder(habitResponse);
        }
      }
    } catch (e) {
      // Error handled silently in production
    }
  }

  /// Schedule reminders for all existing tasks that have reminders enabled
  Future<void> _scheduleExistingTaskReminders() async {
    try {
      // Get all tasks using the application layer query
      final tasksResponse = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
        GetListTasksQuery(pageIndex: 0, pageSize: 1000),
      );

      // Schedule reminders for tasks with reminders enabled
      for (final taskItem in tasksResponse.items) {
        // Check if task has any reminder-enabled dates
        final hasPlannedDateReminder =
            taskItem.plannedDate != null && taskItem.plannedDateReminderTime != ReminderTime.none;
        final hasDeadlineDateReminder =
            taskItem.deadlineDate != null && taskItem.deadlineDateReminderTime != ReminderTime.none;

        if (hasPlannedDateReminder || hasDeadlineDateReminder) {
          // Get the full task details using the application layer query
          final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
            GetTaskQuery(id: taskItem.id),
          );

          await scheduleTaskReminder(taskResponse);
        }
      }
    } catch (e) {
      // Error handled silently in production
    }
  }

  /// Handle task created event
  void _handleTaskCreated() async {
    final taskId = _tasksService.onTaskCreated.value;
    if (taskId == null) return;

    final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );

    await scheduleTaskReminder(taskResponse);
  }

  /// Handle task updated event
  void _handleTaskUpdated() async {
    final taskId = _tasksService.onTaskUpdated.value;
    if (taskId == null) return;

    final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );

    await scheduleTaskReminder(taskResponse);
  }

  /// Handle task deleted event
  void _handleTaskDeleted() async {
    final taskId = _tasksService.onTaskDeleted.value;
    if (taskId == null) return;

    await cancelTaskReminders(taskId);
  }

  /// Handle habit created event
  void _handleHabitCreated() async {
    final habitId = _habitsService.onHabitCreated.value;
    if (habitId == null) return;

    final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
      GetHabitQuery(id: habitId),
    );

    await scheduleHabitReminder(habitResponse);
  }

  /// Handle habit updated event
  void _handleHabitUpdated() async {
    final habitId = _habitsService.onHabitUpdated.value;
    if (habitId == null) return;

    final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
      GetHabitQuery(id: habitId),
    );

    // Ensure we have valid reminder data before scheduling
    if (habitResponse.hasReminder) {
      // If reminder is enabled but no days are selected, select all days by default
      if (habitResponse.getReminderDaysAsList().isEmpty) {
        // This is now handled in the service layer
        habitResponse.setReminderDaysFromList(List.generate(7, (index) => index + 1));
      }
    }

    await scheduleHabitReminder(habitResponse);
  }

  /// Handle habit deleted event
  void _handleHabitDeleted() async {
    final habitId = _habitsService.onHabitDeleted.value;
    if (habitId == null) return;

    await cancelHabitReminders(habitId);
  }

  /// Schedule a reminder for a task based on its reminder settings
  Future<void> scheduleTaskReminder(Task task) async {
    // Cancel any existing reminders for this task
    await cancelTaskReminders(task.id);

    // Schedule planned date reminder if set
    if (task.plannedDate != null && task.plannedDateReminderTime != ReminderTime.none) {
      final reminderTime = _calculateTaskReminderTime(task.plannedDate!, task.plannedDateReminderTime);

      // Only schedule if the reminder time is in the future
      if (reminderTime.isAfter(DateTime.now())) {
        await scheduleReminder(
          id: 'task_planned_${task.id}',
          title: _translationService
              .translate(TaskTranslationKeys.notificationReminderTitle, namedArgs: {'title': task.title}),
          body: _translationService.translate(TaskTranslationKeys.notificationPlannedMessage,
              namedArgs: {'time': _formatTime(task.plannedDate!)}),
          scheduledDate: reminderTime,
          payload: _notificationPayloadHandler.createNavigationPayload(
            route: TasksPage.route,
            arguments: {'showTaskDetails': task.id},
          ),
        );
      }
    }

    // Schedule deadline date reminder if set
    if (task.deadlineDate != null && task.deadlineDateReminderTime != ReminderTime.none) {
      final reminderTime = _calculateTaskReminderTime(task.deadlineDate!, task.deadlineDateReminderTime);

      // Only schedule if the reminder time is in the future
      if (reminderTime.isAfter(DateTime.now())) {
        await scheduleReminder(
          id: 'task_deadline_${task.id}',
          title: _translationService
              .translate(TaskTranslationKeys.notificationDeadlineTitle, namedArgs: {'title': task.title}),
          body: _translationService.translate(TaskTranslationKeys.notificationDeadlineMessage,
              namedArgs: {'time': _formatTime(task.deadlineDate!)}),
          scheduledDate: reminderTime,
          payload: _notificationPayloadHandler.createNavigationPayload(
            route: TasksPage.route,
            arguments: {'showTaskDetails': task.id},
          ),
        );
      }
    }
  }

  /// Schedule a recurring reminder for a habit based on its reminder settings
  Future<void> scheduleHabitReminder(Habit habit) async {
    // Cancel any existing reminders for this habit
    await cancelHabitReminders(habit.id);

    // Don't schedule reminders for archived habits
    if (habit.isArchived()) {
      return;
    }

    // Schedule habit reminder if enabled
    if (habit.hasReminder && habit.reminderTime != null) {
      final reminderDaysList = habit.getReminderDaysAsList();

      if (reminderDaysList.isEmpty) {
        return;
      }

      final timeOfDay = habit.getReminderTimeOfDay();
      if (timeOfDay != null) {
        try {
          await scheduleRecurringReminder(
            id: 'habit_${habit.id}',
            title: _translationService
                .translate(HabitTranslationKeys.notificationReminderTitle, namedArgs: {'name': habit.name}),
            body: _translationService
                .translate(HabitTranslationKeys.notificationReminderMessage, namedArgs: {'name': habit.name}),
            time: timeOfDay,
            days: reminderDaysList,
            payload: _notificationPayloadHandler.createNavigationPayload(
              route: HabitsPage.route,
              arguments: {'showHabitDetails': habit.id},
            ),
          );
        } catch (e) {
          // Error handled silently in production
        }
      }
    }
  }

  /// Schedule a generic reminder for any entity
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Convert to local time using helper method that handles UTC check internally
    final localScheduledDate = DateTimeHelper.toLocalDateTime(scheduledDate);

    // Compare with current local time
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

  /// Schedule a recurring reminder for any entity
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

  /// Cancel reminders based on ID pattern
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

  /// Cancel all reminders for a task
  Future<void> cancelTaskReminders(String taskId) async {
    await cancelEntityReminders(startsWith: 'task_$taskId');
  }

  /// Cancel all reminders for a habit
  Future<void> cancelHabitReminders(String habitId) async {
    await cancelEntityReminders(startsWith: 'habit_$habitId');
  }

  /// Calculate the reminder time based on the task date and reminder setting
  DateTime _calculateTaskReminderTime(DateTime taskDate, ReminderTime reminderTime) {
    switch (reminderTime) {
      case ReminderTime.atTime:
        return taskDate;
      case ReminderTime.fiveMinutesBefore:
        return taskDate.subtract(const Duration(minutes: 5));
      case ReminderTime.fifteenMinutesBefore:
        return taskDate.subtract(const Duration(minutes: 15));
      case ReminderTime.oneHourBefore:
        return taskDate.subtract(const Duration(hours: 1));
      case ReminderTime.oneDayBefore:
        return taskDate.subtract(const Duration(days: 1));
      case ReminderTime.none:
        return taskDate;
    }
  }

  /// Format a DateTime to a readable time string
  String _formatTime(DateTime dateTime) {
    // Convert to local time before formatting for display
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);
    return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }
}
