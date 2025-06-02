import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/application/features/tasks/constants/task_translation_keys.dart' as application;

class TaskTranslationKeys extends application.TaskTranslationKeys {
  // Pomodoro
  static const String pomodoroNotificationTitle = 'tasks.pomodoro.notifications.title';
  static const String pomodoroWorkSessionCompleted = 'tasks.pomodoro.notifications.work_completed';
  static const String pomodoroBreakSessionCompleted = 'tasks.pomodoro.notifications.break_completed';
  static const String pomodoroLongBreakSessionCompleted = 'tasks.pomodoro.notifications.long_break_completed';
  static const String pomodoroTimeRemainingPrefix = 'tasks.pomodoro.notifications.time_remaining_prefix';
  static const String pomodoroTimerCompleted = 'tasks.pomodoro.notifications.timer_completed';
  static const String pomodoroSystemTrayTimerRunning = 'tasks.pomodoro.system_tray.timer_running';
  static const String pomodoroSystemTrayCompleteTitle = 'tasks.pomodoro.system_tray.complete_title';
  static const String pomodoroSystemTrayAppRunning = 'tasks.pomodoro.system_tray.app_running';
  static const String pomodoroSystemTrayTapToOpen = 'tasks.pomodoro.system_tray.tap_to_open';
  static const String pomodoroSettingsLabel = 'tasks.pomodoro.settings.title';
  static const String pomodoroTimerSettingsLabel = 'tasks.pomodoro.settings.timer_label';
  static const String pomodoroWorkLabel = 'tasks.pomodoro.settings.work_duration';
  static const String pomodoroBreakLabel = 'tasks.pomodoro.settings.break_duration';
  static const String pomodoroLongBreakLabel = 'tasks.pomodoro.settings.long_break_duration';
  static const String pomodoroSessionsCountLabel = 'tasks.pomodoro.settings.sessions_before_long_break';
  static const String pomodoroAutoStartBreakLabel = 'tasks.pomodoro.settings.auto_start_break';
  static const String pomodoroAutoStartWorkLabel = 'tasks.pomodoro.settings.auto_start_work';
  static const String pomodoroStopTimer = 'tasks.pomodoro.actions.stop_timer';
  static const String pomodoroAutoStartSectionLabel = 'tasks.pomodoro.settings.auto_start_section';
  static const String pomodoroTickingSoundSectionLabel = 'tasks.pomodoro.settings.ticking_sound_section';
  static const String pomodoroTickingSoundLabel = 'tasks.pomodoro.settings.ticking_sound';
  static const String pomodoroTickingVolumeLabel = 'tasks.pomodoro.settings.ticking_volume';
  static const String pomodoroTickingSpeedLabel = 'tasks.pomodoro.settings.ticking_speed';
  static const String pomodoroKeepScreenAwakeSectionLabel = 'tasks.pomodoro.settings.keep_screen_awake_section';
  static const String pomodoroKeepScreenAwakeLabel = 'tasks.pomodoro.settings.keep_screen_awake';

  // Priority Selection
  static const String prioritySelectionTitle = 'tasks.priority.selection.title';
  static const String priorityUrgentImportant = 'tasks.priority.types.urgent_important';
  static const String priorityNotUrgentImportant = 'tasks.priority.types.not_urgent_important';
  static const String priorityUrgentNotImportant = 'tasks.priority.types.urgent_not_important';
  static const String priorityNotUrgentNotImportant = 'tasks.priority.types.not_urgent_not_important';
  static const String priorityNone = 'tasks.priority.types.none';

  // Priority Tooltips
  static const String priorityUrgentImportantTooltip = 'tasks.priority.tooltips.urgent_important';
  static const String priorityNotUrgentImportantTooltip = 'tasks.priority.tooltips.not_urgent_important';
  static const String priorityUrgentNotImportantTooltip = 'tasks.priority.tooltips.urgent_not_important';
  static const String priorityNotUrgentNotImportantTooltip = 'tasks.priority.tooltips.not_urgent_not_important';
  static const String priorityNoneTooltip = 'tasks.priority.tooltips.none';

  // Quick Task
  static const String quickTaskTitle = 'tasks.quick_task.title';
  static const String quickTaskTitleHint = 'tasks.quick_task.title_hint';
  static const String quickTaskCreateError = 'tasks.quick_task.create_error';
  static const String quickTaskResetAll = 'tasks.quick_task.reset_all';
  static const String quickTaskLockSettings = 'tasks.quick_task.lock_settings';
  static const String quickTaskLockDescription = 'tasks.quick_task.lock_description';

  // Quick Task Tooltips
  static const String quickTaskEstimatedTime = 'tasks.quick_task.tooltips.estimated_time';
  static const String quickTaskEstimatedTimeNotSet = 'tasks.quick_task.tooltips.estimated_time_not_set';
  static const String quickTaskPlannedDate = 'tasks.quick_task.tooltips.planned_date';
  static const String quickTaskPlannedDateNotSet = 'tasks.quick_task.tooltips.planned_date_not_set';
  static const String quickTaskDeadlineDate = 'tasks.quick_task.tooltips.deadline_date';
  static const String quickTaskDeadlineDateNotSet = 'tasks.quick_task.tooltips.deadline_date_not_set';

  // Quick Task Reset Confirmation
  static const String quickTaskResetConfirmTitle = 'tasks.quick_task.reset_confirm.title';
  static const String quickTaskResetConfirmMessage = 'tasks.quick_task.reset_confirm.message';

  // Date Selection Titles
  static const String selectPlannedDateTitle = 'tasks.date_selection.planned_date_title';
  static const String selectDeadlineDateTitle = 'tasks.date_selection.deadline_date_title';

  // Task Add Button
  static const String addTaskButtonTooltip = 'tasks.add_button.tooltip';

  // Task Card
  static const String taskScheduleTooltip = 'tasks.card.tooltips.schedule';
  static const String taskScheduleToday = 'tasks.card.schedule.today';
  static const String taskScheduleTomorrow = 'tasks.card.schedule.tomorrow';

  // Task Delete
  static const String taskDeleteTitle = 'tasks.delete.title';
  static const String taskDeleteMessage = 'tasks.delete.message';
  static const String taskDeleteError = 'tasks.delete.error';

  // Task Complete
  static const String taskCompleteError = 'tasks.complete.error';

  // Task Filters
  static const String filterByTagsTooltip = 'tasks.filters.tooltips.filter_by_tags';
  static const String searchTasksPlaceholder = 'tasks.filters.search.placeholder';

  // Details
  static const String titleLabel = 'tasks.details.title.label';
  static const String tagsLabel = 'tasks.details.tags.label';
  static const String tagsHint = 'tasks.details.tags.hint';
  static const String priorityLabel = 'tasks.details.priority.label';
  static const String estimatedTimeLabel = 'tasks.details.estimated_time.label';
  static const String elapsedTimeLabel = 'tasks.details.elapsed_time.label';
  static const String plannedDateLabel = 'tasks.details.planned_date.label';
  static const String deadlineDateLabel = 'tasks.details.deadline_date.label';
  static const String descriptionLabel = 'tasks.details.description.label';
  static const String addDescriptionHint = 'tasks.details.description.hint';

  // Help
  static const String detailsHelpTitle = 'tasks.help.details.title';
  static const String detailsHelpContent = 'tasks.help.details.content';

  // Tasks Page
  static const String tasksPageTitle = 'tasks.page.title';
  static const String completedTasksTitle = 'tasks.page.completed_tasks_title';
  static const String tasksHelpTitle = 'tasks.help.overview.title';
  static const String tasksHelpContent = 'tasks.help.overview.content';
  static const String noTasks = 'tasks.no_tasks';
  static const String allTasksDone = 'tasks.all_tasks_done';

  // Errors
  static const String getTaskError = 'tasks.errors.get_task';
  static const String saveTaskError = 'tasks.errors.save_task';
  static const String addTagError = 'tasks.errors.add_tag';
  static const String removeTagError = 'tasks.errors.remove_tag';
  static const String getTagsError = 'tasks.errors.get_tags';

  // Tooltips
  static const String editTitleTooltip = 'tasks.tooltips.edit_title';
  static const String showCompletedTasksTooltip = 'tasks.tooltips.show_completed_tasks';
  static const String setReminderTooltip = 'tasks.tooltips.set_reminder';
  static const String clearDateTooltip = 'tasks.tooltips.clear_date';
  static const String decreaseEstimatedTime = 'tasks.tooltips.decrease_estimated_time';
  static const String increaseEstimatedTime = 'tasks.tooltips.increase_estimated_time';

  // Marathon Mode
  static const String marathon = 'tasks.marathon.label';
  static const String marathonHelpTitle = 'tasks.marathon.help.title';
  static const String marathonHelpContent = 'tasks.marathon.help.content';
  static const String marathonHelpTooltip = 'tasks.marathon.help.tooltip';
  static const String marathonDetailsTitle = 'tasks.marathon.details.title';
  static const String marathonUnpinTaskTooltip = 'tasks.marathon.unpin_task_tooltip';

  // Sub Tasks
  static const String subTasksLabel = 'tasks.details.sub_tasks.label';

  // Notification Messages
  static const String notificationReminderTitle = 'tasks.notifications.reminder_title';
  static const String notificationDeadlineTitle = 'tasks.notifications.deadline_title';
  static const String notificationPlannedMessage = 'tasks.notifications.planned_message';
  static const String notificationDeadlineMessage = 'tasks.notifications.deadline_message';

  // Reminder Types and Labels
  static const String reminderNone = 'tasks.reminder.none';
  static const String reminderAtTime = 'tasks.reminder.atTime';
  static const String reminderFiveMinutesBefore = 'tasks.reminder.fiveMinutesBefore';
  static const String reminderFifteenMinutesBefore = 'tasks.reminder.fifteenMinutesBefore';
  static const String reminderOneHourBefore = 'tasks.reminder.oneHourBefore';
  static const String reminderOneDayBefore = 'tasks.reminder.oneDayBefore';
  static const String reminderPlannedLabel = 'tasks.reminder.plannedReminderLabel';
  static const String reminderDeadlineLabel = 'tasks.reminder.deadlineReminderLabel';

  // Recurrence Types and Labels
  static const String recurrenceLabel = 'tasks.recurrence.label';
  static const String recurrenceNone = 'tasks.recurrence.none';
  static const String recurrenceDaily = 'tasks.recurrence.daily';
  static const String recurrenceWeekly = 'tasks.recurrence.weekly';
  static const String recurrenceMonthly = 'tasks.recurrence.monthly';
  static const String recurrenceYearly = 'tasks.recurrence.yearly';
  static const String recurrenceCustom = 'tasks.recurrence.custom';
  static const String recurrenceIntervalLabel = 'tasks.recurrence.interval.label';
  static const String recurrenceIntervalPrefix = 'tasks.recurrence.interval.prefix';
  static const String recurrenceIntervalSuffixDays = 'tasks.recurrence.interval.suffix.days';
  static const String recurrenceIntervalSuffixWeeks = 'tasks.recurrence.interval.suffix.weeks';
  static const String recurrenceIntervalSuffixMonths = 'tasks.recurrence.interval.suffix.months';
  static const String recurrenceIntervalSuffixYears = 'tasks.recurrence.interval.suffix.years';
  static const String recurrenceWeekDaysLabel = 'tasks.recurrence.weekDays';
  static const String recurrenceRangeLabel = 'tasks.recurrence.range';
  static const String recurrenceStartLabel = 'tasks.recurrence.startDate';
  static const String recurrenceEndDateLabel = 'tasks.recurrence.endDate';
  static const String recurrenceCountLabel = 'tasks.recurrence.count';
  static const String selectDateHint = 'tasks.recurrence.selectDateHint';
  static const String enterCountHint = 'tasks.recurrence.enterCountHint';

  // Recurrence Day Suffixes
  static const String recurrenceDaySuffix = 'tasks.recurrence.daySuffix';
  static const String recurrenceWeekSuffix = 'tasks.recurrence.weekSuffix';
  static const String recurrenceMonthSuffix = 'tasks.recurrence.monthSuffix';
  static const String recurrenceYearSuffix = 'tasks.recurrence.yearSuffix';
  // Recurrence Summary
  static const String on = 'tasks.recurrence.summary.on';
  static const String starts = 'tasks.recurrence.summary.starts';
  static const String endsOnDate = 'tasks.recurrence.summary.endsOnDate';
  static const String endsAfter = 'tasks.recurrence.summary.endsAfter';
  static const String occurrences = 'tasks.recurrence.summary.occurrences';

  // Helper Method for Reminder Types
  static String getReminderTypeKey(ReminderTime reminderTime) {
    // Get the enum value part after the dot: "ReminderTime.atTime" -> "atTime"
    final reminderTypeValue = reminderTime.toString().split('.').last;

    // Map the enum value to the corresponding translation key constant
    switch (reminderTypeValue) {
      case 'none':
        return reminderNone;
      case 'atTime':
        return reminderAtTime;
      case 'fiveMinutesBefore':
        return reminderFiveMinutesBefore;
      case 'fifteenMinutesBefore':
        return reminderFifteenMinutesBefore;
      case 'oneHourBefore':
        return reminderOneHourBefore;
      case 'oneDayBefore':
        return reminderOneDayBefore;
      default:
        return reminderNone; // Fallback to none as default
    }
  }
}
