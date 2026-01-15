import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';

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
    // Calculate maxSearchDays based on interval to handle long recurrence periods
    // Ensure at least two full cycles plus a week to find the next occurrence
    final maxSearchDays = (intervalInWeeks ?? 1) * 7 * 2 + 7;

    if (targetWeekdays.isEmpty) {
      throw ArgumentError('targetWeekdays cannot be empty');
    }

    for (int daysFromNow = 1; daysFromNow <= maxSearchDays; daysFromNow++) {
      final candidateDate = startDate.add(Duration(days: daysFromNow));
      final candidateWeekday = candidateDate.weekday;

      if (targetWeekdays.contains(candidateWeekday)) {
        bool isValid = false;
        if (intervalInWeeks != null && intervalInWeeks > 1 && referenceDate != null) {
          final weeksFromStart = (candidateDate.difference(referenceDate).inDays / 7).floor();
          if (weeksFromStart % intervalInWeeks == 0) {
            isValid = true;
          }
        } else {
          isValid = true;
        }

        if (isValid) {
          return candidateDate;
        }
      }
    }

    throw StateError(
      '[${TaskErrorIds.dateHelperMaxSearchDaysExceeded}] '
      'Could not find next weekday occurrence after $maxSearchDays days. '
      'targetWeekdays: $targetWeekdays, intervalInWeeks: $intervalInWeeks, '
      'referenceDate: $referenceDate',
    );
  }

  /// Finds the next occurrence of a weekly schedule with per-day times.
  /// This allows different days of the week to have different scheduled times.
  ///
  /// Example: Monday at 9:00 AM, Tuesday at 10:00 AM, Wednesday at 9:00 AM
  static DateTime findNextWeekdayOccurrenceWithTimes(
    DateTime startDate,
    List<WeeklySchedule> weeklySchedule,
    int? intervalInWeeks,
    DateTime? referenceDate,
  ) {
    // Calculate maxSearchDays based on interval to handle long recurrence periods
    // Ensure at least two full cycles plus a week to find the next occurrence
    final maxSearchDays = (intervalInWeeks ?? 1) * 7 * 2 + 7;

    if (weeklySchedule.isEmpty) {
      throw ArgumentError('weeklySchedule cannot be empty');
    }

    // Extract the valid days from the schedule
    final validDays = weeklySchedule.map((s) => s.dayOfWeek).toList();

    for (int daysFromNow = 1; daysFromNow <= maxSearchDays; daysFromNow++) {
      final candidateDate = startDate.add(Duration(days: daysFromNow));
      final candidateWeekday = candidateDate.weekday;

      if (validDays.contains(candidateWeekday)) {
        bool isValid = false;
        if (intervalInWeeks != null && intervalInWeeks > 1 && referenceDate != null) {
          final weeksFromStart = (candidateDate.difference(referenceDate).inDays / 7).floor();
          if (weeksFromStart % intervalInWeeks == 0) {
            isValid = true;
          }
        } else {
          isValid = true;
        }

        if (isValid) {
          // Find the schedule for this day with validation
          final schedule = weeklySchedule.firstWhere(
            (s) => s.dayOfWeek == candidateWeekday,
          );

          // Validate schedule time values to catch data corruption
          if (schedule.hour < 0 || schedule.hour > 23) {
            throw StateError(
              '[${TaskErrorIds.dateHelperInvalidScheduleHour}] '
              'Invalid hour ${schedule.hour} for weekday $candidateWeekday in weeklySchedule. '
              'This indicates data corruption or invalid configuration.',
            );
          }
          if (schedule.minute < 0 || schedule.minute > 59) {
            throw StateError(
              '[${TaskErrorIds.dateHelperInvalidScheduleMinute}] '
              'Invalid minute ${schedule.minute} for weekday $candidateWeekday in weeklySchedule. '
              'This indicates data corruption or invalid configuration.',
            );
          }

          return DateTime(
            candidateDate.year,
            candidateDate.month,
            candidateDate.day,
            schedule.hour,
            schedule.minute,
          );
        }
      }
    }

    throw StateError(
      '[${TaskErrorIds.dateHelperMaxSearchDaysWithTimesExceeded}] '
      'Could not find next weekday occurrence after $maxSearchDays days. '
      'weeklySchedule: $weeklySchedule, intervalInWeeks: $intervalInWeeks, '
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
