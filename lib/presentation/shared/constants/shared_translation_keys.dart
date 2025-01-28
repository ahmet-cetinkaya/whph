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
  static const String unexpectedError = 'shared.errors.unexpected';
  static const String loadingError = 'shared.errors.loading';
  static const String savingError = 'shared.errors.saving';
  static const String deletingError = 'shared.errors.deleting';
  static const String minutes = 'shared.units.minutes';
  static const String days = 'shared.units.days';
  static const String getTagsError = 'shared.errors.get_tags';
  static const String filterByTagsTooltip = 'shared.tooltips.filter_by_tags';

  // Calendar
  static const String weekDayMon = 'shared.calendar.week_days.mon';
  static const String weekDayTue = 'shared.calendar.week_days.tue';
  static const String weekDayWed = 'shared.calendar.week_days.wed';
  static const String weekDayThu = 'shared.calendar.week_days.thu';
  static const String weekDayFri = 'shared.calendar.week_days.fri';
  static const String weekDaySat = 'shared.calendar.week_days.sat';
  static const String weekDaySun = 'shared.calendar.week_days.sun';

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
