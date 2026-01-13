import 'package:acore/acore.dart';

class DateHelper {
  static int weekDayToNumber(WeekDays day) {
    switch (day) {
      case WeekDays.monday:
        return 1;
      case WeekDays.tuesday:
        return 2;
      case WeekDays.wednesday:
        return 3;
      case WeekDays.thursday:
        return 4;
      case WeekDays.friday:
        return 5;
      case WeekDays.saturday:
        return 6;
      case WeekDays.sunday:
        return 7;
    }
  }

  static DateTime findNextWeekdayOccurrence(
    DateTime startDate,
    List<int> targetWeekdays,
    int? intervalInWeeks,
    DateTime? referenceDate,
  ) {
    const maxSearchDays = 90;

    if (targetWeekdays.isEmpty) {
      throw ArgumentError('targetWeekdays cannot be empty');
    }

    for (int daysFromNow = 1; daysFromNow <= maxSearchDays; daysFromNow++) {
      final candidateDate = startDate.add(Duration(days: daysFromNow));
      final candidateWeekday = candidateDate.weekday;

      if (targetWeekdays.contains(candidateWeekday)) {
        if (intervalInWeeks != null && intervalInWeeks > 1 && referenceDate != null) {
          final weeksFromStart = (candidateDate.difference(referenceDate).inDays / 7).floor();
          if (weeksFromStart % intervalInWeeks == 0) {
            return candidateDate;
          }
        } else {
          return candidateDate;
        }
      }
    }

    throw StateError(
      'Could not find next weekday occurrence after $maxSearchDays days. '
      'targetWeekdays: $targetWeekdays, intervalInWeeks: $intervalInWeeks, '
      'referenceDate: $referenceDate',
    );
  }

  static DateTime calculateNextMonthDate(DateTime currentDate, int intervalInMonths) {
    int year = currentDate.year;
    int month = currentDate.month + intervalInMonths;

    while (month > 12) {
      month -= 12;
      year++;
    }

    while (month < 1) {
      month += 12;
      year--;
    }

    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final actualDay = currentDate.day > lastDayOfMonth ? lastDayOfMonth : currentDate.day;

    return DateTime(year, month, actualDay, currentDate.hour, currentDate.minute);
  }

  /// Returns the [n]-th occurrence of [weekday] in the given [month] and [year].
  ///
  /// [n] is 1-based: 1 = first occurrence, 2 = second occurrence,
  /// ..., 5 = last occurrence.
  ///
  /// If the requested [n]-th occurrence doesn't exist in the month (e.g., asking for
  /// the 5th Friday in a month that only has 4 Fridays), this method falls back to
  /// the **last** occurrence of that weekday in the month. This behavior ensures
  /// consistent results for edge cases like February or months with limited weekday occurrences.
  ///
  /// **Examples**:
  /// - `getNthWeekdayOfMonth(2024, 2, DateTime.friday, 4)` → 4th Friday of February 2024
  /// - `getNthWeekdayOfMonth(2024, 2, DateTime.friday, 5)` → Last Friday of February 2024
  ///   (falls back from non-existent 5th Friday)
  ///
  /// [year] The year to find the date in
  /// [month] The month (1-12) to search within
  /// [weekday] The weekday to find (DateTime.monday = 1, ..., DateTime.sunday = 7)
  /// [n] The occurrence number (1-5, where 5 means "last")
  ///
  /// Returns a [DateTime] representing the [n]-th (or last) occurrence of [weekday]
  static DateTime getNthWeekdayOfMonth(int year, int month, int weekday, int n) {
    if (n == 5) {
      return getLastWeekdayOfMonth(year, month, weekday);
    }

    final firstDayOfMonth = DateTime(year, month, 1);
    int daysToAdd = (weekday - firstDayOfMonth.weekday + 7) % 7;
    // Advance to the 1st occurrence
    DateTime firstOccurrence = firstDayOfMonth.add(Duration(days: daysToAdd));

    // Add (n-1) weeks
    DateTime candidate = firstOccurrence.add(Duration(days: (n - 1) * 7));

    // If we overshoot month (candidate falls in next month),
    // fall back to last occurrence as documented
    // This handles edge cases like asking for 5th Friday in a month with only 4 Fridays
    if (candidate.month != month) {
      return getLastWeekdayOfMonth(year, month, weekday);
    }

    return candidate;
  }

  static DateTime getLastWeekdayOfMonth(int year, int month, int weekday) {
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    int daysToSubtract = (lastDayOfMonth.weekday - weekday + 7) % 7;
    return lastDayOfMonth.subtract(Duration(days: daysToSubtract));
  }
}
