import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:infrastructure_shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/notification_translation_service.dart';

/// Service to handle scheduling reminders for various entities
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

  /// Initialize the reminder service and set up event listeners
  Future<void> initialize() async {
    // Initialize the reminder service
    await _reminderService.init();

    // Initialize notification translation service
    await _notificationTranslationService.initialize();

    // Set up event listeners for tasks
    _tasksService.onTaskCreated.addListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.addListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.addListener(_handleTaskDeleted);
    _tasksService.onTaskCompleted.addListener(_handleTaskCompleted);

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
    _tasksService.onTaskCompleted.removeListener(_handleTaskCompleted);

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
        // Don't schedule reminders for archived habits
        if (habitItem.isArchived) {
          continue;
        }

        if (habitItem.hasReminder && habitItem.reminderTime != null) {
          // Get the full habit details using the application layer query
          final habitResponse = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
            GetHabitQuery(id: habitItem.id),
          );

          await scheduleHabitReminder(habitResponse, cancelExisting: false);
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
        // Don't schedule reminders for completed tasks
        if (taskItem.isCompleted) {
          continue;
        }

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

  /// Handle task completed event
  void _handleTaskCompleted() async {
    final taskId = _tasksService.onTaskCompleted.value;
    if (taskId == null) return;

    DomainLogger.debug('ReminderService: Task completed event received for task: $taskId');

    // Immediately cancel all reminders for the completed task
    await cancelRemindersForCompletedTask(taskId);

    DomainLogger.debug('ReminderService: Completed task reminder cancellation for task: $taskId');
  }

  /// Schedule a reminder for a task based on its reminder settings
  Future<void> scheduleTaskReminder(Task task) async {
    // Always cancel any existing reminders for this task first
    // Note: We don't cancel all reminders immediately anymore to allow persistent notifications for past events
    // await cancelTaskReminders(task.id);

    // Don't schedule reminders for completed or deleted tasks
    if (task.isCompleted || task.isDeleted) {
      // Explicitly cancel reminders again for completed/deleted tasks to ensure they're removed
      await cancelTaskReminders(task.id);
      return;
    }

    // Schedule planned date reminder if set
    if (task.plannedDate != null && task.plannedDateReminderTime != ReminderTime.none) {
      final reminderTime = _reminderCalculationService.calculateReminderDateTime(
        baseDate: task.plannedDate,
        reminderTime: task.plannedDateReminderTime,
        customOffset: task.plannedDateReminderCustomOffset,
      );

      // Skip if reminder calculation failed
      if (reminderTime == null) {
        DomainLogger.warning('ReminderService: Failed to calculate planned reminder time for task ${task.id}');
        DomainLogger.debug(
            'ReminderService: Cancelling planned reminder for task ${task.id} due to calculation failure');
        // If calculation fails (e.g. invalid date), ensure we don't leave a stale reminder
        await cancelEntityReminders(equals: _plannedReminderKey(task.id));
        return;
      }

      DomainLogger.debug('ReminderService: Scheduling planned reminder for task ${task.id}');
      DomainLogger.debug('Planned Date: ${task.plannedDate}');
      DomainLogger.debug('Reminder Time: ${task.plannedDateReminderTime}');
      DomainLogger.debug('Custom Offset: ${task.plannedDateReminderCustomOffset}');
      DomainLogger.debug('Calculated Reminder Time: $reminderTime');
      DomainLogger.debug('Current Time: ${DateTime.now()}');
      DomainLogger.debug('Is Future: ${reminderTime.isAfter(DateTime.now())}');

      if (reminderTime.isAfter(DateTime.now())) {
        // Only cancel existing reminder if we are scheduling a new future one
        // This preserves past notifications if the user merely opens the app
        await cancelEntityReminders(equals: _plannedReminderKey(task.id));

        // Pre-translate notification strings to ensure they work in background
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
        DomainLogger.debug(
            'ReminderService: Skipping planned scheduling for task ${task.id} because time is in the past.');
      }
    } else {
      // If reminder is explicitly disabled (or none), ensure any existing reminder is cancelled
      DomainLogger.debug(
          'ReminderService: Cancelling planned reminder for task ${task.id} because it is disabled or invalid. PlannedDate: ${task.plannedDate}, ReminderTime: ${task.plannedDateReminderTime}');
      await cancelEntityReminders(equals: _plannedReminderKey(task.id));
    }

    // Schedule deadline date reminder
    if (task.deadlineDate != null && task.deadlineDateReminderTime != ReminderTime.none) {
      final reminderTime = _reminderCalculationService.calculateReminderDateTime(
        baseDate: task.deadlineDate,
        reminderTime: task.deadlineDateReminderTime,
        customOffset: task.deadlineDateReminderCustomOffset,
      );

      // Skip if reminder calculation failed
      if (reminderTime == null) {
        DomainLogger.warning('ReminderService: Failed to calculate deadline reminder time for task ${task.id}');
        DomainLogger.debug(
            'ReminderService: Cancelling deadline reminder for task ${task.id} due to calculation failure');
        // If calculation fails (e.g. invalid date), ensure we don't leave a stale reminder
        await cancelEntityReminders(equals: _deadlineReminderKey(task.id));
        return;
      }

      DomainLogger.debug('ReminderService: Scheduling deadline reminder for task ${task.id}');
      DomainLogger.debug('Deadline Date: ${task.deadlineDate}');
      DomainLogger.debug('Reminder Time: ${task.deadlineDateReminderTime}');
      DomainLogger.debug('Custom Offset: ${task.deadlineDateReminderCustomOffset}');
      DomainLogger.debug('Calculated Reminder Time: $reminderTime');
      DomainLogger.debug('Current Time: ${DateTime.now()}');
      DomainLogger.debug('Is Future: ${reminderTime.isAfter(DateTime.now())}');

      if (reminderTime.isAfter(DateTime.now())) {
        // Only cancel existing reminder if we are scheduling a new future one
        // This preserves past notifications if the user merely opens the app
        await cancelEntityReminders(equals: _deadlineReminderKey(task.id));

        // Pre-translate notification strings to ensure they work in background
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
        DomainLogger.debug(
            'ReminderService: Skipping deadline scheduling for task ${task.id} because time is in the past.');
      }
    } else {
      // If reminder is explicitly disabled (or none), ensure any existing reminder is cancelled
      DomainLogger.debug(
          'ReminderService: Cancelling deadline reminder for task ${task.id} because it is disabled or invalid. DeadlineDate: ${task.deadlineDate}, ReminderTime: ${task.deadlineDateReminderTime}');
      await cancelEntityReminders(equals: _deadlineReminderKey(task.id));
    }
  }

  /// Schedule a recurring reminder for a habit based on its reminder settings
  Future<void> scheduleHabitReminder(Habit habit, {bool cancelExisting = true}) async {
    // Cancel any existing reminders for this habit if requested
    if (cancelExisting) {
      await cancelHabitReminders(habit.id);
    }

    // Don't schedule reminders for archived or deleted habits
    if (habit.isArchived || habit.isDeleted) {
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
          // Pre-translate notification strings to ensure they work in background
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

    DomainLogger.debug('ReminderService: Scheduling generic reminder');
    DomainLogger.debug('ID: $id');
    DomainLogger.debug('Scheduled Date (Local): $localScheduledDate');
    DomainLogger.debug('Current Time: ${DateTime.now()}');

    // Compare with current local time
    if (localScheduledDate.isAfter(DateTime.now())) {
      await _reminderService.scheduleReminder(
        id: id,
        title: title,
        body: body,
        scheduledDate: localScheduledDate,
        payload: payload,
      );
      DomainLogger.debug('Reminder scheduled successfully');
    } else {
      DomainLogger.debug('Reminder NOT scheduled (in the past)');
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
    DomainLogger.debug('ReminderService: Cancelling task reminders for task: $taskId');

    // Cancel reminders using the contains pattern to catch all variations
    await cancelEntityReminders(contains: taskId);

    // Also explicitly cancel by specific IDs to ensure they're removed
    await cancelEntityReminders(equals: _plannedReminderKey(taskId));
    await cancelEntityReminders(equals: _deadlineReminderKey(taskId));

    DomainLogger.debug('ReminderService: Task reminder cancellation completed for task: $taskId');
  }

  /// Cancel all reminders for a habit
  Future<void> cancelHabitReminders(String habitId) async {
    await cancelEntityReminders(startsWith: 'habit_$habitId');
  }

  /// Cancel reminders for a completed task (explicit method for task completion)
  Future<void> cancelRemindersForCompletedTask(String taskId) async {
    DomainLogger.debug('ReminderService: Starting reminder cancellation for completed task: $taskId');

    // Multiple approaches to ensure reminders are cancelled
    await cancelTaskReminders(taskId);

    // Additional explicit cancellation by exact IDs
    await _reminderService.cancelReminders(equals: _plannedReminderKey(taskId));
    await _reminderService.cancelReminders(equals: _deadlineReminderKey(taskId));

    // Use pattern matching as backup
    await _reminderService.cancelReminders(startsWith: 'task_', contains: taskId);

    DomainLogger.debug('ReminderService: Finished reminder cancellation for completed task: $taskId');
  }

  /// Refresh all reminders with updated language translations
  /// This method cancels all existing reminders and reschedules them with current language
  Future<void> refreshAllRemindersForLanguageChange() async {
    try {
      // 1. Reinitialize translation service to load new language
      await _notificationTranslationService.initialize();

      // 2. Reschedule all existing reminders with new language
      // Note: We deliberately do NOT call cancelAllReminders() here.
      // Calling cancelAllReminders() would remove all notifications, including "past" ones that are currently
      // visible in the tray. Since _scheduleExistingTaskReminders only schedules FUTURE reminders,
      // the past notifications would be lost forever (auto-dismissed).
      // By skipping cancelAllReminders, we:
      // - Update future reminders (scheduleTaskReminder cancels & reschedules them)
      // - Preserve past reminders (they keep the old language, but at least they remain visible)
      await _scheduleExistingHabitReminders();
      await _scheduleExistingTaskReminders();
    } catch (e) {
      DomainLogger.error('ReminderService: Error refreshing reminders for language change: $e');
    }
  }

  /// Format a DateTime to a readable time string
  String _formatTime(DateTime dateTime) {
    // Convert to local time before formatting for display
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);
    return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Generate the planned reminder key for a task
  String _plannedReminderKey(String taskId) => 'task_planned_$taskId';

  /// Generate the deadline reminder key for a task
  String _deadlineReminderKey(String taskId) => 'task_deadline_$taskId';
}
