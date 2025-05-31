import 'package:whph/application/shared/constants/shared_translation_keys.dart' as application;

class SharedTranslationKeys extends application.SharedTranslationKeys {
  static const String saveButton = 'shared.buttons.save';
  static const String savedButton = 'shared.buttons.saved';
  static const String addButton = 'shared.buttons.add';
  static const String cancelButton = 'shared.buttons.cancel';
  static const String deleteButton = 'shared.buttons.delete';
  static const String closeButton = 'shared.buttons.close';
  static const String doneButton = 'shared.buttons.done';
  static const String confirmButton = 'shared.buttons.confirm';
  static const String backButton = 'shared.buttons.back';
  static const String confirmDeleteMessage = 'shared.messages.confirm_delete';
  static const String noItemsFoundMessage = 'shared.messages.no_items_found';
  static const String requiredValidation = 'shared.validation.required';
  static const String refreshTooltip = 'shared.tooltips.refresh';

  // UI-specific errors (inherited from application layer but also defined here for UI components)
  static const String unexpectedError = 'shared.errors.unexpected';
  static const String loadingError = 'shared.errors.loading';
  static const String savingError = 'shared.errors.saving';
  static const String deletingError = 'shared.errors.deleting';
  static const String reportError = 'shared.report_error';

  // File operation errors
  static const String filePickError = 'shared.errors.file_pick';
  static const String fileSaveError = 'shared.errors.file_save';
  static const String fileReadError = 'shared.errors.file_read';
  static const String fileWriteError = 'shared.errors.file_write';
  static const String fileNotFoundError = 'shared.errors.file_not_found';
  static const String storagePermissionError = 'shared.errors.storage_permission';
  static const String storagePermissionDeniedError = 'shared.errors.storage_permission_denied';

  // Units
  static const String minutes = 'shared.units.minutes';
  static const String minutesShort = 'shared.units.minutes_short';
  static const String days = 'shared.units.days';
  static const String hours = 'shared.units.hours';
  static const String seconds = 'shared.units.seconds';

  // Time not set
  static const String notSetTime = 'shared.time.not_set';

  // Tooltips
  static const String filterByTagsTooltip = 'shared.tooltips.filter_by_tags';
  static const String compareWithPreviousLabel = 'shared.tooltips.compare_with_previous';

  // Calendar
  static const String weekDayMon = 'shared.calendar.week_days.mon';
  static const String weekDayTue = 'shared.calendar.week_days.tue';
  static const String weekDayWed = 'shared.calendar.week_days.wed';
  static const String weekDayThu = 'shared.calendar.week_days.thu';
  static const String weekDayFri = 'shared.calendar.week_days.fri';
  static const String weekDaySat = 'shared.calendar.week_days.sat';
  static const String weekDaySun = 'shared.calendar.week_days.sun';

  // Time periods
  static const String today = 'shared.time_periods.today';
  static const String thisWeek = 'shared.time_periods.this_week';
  static const String thisMonth = 'shared.time_periods.this_month';
  static const String this3Months = 'shared.time_periods.this_three_months';
  static const String lastWeek = 'shared.time_periods.last_week';
  static const String lastMonth = 'shared.time_periods.last_month';
  static const String last3Months = 'shared.time_periods.last_three_months';
  static const String custom = 'shared.time_periods.custom';

  // Days of week
  static const String monday = 'shared.days.monday';
  static const String tuesday = 'shared.days.tuesday';
  static const String wednesday = 'shared.days.wednesday';
  static const String thursday = 'shared.days.thursday';
  static const String friday = 'shared.days.friday';
  static const String saturday = 'shared.days.saturday';
  static const String sunday = 'shared.days.sunday';

  // Days of week (short)
  static const String mondayShort = 'shared.days.monday_short';
  static const String tuesdayShort = 'shared.days.tuesday_short';
  static const String wednesdayShort = 'shared.days.wednesday_short';
  static const String thursdayShort = 'shared.days.thursday_short';
  static const String fridayShort = 'shared.days.friday_short';
  static const String saturdayShort = 'shared.days.saturday_short';
  static const String sundayShort = 'shared.days.sunday_short';

  // Statistics
  static const String dailyUsage = 'shared.statistics.daily_usage.title';
  static const String dailyUsageDescription = 'shared.statistics.daily_usage.description';
  static const String hourlyUsage = 'shared.statistics.hourly_usage.title';
  static const String hourlyUsageDescription = 'shared.statistics.hourly_usage.description';

  // Editor
  static const String markdownEditorHint = 'shared.editor.markdown.hint';

  // Color Picker
  static const String colorPickerTitle = 'shared.color_picker.title';
  static const String colorPickerPaletteTab = 'shared.color_picker.tabs.palette';
  static const String colorPickerCustomTab = 'shared.color_picker.tabs.custom';
  static const String selectColorTitle = 'shared.color_picker.select_color_title';
  static const String confirmSelection = 'shared.color_picker.confirm_selection';

  // Date Filter
  static const String dateRangeTitle = 'shared.date_filter.title';
  static const String dateFilterTooltip = 'shared.date_filter.tooltips.filter';
  static const String clearDateFilterTooltip = 'shared.date_filter.tooltips.clear';

  // Search
  static const String searchTitle = 'shared.filters.search';

  // Load More
  static const String loadMoreButton = 'shared.buttons.load_more';

  // Regex Help
  static const String regexHelpTitle = 'shared.regex_help.title';
  static const String regexHelpTips = 'shared.regex_help.tips_title';
  static const String regexHelpTipAny = 'shared.regex_help.tips.any_chars';
  static const String regexHelpTipStart = 'shared.regex_help.tips.start';
  static const String regexHelpTipEnd = 'shared.regex_help.tips.end';
  static const String regexHelpTipOr = 'shared.regex_help.tips.or';
  static const String regexHelpTipDot = 'shared.regex_help.tips.dot';

  static const String regexHelpExamplesChrome = 'shared.regex_help.examples.chrome';
  static const String regexHelpExamplesVscode = 'shared.regex_help.examples.vscode';
  static const String regexHelpExamplesExactChrome = 'shared.regex_help.examples.exact_chrome';
  static const String regexHelpExamplesChat = 'shared.regex_help.examples.chat';
  static const String regexHelpExamplesPdf = 'shared.regex_help.examples.pdf';

  // Search Filter
  static const String searchPlaceholder = 'shared.search.placeholder';
  static const String searchTooltip = 'shared.search.tooltip';

  // Navigation
  static const String navToday = 'shared.nav.items.today';
  static const String navTasks = 'shared.nav.items.tasks';
  static const String navHabits = 'shared.nav.items.habits';
  static const String navNotes = 'shared.nav.items.notes';
  static const String navAppUsages = 'shared.nav.items.app_usages';
  static const String navTags = 'shared.nav.items.tags';
  static const String navSettings = 'shared.nav.items.settings';
  static const String navMore = 'shared.nav.items.more';

  // Update Dialog
  static const String updateAvailableTitle = 'shared.update_dialog.title';
  static const String updateAvailableMessage = 'shared.update_dialog.message';
  static const String updateQuestionMessage = 'shared.update_dialog.question';
  static const String updateLaterButton = 'shared.update_dialog.buttons.later';
  static const String updateDownloadPageButton = 'shared.update_dialog.buttons.download_page';
  static const String updateNowButton = 'shared.update_dialog.buttons.update_now';
  static const String updateFailedMessage = 'shared.update_dialog.failed';

  // Help
  static const String helpTooltip = 'shared.help.tooltip';

  // Sections
  static const String specialFiltersLabel = 'shared.sections.special_filters';
  static const String tagsLabel = 'shared.sections.tags';
  static const String statisticsLabel = 'shared.sections.statistics';

  static const String noneOption = 'shared.none_option';
  static const String dateFormatHint = 'shared.date_format.hint';
  static const String saveListOptions = 'shared.save_list_options';

  static const String sortCustomTitle = 'shared.sort.custom_order.title';
  static const String sortCustomDescription = 'shared.sort.custom_order.description';
  static const String sortResetToDefault = 'shared.sort.reset_to_default';
  static const String sortAscending = 'shared.sort.ascending';
  static const String sortDescending = 'shared.sort.descending';
  static const String sortRemoveCriteria = 'shared.sort.remove_criteria';
  static const String sort = 'shared.sort.sort';

  // Data
  static const String createdDateLabel = 'shared.data.created_date_label';
  static const String modifiedDateLabel = 'shared.data.modified_date_label';
  static const String nameLabel = 'shared.data.name_label';

  // Error Report Translation Keys
  static const String errorReportTemplate = 'shared.errors.report_template';
  static const String errorReportSubject = 'shared.errors.report_subject';

  static const String change = 'shared.change';

  // Helper Methods
  static String getWeekDayKey(int weekday) {
    final day = switch (weekday) {
      1 => 'mon',
      2 => 'tue',
      3 => 'wed',
      4 => 'thu',
      5 => 'fri',
      6 => 'sat',
      7 => 'sun',
      _ => throw Exception('Invalid weekday'),
    };
    return 'shared.calendar.week_days.$day';
  }

  // Months
  static String getMonthKey(int month) {
    final monthName = switch (month) {
      1 => 'jan',
      2 => 'feb',
      3 => 'mar',
      4 => 'apr',
      5 => 'may',
      6 => 'jun',
      7 => 'jul',
      8 => 'aug',
      9 => 'sep',
      10 => 'oct',
      11 => 'nov',
      12 => 'dec',
      _ => throw Exception('Invalid month'),
    };
    return 'shared.calendar.months.$monthName';
  }

  static String getShortMonthKey(int month) {
    final monthName = switch (month) {
      1 => 'jan_short',
      2 => 'feb_short',
      3 => 'mar_short',
      4 => 'apr_short',
      5 => 'may_short',
      6 => 'jun_short',
      7 => 'jul_short',
      8 => 'aug_short',
      9 => 'sep_short',
      10 => 'oct_short',
      11 => 'nov_short',
      12 => 'dec_short',
      _ => throw Exception('Invalid month'),
    };
    return 'shared.calendar.months.$monthName';
  }
}
