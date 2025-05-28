import 'package:whph/application/features/habits/constants/habit_translation_keys.dart' as application;

class HabitTranslationKeys extends application.HabitTranslationKeys {
  static const String newHabit = 'habits.new_habit';
  static const String loadingRecordsError = 'habits.errors.loading_records';
  static const String creatingRecordError = 'habits.errors.creating_record';
  static const String deletingRecordError = 'habits.errors.deleting_record';
  static const String deleteConfirmTitle = 'habits.delete.confirm_title';
  static const String deleteConfirmMessage = 'habits.delete.confirm_message';
  static const String deletingError = 'habits.errors.deleting';

  // Goals
  static const String goal = 'habits.goals.goal';
  static const String targetFrequency = 'habits.goals.target_frequency';
  static const String periodDays = 'habits.goals.period_days';
  static const String enableGoals = 'habits.goals.enable';
  static const String goalFormat = 'habits.goals.goal_format';
  static const String goalSettings = 'habits.goals.settings';
  static const String currentGoal = 'habits.goals.current_goal';

  // Details
  static const String descriptionLabel = 'habits.details.description';
  static const String tagsLabel = 'habits.details.tags';
  static const String tagsHint = 'habits.details.tags_hint';
  static const String estimatedTimeLabel = 'habits.details.estimated_time';
  static const String estimatedTimeNotSet = 'habits.details.estimated_time_not_set';
  static const String recordsLabel = 'habits.details.records';
  static const String statisticsLabel = 'habits.details.statistics_label';
  static const String createRecordTooltip = 'habits.details.create_record_tooltip';
  static const String removeRecordTooltip = 'habits.details.remove_record_tooltip';

  // Errors
  static const String loadingDetailsError = 'habits.errors.loading_details';
  static const String savingDetailsError = 'habits.errors.saving_details';
  static const String loadingTagsError = 'habits.errors.loading_tags';
  static const String addingTagError = 'habits.errors.adding_tag';
  static const String removingTagError = 'habits.errors.removing_tag';
  static const String loadingHabitError = 'habits.errors.loading_habit';
  static const String savingHabitError = 'habits.errors.saving_habit';
  static const String loadingHabitsError = 'habits.errors.loading_habits';

  static const String weekDays = 'habits.calendar.week_days';

  // Calendar
  static const String weekDayMon = 'habits.calendar.week_days.mon';
  static const String weekDayTue = 'habits.calendar.week_days.tue';
  static const String weekDayWed = 'habits.calendar.week_days.wed';
  static const String weekDayThu = 'habits.calendar.week_days.thu';
  static const String weekDayFri = 'habits.calendar.week_days.fri';
  static const String weekDaySat = 'habits.calendar.week_days.sat';
  static const String weekDaySun = 'habits.calendar.week_days.sun';

  // Statistics
  static const String overall = 'habits.details.statistics.overall';
  static const String monthly = 'habits.details.statistics.monthly';
  static const String yearly = 'habits.details.statistics.yearly';
  static const String records = 'habits.details.statistics.records';
  static const String scoreTrends = 'habits.details.statistics.score_trends';
  static const String topStreaks = 'habits.details.statistics.top_streaks';
  static const String archivedOn = 'habits.details.statistics.archived_on';
  static const String statisticsFrom = 'habits.details.statistics.from';
  static const String statisticsTo = 'habits.details.statistics.to';
  static const String statisticsArchivedNote = 'habits.details.statistics.archived_note';
  static const String statisticsArchivedWarning = 'habits.details.statistics.archived_warning';
  static const String archivedStatus = 'habits.details.archived_status';

  // Tag Section
  static const String selectTagsTooltip = 'habits.tags.select_tooltip';
  static const String addTagTooltip = 'habits.tags.add_tooltip';

  // List
  static const String noHabitsFound = 'habits.list.no_habits_found';
  static const String allHabitsDone = 'habits.list.all_habits_done';

  // Help Dialog
  static const String helpTitle = 'habits.details.help.title';
  static const String helpDescription = 'habits.details.help.description';
  static const String detailsHelpTitle = 'habits.details.help.title';
  static const String detailsHelpContent = 'habits.details.help.content';
  static const String overviewHelpTitle = 'habits.overview.help.title';
  static const String overviewHelpContent = 'habits.overview.help.content';

  // Overview Page
  static const String pageTitle = 'habits.overview.title';
  static const String filterByTagsTooltip = 'habits.overview.filter_by_tags_tooltip';

  static const String editNameTooltip = 'habits.tooltips.edit_name';

  static const String addHabit = 'habits.tooltips.add_habit';

  // Notifications
  static const String notificationReminderTitle = 'habits.notifications.reminder_title';
  static const String notificationReminderMessage = 'habits.notifications.reminder_message';

  // Reminders
  static const String enableReminders = 'habits.reminders.enable';
  static const String selectDaysWarning = 'habits.reminders.select_days_warning';
  static const String reminderSettings = 'habits.reminder.reminderSettings';
  static const String reminderTime = 'habits.reminder.reminderTime';
  static const String reminderDays = 'habits.reminder.reminderDays';
  static const String noReminder = 'habits.reminder.noReminder';
  static const String everyDay = 'habits.reminder.everyDay';

  // Archive
  static const String showArchived = 'habits.archive.show_archived';
  static const String hideArchived = 'habits.archive.hide_archived';
  static const String archiveHabit = 'habits.archive.archive';
  static const String archivedDateLabel = 'habits.archive.archived_date';
  static const String unarchiveHabit = 'habits.archive.unarchive';
  static const String archiveHabitConfirm = 'habits.archive.archive_confirm';
  static const String unarchiveHabitConfirm = 'habits.archive.unarchive_confirm';
  static const String archiveHabitTooltip = 'habits.archive.archive_tooltip';
  static const String unarchiveHabitTooltip = 'habits.archive.unarchive_tooltip';
  static const String errorLoadingArchiveStatus = 'habits.errors.loading_archive_status';
  static const String errorTogglingArchive = 'habits.errors.toggling_archive';
}
