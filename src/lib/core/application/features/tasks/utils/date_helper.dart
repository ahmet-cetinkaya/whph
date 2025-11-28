import 'package:whph/core/domain/features/tasks/task.dart';
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

    return startDate.add(const Duration(days: 7));
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
}
