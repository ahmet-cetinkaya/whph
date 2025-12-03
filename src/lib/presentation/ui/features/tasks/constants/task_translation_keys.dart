import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart' as application;

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
  static const String quickTaskTitlePlaceholder = 'tasks.quick_task.title_placeholder';
  static const String quickTaskCreateError = 'tasks.quick_task.create_error';
  static const String quickTaskResetAll = 'tasks.quick_task.reset_all';
  static const String quickTaskLockSettings = 'tasks.quick_task.lock_settings';
  static const String quickTaskLockDescription = 'tasks.quick_task.lock_description';
  static const String taskAddedSuccessfully = 'tasks.quick_task.task_added_successfully';

  // Estimated Time Dialog
  static const String estimatedTimeDescription = 'tasks.estimated_time.description';

  // Priority Selection Dialog
  static const String priorityDescription = 'tasks.priority.description';

  // Quick Task Tooltips
  static const String quickTaskEstimatedTime = 'tasks.quick_task.tooltips.estimated_time';
  static const String quickTaskEstimatedTimeDefault = 'tasks.quick_task.tooltips.estimated_time_default';
  static const String quickTaskEstimatedTimeNotSet = 'tasks.quick_task.tooltips.estimated_time_not_set';
  static const String quickTaskPlannedDate = 'tasks.quick_task.tooltips.planned_date';
  static const String quickTaskPlannedDateNotSet = 'tasks.quick_task.tooltips.planned_date_not_set';
  static const String quickTaskDeadlineDate = 'tasks.quick_task.tooltips.deadline_date';
  static const String quickTaskDeadlineDateNotSet = 'tasks.quick_task.tooltips.deadline_date_not_set';

  // Quick Task Reset Confirmation
  static const String quickTaskResetConfirmTitle = 'tasks.quick_task.reset_confirm.title';
  static const String quickTaskResetConfirmMessage = 'tasks.quick_task.reset_confirm.message';

  // Task Add Button
  static const String addTaskButtonTooltip = 'tasks.add_button.tooltip';

  // Task Card
  static const String taskScheduleTooltip = 'tasks.card.tooltips.schedule';
  static const String taskScheduleToday = 'tasks.card.schedule.today';
  static const String taskScheduleTomorrow = 'tasks.card.schedule.tomorrow';

  // Date Picker Quick Selections
  static const String today = 'tasks.date_picker.quick_selection.today';
  static const String tomorrow = 'tasks.date_picker.quick_selection.tomorrow';
  static const String thisWeekend = 'tasks.date_picker.quick_selection.this_weekend';
  static const String weekend = 'tasks.date_picker.quick_selection.weekend';
  static const String nextWeek = 'tasks.date_picker.quick_selection.next_week';
  static const String nextWeekday = 'tasks.date_picker.quick_selection.next_weekday';
  static const String nextWeekend = 'tasks.date_picker.quick_selection.next_weekend';

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
  static const String plannedDateLabel = 'tasks.details.planned_date.label';
  static const String deadlineDateLabel = 'tasks.details.deadline_date.label';
  static const String descriptionLabel = 'tasks.details.description.label';
  static const String addDescriptionHint = 'tasks.details.description.hint';
  static const String descriptionContext = 'tasks.details.description.context';

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
  static const String showSubTasksTooltip = 'tasks.tooltips.show_sub_tasks';
  static const String setReminderTooltip = 'tasks.tooltips.set_reminder';
  static const String setReminderWithStatusTooltip = 'tasks.tooltips.set_reminder_with_status';
  static const String reminderHelpText = 'tasks.tooltips.reminder_help_text';
  static const String reminderDateRequiredTooltip = 'tasks.tooltips.reminder_date_required';
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

  // Parent Task
  static const String parentTaskLabel = 'tasks.details.parent_task.label';
  static const String parentTaskTooltip = 'tasks.details.parent_task.tooltip';

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
  static const String reminderSectionTitle = 'tasks.reminder.section_title';
  static const String reminderCustom = 'tasks.reminder.custom';
  static const String customReminderTitle = 'tasks.reminder.custom_title';
  static const String reminderBeforeSuffix = 'tasks.reminder.before_suffix';
  static const String minutes = 'shared.time.minutes';
  static const String hours = 'shared.time.hours';
  static const String days = 'shared.time.days';
  static const String weeks = 'shared.time.weeks';

  // Recurrence Types and Labels
  static const String recurrenceLabel = 'tasks.recurrence.label';
  static const String recurrenceNone = 'tasks.recurrence.none';
  static const String recurrenceDaily = 'tasks.recurrence.daily';
  static const String recurrenceWeekly = 'tasks.recurrence.weekly';
  static const String recurrenceDaysOfWeek = 'tasks.recurrence.daysOfWeek';
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
  static const String everyDay = 'tasks.recurrence.summary.everyDay';
  static const String occurrences = 'tasks.recurrence.summary.occurrences';

  // Recurrence End Options
  static const String recurrenceEndsLabel = 'tasks.recurrence.ends.label';
  static const String recurrenceEndsNever = 'tasks.recurrence.ends.never';
  static const String recurrenceEndsOnDate = 'tasks.recurrence.ends.onDate';
  static const String recurrenceEndsAfter = 'tasks.recurrence.ends.after';

  // Validation Messages
  static const String deadlineTimeInvalid = 'tasks.validation.deadline_time_invalid';
  static const String deadlineCannotBeBeforePlanned = 'tasks.validation.deadline_cannot_be_before_planned';

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
      case 'custom':
        return reminderCustom;
      default:
        return reminderNone; // Fallback to none as default
    }
  }

  // Tour translation keys
  static const String tourTaskManagementTitle = 'tasks.tour.task_management.title';
  static const String tourTaskManagementDescription = 'tasks.tour.task_management.description';
  static const String tourAddTasksTitle = 'tasks.tour.add_tasks.title';
  static const String tourAddTasksDescription = 'tasks.tour.add_tasks.description';
  static const String tourYourTasksTitle = 'tasks.tour.your_tasks.title';
  static const String tourYourTasksDescription = 'tasks.tour.your_tasks.description';
  static const String tourFilterSearchTitle = 'tasks.tour.filter_search.title';
  static const String tourFilterSearchDescription = 'tasks.tour.filter_search.description';

  // Marathon tour translation keys
  static const String tourMarathonAppUsageTitle = 'tasks.tour.marathon.app_usage.title';
  static const String tourMarathonAppUsageDescription = 'tasks.tour.marathon.app_usage.description';
  static const String tourMarathonUsageStatisticsTitle = 'tasks.tour.marathon.usage_statistics.title';
  static const String tourMarathonUsageStatisticsDescription = 'tasks.tour.marathon.usage_statistics.description';
  static const String tourMarathonFilterSortTitle = 'tasks.tour.marathon.filter_sort.title';
  static const String tourMarathonFilterSortDescription = 'tasks.tour.marathon.filter_sort.description';
  static const String tourMarathonTrackingSettingsTitle = 'tasks.tour.marathon.tracking_settings.title';
  static const String tourMarathonTrackingSettingsDescription = 'tasks.tour.marathon.tracking_settings.description';
}
