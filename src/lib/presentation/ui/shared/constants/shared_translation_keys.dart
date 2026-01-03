import 'package:whph/core/application/shared/constants/shared_translation_keys.dart' as application;
import 'package:acore/acore.dart' show DateTimePickerTranslationKey;
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/components/markdown_editor/config/markdown_editor_translation_keys.dart';

class SharedTranslationKeys extends application.SharedTranslationKeys {
  static const String saveButton = 'shared.buttons.save';
  static const String savedButton = 'shared.buttons.saved';
  static const String addButton = 'shared.buttons.add';
  static const String cancelButton = 'shared.buttons.cancel';
  static const String clearButton = 'shared.buttons.clear';
  static const String deleteButton = 'shared.buttons.delete';
  static const String closeButton = 'shared.buttons.close';
  static const String doneButton = 'shared.buttons.done';
  static const String confirmButton = 'shared.buttons.confirm';
  static const String backButton = 'shared.buttons.back';
  static const String confirmDeleteMessage = 'shared.messages.confirm_delete';
  static const String noItemsFoundMessage = 'shared.messages.no_items_found';
  static const String untitled = 'shared.untitled'; // Added for sl, tr, uk locales
  static const String requiredValidation = 'shared.validation.required';
  static const String refreshTooltip = 'shared.tooltips.refresh';
  static const String resetTooltip = 'shared.tooltips.reset';

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
  static const String hoursShort = 'shared.units.hours_short';
  static const String days = 'shared.units.days';
  static const String hours = 'shared.units.hours';
  static const String seconds = 'shared.units.seconds';

  // Time not set
  static const String notSetTime = 'shared.time.not_set';

  // Tooltips
  static const String filterByTagsTooltip = 'shared.tooltips.filter_by_tags';
  static const String compareWithPreviousLabel = 'shared.tooltips.compare_with_previous';

  // Calendar
  static const String weekDayMon = 'shared.calendar.week_days.monday';
  static const String weekDayTue = 'shared.calendar.week_days.tuesday';
  static const String weekDayWed = 'shared.calendar.week_days.wednesday';
  static const String weekDayThu = 'shared.calendar.week_days.thursday';
  static const String weekDayFri = 'shared.calendar.week_days.friday';
  static const String weekDaySat = 'shared.calendar.week_days.saturday';
  static const String weekDaySun = 'shared.calendar.week_days.sunday';
  static const String weekDayMonShort = 'shared.calendar.week_days.monday_short';
  static const String weekDayTueShort = 'shared.calendar.week_days.tuesday_short';
  static const String weekDayWedShort = 'shared.calendar.week_days.wednesday_short';
  static const String weekDayThuShort = 'shared.calendar.week_days.thursday_short';
  static const String weekDayFriShort = 'shared.calendar.week_days.friday_short';
  static const String weekDaySatShort = 'shared.calendar.week_days.saturday_short';
  static const String weekDaySunShort = 'shared.calendar.week_days.sunday_short';

  // Time periods
  static const String today = 'shared.time_periods.today';
  static const String thisWeek = 'shared.time_periods.this_week';
  static const String thisMonth = 'shared.time_periods.this_month';
  static const String this3Months = 'shared.time_periods.this_three_months';
  static const String lastWeek = 'shared.time_periods.last_week';
  static const String lastMonth = 'shared.time_periods.last_month';
  static const String nextWeek = 'shared.time_periods.next_week';
  static const String custom = 'shared.time_periods.custom';

  // Date picker
  static const String allDay = 'shared.date_picker.all_day';
  static const String timePickerHourLabel = 'shared.date_picker.time_picker_hour_label';
  static const String timePickerMinuteLabel = 'shared.date_picker.time_picker_minute_label';

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
  static const String totalUsageLabel = 'shared.statistics.total_usage_label';
  static const String averageDailyLabel = 'shared.statistics.average_daily_label';
  static const String peakHourLabel = 'shared.statistics.peak_hour_label';
  static const String selectDateRangeMessage = 'shared.statistics.select_date_range_message';
  static const String selectDateRangeDescription = 'shared.statistics.select_date_range_description';
  static const String loadingMessage = 'shared.messages.loading';

  // Editor
  static const String markdownEditorHint = 'shared.editor.markdown.hint';
  static const String markdownEditorBoldTooltip = 'shared.editor.markdown.tooltips.bold';
  static const String markdownEditorItalicTooltip = 'shared.editor.markdown.tooltips.italic';
  static const String markdownEditorStrikethroughTooltip = 'shared.editor.markdown.tooltips.strikethrough';
  static const String markdownEditorCodeTooltip = 'shared.editor.markdown.tooltips.code';
  static const String markdownEditorLinkTooltip = 'shared.editor.markdown.tooltips.link';
  static const String markdownEditorQuoteTooltip = 'shared.editor.markdown.tooltips.quote';
  static const String markdownEditorBulletedListTooltip = 'shared.editor.markdown.tooltips.bulleted_list';
  static const String markdownEditorNumberedListTooltip = 'shared.editor.markdown.tooltips.numbered_list';
  static const String markdownEditorHorizontalRuleTooltip = 'shared.editor.markdown.tooltips.horizontal_rule';
  static const String markdownEditorEditTooltip = 'shared.editor.markdown.tooltips.edit';
  static const String markdownEditorPreviewTooltip = 'shared.editor.markdown.tooltips.preview';
  static const String markdownEditorImageTooltip = 'shared.editor.markdown.tooltips.image';
  static const String markdownEditorHeadingTooltip = 'shared.editor.markdown.tooltips.heading';
  static const String markdownEditorCheckboxTooltip = 'shared.editor.markdown.tooltips.checkbox';

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
  static const String updateDownloadingMessage = 'shared.update_dialog.downloading';
  static const String updateSuccessMessage = 'shared.update_dialog.success';
  static const String updateFailedMessage = 'shared.update_dialog.failed';

  // Timer
  static const String normalTimer = 'shared.timer.normal';
  static const String pomodoroTimer = 'shared.timer.pomodoro';
  static const String stopwatchTimer = 'shared.timer.stopwatch';

  // Timer - Generic label extracted from habits
  static const String timerLabel = 'shared.timer.label';

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
  static const String enableReorderingTooltip = 'shared.sort.enable_reordering_tooltip';
  static const String disableReorderingTooltip = 'shared.sort.disable_reordering_tooltip';
  static const String sortCriteria = 'shared.sort.criteria';
  static const String sortEnableGrouping = application.SharedTranslationKeys.sortEnableGrouping;
  static const String sortEnableGroupingDescription = application.SharedTranslationKeys.sortEnableGroupingDescription;
  static const String sortAndGroup = application.SharedTranslationKeys.sortAndGroup;

  // Data
  static const String createdDateLabel = 'shared.data.created_date_label';
  static const String modifiedDateLabel = 'shared.data.modified_date_label';
  static const String nameLabel = 'shared.data.name_label';

  // Error Report Translation Keys
  static const String errorReportTemplate = 'shared.errors.report_template';
  static const String errorReportSubject = 'shared.errors.report_subject';

  // Startup Error Translation Keys
  static const String startupErrorTitle = 'shared.startup_error.title';
  static const String startupErrorDescription = 'shared.startup_error.description';
  static const String startupErrorDetailsTitle = 'shared.startup_error.details_title';
  static const String copyErrorButton = 'shared.startup_error.copy_button';
  static const String copiedToClipboard = 'shared.startup_error.copied_to_clipboard';
  static const String reportIssueButton = 'shared.startup_error.report_button';

  static const String change = 'shared.change';

  // Date Picker Translations
  static const String selectedDateMustBeAtOrAfter = 'shared.datepicker.selected_date_must_be_at_or_after';
  static const String selectedDateMustBeAtOrBefore = 'shared.datepicker.selected_date_must_be_at_or_before';
  static const String startDateCannotBeAfterEndDate = 'shared.datepicker.start_date_cannot_be_after_end_date';
  static const String startDateMustBeAtOrAfter = 'shared.datepicker.start_date_must_be_at_or_after';
  static const String endDateMustBeAtOrBefore = 'shared.datepicker.end_date_must_be_at_or_before';
  static const String cannotSelectDateBeforeMinDate = 'shared.datepicker.cannot_select_date_before_min_date';
  static const String cannotSelectDateAfterMaxDate = 'shared.datepicker.cannot_select_date_after_max_date';
  static const String startDateCannotBeBeforeMinDate = 'shared.datepicker.start_date_cannot_be_before_min_date';
  static const String endDateCannotBeAfterMaxDate = 'shared.datepicker.end_date_cannot_be_after_max_date';
  static const String cannotSelectTimeBeforeMinDate = 'shared.datepicker.cannot_select_time_before_min_date';
  static const String cannotSelectTimeAfterMaxDate = 'shared.datepicker.cannot_select_time_after_max_date';
  static const String timeMustBeAtOrAfter = 'shared.datepicker.time_must_be_at_or_after';
  static const String timeMustBeAtOrBefore = 'shared.datepicker.time_must_be_at_or_before';
  static const String selectedDateTimeMustBeAfter = 'shared.datepicker.selected_date_time_must_be_after';
  static const String selectDateTimeTitle = 'shared.datepicker.select_date_time_title';
  static const String selectTimeTitle = 'shared.datepicker.select_time_title';
  static const String selectedTime = 'shared.datepicker.selected_time';
  static const String selectDateTitle = 'shared.datepicker.select_date_title';
  static const String selectDateRangeTitle = 'shared.datepicker.select_date_range_title';
  static const String deadlineCannotBeBeforePlannedDate = 'shared.datepicker.deadline_cannot_be_before_planned_date';

  // Quick Selection Dialog
  static const String quickSelection = 'shared.datepicker.quick_selection';
  static const String quickSelectionTitle = 'shared.datepicker.quick_selection_title';
  static const String refreshSettings = 'shared.datepicker.refresh_settings';
  static const String dateRanges = 'shared.datepicker.date_ranges';
  static const String refreshSettingsLabel = 'shared.datepicker.refresh_settings_label';

  // DateTimePickerField Accessibility
  static const String dateTimeFieldLabel = 'shared.date_time_picker.field_label';
  static const String dateTimeFieldHint = 'shared.date_time_picker.field_hint';
  static const String editButtonLabel = 'shared.date_time_picker.edit_button_label';
  static const String editButtonHint = 'shared.date_time_picker.edit_button_hint';

  static const String date = 'shared.date';

  // Time Logging - Extracted from habits and tasks features to reduce redundancy
  static const String timeLoggingDialogTitle = 'shared.time_logging.dialog_title';
  static const String timeLoggingMode = 'shared.time_logging.mode';
  static const String timeLoggingAddTime = 'shared.time_logging.add_time';
  static const String timeLoggingSetTotal = 'shared.time_logging.set_total';
  static const String timeLoggingDuration = 'shared.time_logging.duration';
  static const String timeLoggingTotalTime = 'shared.time_logging.total_time';
  static const String timeLoggingAddTimeDescription = 'shared.time_logging.add_time_description';
  static const String timeLoggingSetTotalDescription = 'shared.time_logging.set_total_description';
  static const String timeLoggingLogTime = 'shared.time_logging.log_time';
  static const String timeLoggingInvalidInput = 'shared.time_logging.invalid_input';

  // Time Display
  static const String timeDisplayEstimated = 'shared.time_display.estimated';
  static const String timeDisplayEstimatedTimeTooltip = 'shared.time_display.estimated_time_tooltip';
  static const String timeDisplayElapsed = 'shared.time_display.elapsed';
  static const String timeDisplayElapsedTimeTooltip = 'shared.time_display.elapsed_time_tooltip';
  static const String timeDisplayNoTimeLoggedTooltip = 'shared.time_display.no_time_logged_tooltip';

  // Numeric Input
  static const String numericInputDecrementButtonLabel = 'shared.numeric_input.decrement_button_label';
  static const String numericInputIncrementButtonLabel = 'shared.numeric_input.increment_button_label';
  static const String numericInputTextFieldLabel = 'shared.numeric_input.text_field_label';
  static const String numericInputDecrementHint = 'shared.numeric_input.decrement_hint';
  static const String numericInputIncrementHint = 'shared.numeric_input.increment_hint';
  static const String numericInputTextFieldHint = 'shared.numeric_input.text_field_hint';
  static const String numericInputDecrementTooltip = 'shared.numeric_input.decrement_tooltip';
  static const String numericInputIncrementTooltip = 'shared.numeric_input.increment_tooltip';
  static const String numericInputAtMinimumValue = 'shared.numeric_input.at_minimum_value';
  static const String numericInputAtMaximumValue = 'shared.numeric_input.at_maximum_value';

  // Date Time Picker
  static const String dateTimePickerTitle = 'shared.date_time_picker.title';
  static const String dateTimePickerConfirm = 'shared.date_time_picker.confirm';
  static const String dateTimePickerCancel = 'shared.date_time_picker.cancel';
  static const String dateTimePickerSetTime = 'shared.date_time_picker.set_time';
  static const String dateTimePickerSelectedTime = 'shared.date_time_picker.selected_time';
  static const String dateTimePickerSelectTimeTitle = 'shared.date_time_picker.select_time_title';
  static const String dateTimePickerSelectDateTitle = 'shared.date_time_picker.select_date_title';
  static const String dateTimePickerNoDateSelected = 'shared.date_time_picker.no_date_selected';
  static const String dateTimePickerSelectEndDate = 'shared.date_time_picker.select_end_date';
  static const String dateTimePickerNoDatesSelected = 'shared.date_time_picker.no_dates_selected';
  static const String dateTimePickerRefresh = 'shared.date_time_picker.refresh';
  static const String dateTimePickerCannotSelectTimeBeforeMinDate =
      'shared.date_time_picker.cannot_select_time_before_min_date';
  static const String dateTimePickerCannotSelectTimeAfterMaxDate =
      'shared.date_time_picker.cannot_select_time_after_max_date';
  static const String dateTimePickerTimeMustBeAtOrAfter = 'shared.date_time_picker.time_must_be_at_or_after';
  static const String dateTimePickerTimeMustBeAtOrBefore = 'shared.date_time_picker.time_must_be_at_or_before';
  static const String dateTimePickerSelectedDateMustBeAtOrAfter =
      'shared.date_time_picker.selected_date_must_be_at_or_after';
  static const String dateTimePickerSelectedDateMustBeAtOrBefore =
      'shared.date_time_picker.selected_date_must_be_at_or_before';
  static const String dateTimePickerStartDateCannotBeAfterEndDate =
      'shared.date_time_picker.start_date_cannot_be_after_end_date';
  static const String dateTimePickerStartDateMustBeAtOrAfter = 'shared.date_time_picker.start_date_must_be_at_or_after';
  static const String dateTimePickerEndDateMustBeAtOrBefore = 'shared.date_time_picker.end_date_must_be_at_or_before';
  static const String dateTimePickerCannotSelectDateBeforeMinDate =
      'shared.date_time_picker.cannot_select_date_before_min_date';
  static const String dateTimePickerCannotSelectDateAfterMaxDate =
      'shared.date_time_picker.cannot_select_date_after_max_date';
  static const String dateTimePickerStartDateCannotBeBeforeMinDate =
      'shared.date_time_picker.start_date_cannot_be_before_min_date';
  static const String dateTimePickerEndDateCannotBeAfterMaxDate =
      'shared.date_time_picker.end_date_cannot_be_after_max_date';
  static const String dateTimePickerSelectedDateTimeMustBeAfter =
      'shared.date_time_picker.selected_date_time_must_be_after';
  static const String dateTimePickerSelectDateTimeTitle = 'shared.date_time_picker.select_date_time_title';
  static const String dateTimePickerSelectDateRangeTitle = 'shared.date_time_picker.select_date_range_title';
  static const String dateTimePickerRefreshDescription = 'shared.date_time_picker.refresh_description';
  static const String dateTimePickerDateTimeFieldLabel = 'shared.date_time_picker.date_time_field_label';
  static const String dateTimePickerDateTimeFieldHint = 'shared.date_time_picker.date_time_field_hint';
  static const String dateTimePickerEditButtonLabel = 'shared.date_time_picker.edit_button_label';
  static const String dateTimePickerEditButtonHint = 'shared.date_time_picker.edit_button_hint';
  static const String dateTimePickerQuickSelectionToday = 'shared.date_time_picker.quick_selection_today';
  static const String dateTimePickerQuickSelectionTomorrow = 'shared.date_time_picker.quick_selection_tomorrow';
  static const String dateTimePickerQuickSelectionWeekend = 'shared.date_time_picker.quick_selection_weekend';
  static const String dateTimePickerQuickSelectionNextWeek = 'shared.date_time_picker.quick_selection_next_week';
  static const String dateTimePickerQuickSelectionNoDate = 'shared.date_time_picker.quick_selection_no_date';
  static const String dateTimePickerQuickSelectionLastWeek = 'shared.date_time_picker.quick_selection_last_week';
  static const String dateTimePickerQuickSelectionLastMonth = 'shared.date_time_picker.quick_selection_last_month';

  static const String help = "shared.help";
  static const String startTour = "shared.start_tour";
  static const String skipTour = "shared.skip_tour";
  static const String previousButton = "shared.buttons.previous";
  static const String tapToResume = "shared.tap_to_resume";

  // Helper Methods
  static String getWeekDayKey(int weekday) {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError('Invalid weekday: $weekday. Must be between 1 and 7.');
    }
    final day = switch (weekday) {
      1 => 'monday',
      2 => 'tuesday',
      3 => 'wednesday',
      4 => 'thursday',
      5 => 'friday',
      6 => 'saturday',
      7 => 'sunday',
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

  // Helper methods for getting translation keys
  static String getWeekDayNameTranslationKey(String weekDayName, {bool short = false}) {
    final prefix = 'shared.calendar.week_days';
    final suffix = short ? '_short' : '';
    return '$prefix.${weekDayName.toLowerCase()}$suffix';
  }

  static String getWeekDayTranslationKey(int weekDay, {bool short = false}) {
    final weekDayMap = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };

    final weekDayName = weekDayMap[weekDay];
    if (weekDayName == null) return '';

    return getWeekDayNameTranslationKey(weekDayName, short: short);
  }

  /// Maps DateTimePickerTranslationKey to SharedTranslationKeys
  static String mapDateTimePickerKey(DateTimePickerTranslationKey key) {
    switch (key) {
      case DateTimePickerTranslationKey.title:
        return SharedTranslationKeys.dateTimePickerTitle;
      case DateTimePickerTranslationKey.confirm:
        return SharedTranslationKeys.dateTimePickerConfirm;
      case DateTimePickerTranslationKey.cancel:
        return SharedTranslationKeys.dateTimePickerCancel;
      case DateTimePickerTranslationKey.clear:
        return SharedTranslationKeys.clearButton;
      case DateTimePickerTranslationKey.setTime:
        return SharedTranslationKeys.dateTimePickerSetTime;
      case DateTimePickerTranslationKey.selectedTime:
        return SharedTranslationKeys.dateTimePickerSelectedTime;
      case DateTimePickerTranslationKey.selectTimeTitle:
        return SharedTranslationKeys.dateTimePickerSelectTimeTitle;
      case DateTimePickerTranslationKey.selectDateTitle:
        return SharedTranslationKeys.dateTimePickerSelectDateTitle;
      case DateTimePickerTranslationKey.noDateSelected:
        return SharedTranslationKeys.dateTimePickerNoDateSelected;
      case DateTimePickerTranslationKey.selectEndDate:
        return SharedTranslationKeys.dateTimePickerSelectEndDate;
      case DateTimePickerTranslationKey.noDatesSelected:
        return SharedTranslationKeys.dateTimePickerNoDatesSelected;
      case DateTimePickerTranslationKey.refresh:
        return SharedTranslationKeys.dateTimePickerRefresh;
      case DateTimePickerTranslationKey.cannotSelectTimeBeforeMinDate:
        return SharedTranslationKeys.dateTimePickerCannotSelectTimeBeforeMinDate;
      case DateTimePickerTranslationKey.cannotSelectTimeAfterMaxDate:
        return SharedTranslationKeys.dateTimePickerCannotSelectTimeAfterMaxDate;
      case DateTimePickerTranslationKey.timeMustBeAtOrAfter:
        return SharedTranslationKeys.dateTimePickerTimeMustBeAtOrAfter;
      case DateTimePickerTranslationKey.timeMustBeAtOrBefore:
        return SharedTranslationKeys.dateTimePickerTimeMustBeAtOrBefore;
      case DateTimePickerTranslationKey.selectedDateMustBeAtOrAfter:
        return SharedTranslationKeys.dateTimePickerSelectedDateMustBeAtOrAfter;
      case DateTimePickerTranslationKey.selectedDateMustBeAtOrBefore:
        return SharedTranslationKeys.dateTimePickerSelectedDateMustBeAtOrBefore;
      case DateTimePickerTranslationKey.startDateCannotBeAfterEndDate:
        return SharedTranslationKeys.dateTimePickerStartDateCannotBeAfterEndDate;
      case DateTimePickerTranslationKey.startDateMustBeAtOrAfter:
        return SharedTranslationKeys.dateTimePickerStartDateMustBeAtOrAfter;
      case DateTimePickerTranslationKey.endDateMustBeAtOrBefore:
        return SharedTranslationKeys.dateTimePickerEndDateMustBeAtOrBefore;
      case DateTimePickerTranslationKey.cannotSelectDateBeforeMinDate:
        return SharedTranslationKeys.dateTimePickerCannotSelectDateBeforeMinDate;
      case DateTimePickerTranslationKey.cannotSelectDateAfterMaxDate:
        return SharedTranslationKeys.dateTimePickerCannotSelectDateAfterMaxDate;
      case DateTimePickerTranslationKey.startDateCannotBeBeforeMinDate:
        return SharedTranslationKeys.dateTimePickerStartDateCannotBeBeforeMinDate;
      case DateTimePickerTranslationKey.endDateCannotBeAfterMaxDate:
        return SharedTranslationKeys.dateTimePickerEndDateCannotBeAfterMaxDate;
      case DateTimePickerTranslationKey.selectedDateTimeMustBeAfter:
        return SharedTranslationKeys.dateTimePickerSelectedDateTimeMustBeAfter;
      case DateTimePickerTranslationKey.selectDateTimeTitle:
        return SharedTranslationKeys.dateTimePickerSelectDateTimeTitle;
      case DateTimePickerTranslationKey.selectDateRangeTitle:
        return SharedTranslationKeys.dateTimePickerSelectDateRangeTitle;
      // Quick selection translations
      case DateTimePickerTranslationKey.quickSelection:
        return SharedTranslationKeys.quickSelection;
      case DateTimePickerTranslationKey.quickSelectionTitle:
        return SharedTranslationKeys.quickSelectionTitle;
      case DateTimePickerTranslationKey.refreshSettings:
        return SharedTranslationKeys.refreshSettings;
      case DateTimePickerTranslationKey.dateRanges:
        return SharedTranslationKeys.dateRanges;
      case DateTimePickerTranslationKey.refreshSettingsLabel:
        return SharedTranslationKeys.refreshSettingsLabel;
      // DateTimePickerField Accessibility
      case DateTimePickerTranslationKey.dateTimeFieldLabel:
        return SharedTranslationKeys.dateTimePickerDateTimeFieldLabel;
      case DateTimePickerTranslationKey.dateTimeFieldHint:
        return SharedTranslationKeys.dateTimePickerDateTimeFieldHint;
      case DateTimePickerTranslationKey.editButtonLabel:
        return SharedTranslationKeys.dateTimePickerEditButtonLabel;
      case DateTimePickerTranslationKey.editButtonHint:
        return SharedTranslationKeys.dateTimePickerEditButtonHint;
      // Quick Selection translations
      case DateTimePickerTranslationKey.quickSelectionToday:
        return SharedTranslationKeys.dateTimePickerQuickSelectionToday;
      case DateTimePickerTranslationKey.quickSelectionTomorrow:
        return SharedTranslationKeys.dateTimePickerQuickSelectionTomorrow;
      case DateTimePickerTranslationKey.quickSelectionWeekend:
        return SharedTranslationKeys.dateTimePickerQuickSelectionWeekend;
      case DateTimePickerTranslationKey.quickSelectionNextWeek:
        return SharedTranslationKeys.dateTimePickerQuickSelectionNextWeek;
      case DateTimePickerTranslationKey.quickSelectionNoDate:
        return SharedTranslationKeys.dateTimePickerQuickSelectionNoDate;
      case DateTimePickerTranslationKey.quickSelectionLastWeek:
        return SharedTranslationKeys.dateTimePickerQuickSelectionLastWeek;
      case DateTimePickerTranslationKey.quickSelectionLastMonth:
        return SharedTranslationKeys.dateTimePickerQuickSelectionLastMonth;
      // Handle weekday abbreviations dynamically
      case DateTimePickerTranslationKey.weekdayMonShort:
        return getWeekDayTranslationKey(1, short: true);
      case DateTimePickerTranslationKey.weekdayTueShort:
        return getWeekDayTranslationKey(2, short: true);
      case DateTimePickerTranslationKey.weekdayWedShort:
        return getWeekDayTranslationKey(3, short: true);
      case DateTimePickerTranslationKey.weekdayThuShort:
        return getWeekDayTranslationKey(4, short: true);
      case DateTimePickerTranslationKey.weekdayFriShort:
        return getWeekDayTranslationKey(5, short: true);
      case DateTimePickerTranslationKey.weekdaySatShort:
        return getWeekDayTranslationKey(6, short: true);
      case DateTimePickerTranslationKey.weekdaySunShort:
        return getWeekDayTranslationKey(7, short: true);
      default:
        // For any other keys, try to use the key directly
        return 'shared.date_time_picker.${key.name}';
    }
  }

  /// Maps NumericInputTranslationKey to SharedTranslationKeys
  static String mapNumericInputKey(NumericInputTranslationKey key) {
    switch (key) {
      case NumericInputTranslationKey.decrementButtonLabel:
        return SharedTranslationKeys.numericInputDecrementButtonLabel;
      case NumericInputTranslationKey.incrementButtonLabel:
        return SharedTranslationKeys.numericInputIncrementButtonLabel;
      case NumericInputTranslationKey.textFieldLabel:
        return SharedTranslationKeys.numericInputTextFieldLabel;
      case NumericInputTranslationKey.decrementHint:
        return SharedTranslationKeys.numericInputDecrementHint;
      case NumericInputTranslationKey.incrementHint:
        return SharedTranslationKeys.numericInputIncrementHint;
      case NumericInputTranslationKey.textFieldHint:
        return SharedTranslationKeys.numericInputTextFieldHint;
      case NumericInputTranslationKey.decrementTooltip:
        return SharedTranslationKeys.numericInputDecrementTooltip;
      case NumericInputTranslationKey.incrementTooltip:
        return SharedTranslationKeys.numericInputIncrementTooltip;
      case NumericInputTranslationKey.atMinimumValue:
        return SharedTranslationKeys.numericInputAtMinimumValue;
      case NumericInputTranslationKey.atMaximumValue:
        return SharedTranslationKeys.numericInputAtMaximumValue;
    }
  }

  /// Maps markdown editor translation keys using the app's translation service
  static Map<String, String> mapMarkdownTranslations(ITranslationService translationService) {
    return {
      MarkdownEditorTranslationKeys.hintText: translationService.translate(markdownEditorHint),
      MarkdownEditorTranslationKeys.editTooltip: translationService.translate(markdownEditorEditTooltip),
      MarkdownEditorTranslationKeys.previewTooltip: translationService.translate(markdownEditorPreviewTooltip),
      MarkdownEditorTranslationKeys.boldTooltip: translationService.translate(markdownEditorBoldTooltip),
      MarkdownEditorTranslationKeys.italicTooltip: translationService.translate(markdownEditorItalicTooltip),
      MarkdownEditorTranslationKeys.linkTooltip: translationService.translate(markdownEditorLinkTooltip),
      MarkdownEditorTranslationKeys.imageTooltip: translationService.translate(markdownEditorImageTooltip),
      MarkdownEditorTranslationKeys.headingTooltip: translationService.translate(markdownEditorHeadingTooltip),
      MarkdownEditorTranslationKeys.checkboxTooltip: translationService.translate(markdownEditorCheckboxTooltip),
      MarkdownEditorTranslationKeys.codeTooltip: translationService.translate(markdownEditorCodeTooltip),
      MarkdownEditorTranslationKeys.bulletedListTooltip:
          translationService.translate(markdownEditorBulletedListTooltip),
      MarkdownEditorTranslationKeys.numberedListTooltip:
          translationService.translate(markdownEditorNumberedListTooltip),
      MarkdownEditorTranslationKeys.quoteTooltip: translationService.translate(markdownEditorQuoteTooltip),
      MarkdownEditorTranslationKeys.horizontalRuleTooltip:
          translationService.translate(markdownEditorHorizontalRuleTooltip),
      MarkdownEditorTranslationKeys.strikethroughTooltip:
          translationService.translate(markdownEditorStrikethroughTooltip),
    };
  }
}
