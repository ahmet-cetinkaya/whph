class SharedTranslationKeys {
  static const String saveButton = 'shared.buttons.save';
  static const String savedButton = 'shared.buttons.saved';
  static const String addButton = 'shared.buttons.add';
  static const String cancelButton = 'shared.buttons.cancel';
  static const String deleteButton = 'shared.buttons.delete';
  static const String closeButton = 'shared.buttons.close';
  static const String confirmDeleteMessage = 'shared.messages.confirm_delete';
  static const String noItemsFoundMessage = 'shared.messages.no_items_found';
  static const String requiredValidation = 'shared.validation.required';

  // Keep only generic errors
  static const String unexpectedError = 'shared.errors.unexpected';
  static const String loadingError = 'shared.errors.loading';
  static const String savingError = 'shared.errors.saving';
  static const String deletingError = 'shared.errors.deleting';

  static const String minutes = 'shared.units.minutes';
  static const String days = 'shared.units.days';
  static const String filterByTagsTooltip = 'shared.tooltips.filter_by_tags';

  // Calendar
  static const String weekDayMon = 'shared.calendar.week_days.mon';
  static const String weekDayTue = 'shared.calendar.week_days.tue';
  static const String weekDayWed = 'shared.calendar.week_days.wed';
  static const String weekDayThu = 'shared.calendar.week_days.thu';
  static const String weekDayFri = 'shared.calendar.week_days.fri';
  static const String weekDaySat = 'shared.calendar.week_days.sat';
  static const String weekDaySun = 'shared.calendar.week_days.sun';

  // Editor
  static const String markdownEditorHint = 'shared.editor.markdown.hint';

  // Color Picker
  static const String colorPickerTitle = 'shared.color_picker.title';
  static const String colorPickerPaletteTab = 'shared.color_picker.tabs.palette';
  static const String colorPickerCustomTab = 'shared.color_picker.tabs.custom';

  // Date Filter
  static const String dateRangeTitle = 'shared.date_filter.title';
  static const String dateFilterTooltip = 'shared.date_filter.tooltips.filter';
  static const String clearDateFilterTooltip = 'shared.date_filter.tooltips.clear';

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
  static const String navAppUsages = 'shared.nav.items.app_usages';
  static const String navTags = 'shared.nav.items.tags';
  static const String navSettings = 'shared.nav.items.settings';
  static const String navBuyMeCoffee = 'shared.nav.items.buy_me_coffee';

  // Update Dialog
  static const String updateAvailableTitle = 'shared.update_dialog.title';
  static const String updateAvailableMessage = 'shared.update_dialog.message';
  static const String updateQuestionMessage = 'shared.update_dialog.question';
  static const String updateLaterButton = 'shared.update_dialog.buttons.later';
  static const String updateDownloadPageButton = 'shared.update_dialog.buttons.download_page';
  static const String updateNowButton = 'shared.update_dialog.buttons.update_now';
  static const String updateFailedMessage = 'shared.update_dialog.failed';

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
