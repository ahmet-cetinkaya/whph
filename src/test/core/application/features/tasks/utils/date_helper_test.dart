import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/utils/date_helper.dart';
import 'package:acore/acore.dart';

void main() {
  group('DateHelper Tests', () {
    group('weekDayToNumber', () {
      test('should convert WeekDays to correct numbers', () {
        expect(DateHelper.weekDayToNumber(WeekDays.monday), 1);
        expect(DateHelper.weekDayToNumber(WeekDays.tuesday), 2);
        expect(DateHelper.weekDayToNumber(WeekDays.wednesday), 3);
        expect(DateHelper.weekDayToNumber(WeekDays.thursday), 4);
        expect(DateHelper.weekDayToNumber(WeekDays.friday), 5);
        expect(DateHelper.weekDayToNumber(WeekDays.saturday), 6);
        expect(DateHelper.weekDayToNumber(WeekDays.sunday), 7);
      });
    });

    group('findNextWeekdayOccurrence', () {
      test('should find next occurrence of specified weekday', () {
        final startDate = DateTime(2024, 1, 15); // Monday
        final targetWeekdays = [3]; // Wednesday

        final result = DateHelper.findNextWeekdayOccurrence(startDate, targetWeekdays, null, null);

        expect(result.weekday, 3); // Wednesday
        expect(result.day, 17); // January 17th
      });

      test('should find next occurrence from list of weekdays', () {
        final startDate = DateTime(2024, 1, 15); // Monday
        final targetWeekdays = [5, 6, 7]; // Friday, Saturday, Sunday

        final result = DateHelper.findNextWeekdayOccurrence(startDate, targetWeekdays, null, null);

        expect(result.weekday, 5); // Friday (first in list)
        expect(result.day, 19); // January 19th
      });

      test('should handle interval pattern correctly', () {
        final startDate = DateTime(2024, 1, 2); // Tuesday
        final targetWeekdays = [2]; // Tuesday
        final referenceDate = DateTime(2024, 1, 2); // Same as start
        const interval = 2; // Every 2 weeks

        final result = DateHelper.findNextWeekdayOccurrence(startDate, targetWeekdays, interval, referenceDate);

        expect(result.weekday, 2); // Tuesday
        expect(result.day, 16); // January 16th (2 weeks later)
      });

      test('should handle edge case where no match is found within bounds', () {
        final startDate = DateTime(2024, 1, 1); // Monday
        final targetWeekdays = [1]; // Monday
        const interval = 52; // Every 52 weeks (1 year)
        final referenceDate = DateTime(2024, 1, 1);

        final result = DateHelper.findNextWeekdayOccurrence(startDate, targetWeekdays, interval, referenceDate);

        // Should fallback to simple interval calculation
        expect(result, DateTime(2024, 1, 8)); // Monday + 7 days * 1 (since interval is too large to find match)
      });
    });

    group('calculateNextMonthDate', () {
      test('should handle simple month addition', () {
        final currentDate = DateTime(2024, 1, 15);

        final result = DateHelper.calculateNextMonthDate(currentDate, 1);

        expect(result.year, 2024);
        expect(result.month, 2);
        expect(result.day, 15);
      });

      test('should handle year overflow', () {
        final currentDate = DateTime(2024, 12, 15);

        final result = DateHelper.calculateNextMonthDate(currentDate, 1);

        expect(result.year, 2025);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('should handle multi-month addition', () {
        final currentDate = DateTime(2024, 1, 15);

        final result = DateHelper.calculateNextMonthDate(currentDate, 3);

        expect(result.year, 2024);
        expect(result.month, 4);
        expect(result.day, 15);
      });

      test('should handle multi-year overflow', () {
        final currentDate = DateTime(2024, 1, 15);

        final result = DateHelper.calculateNextMonthDate(currentDate, 15);

        expect(result.year, 2025);
        expect(result.month, 4);
        expect(result.day, 15);
      });

      test('should handle day adjustment for shorter months', () {
        final currentDate = DateTime(2024, 1, 31); // January 31st

        final result = DateHelper.calculateNextMonthDate(currentDate, 1);

        expect(result.year, 2024);
        expect(result.month, 2);
        expect(result.day, 29); // February 2024 has 29 days (leap year)
      });

      test('should handle non-leap year February', () {
        final currentDate = DateTime(2023, 1, 31); // January 31st, 2023 (not leap year)

        final result = DateHelper.calculateNextMonthDate(currentDate, 1);

        expect(result.year, 2023);
        expect(result.month, 2);
        expect(result.day, 28); // February 2023 has 28 days
      });

      test('should preserve time components', () {
        final currentDate = DateTime(2024, 1, 15, 14, 30);

        final result = DateHelper.calculateNextMonthDate(currentDate, 1);

        expect(result.year, 2024);
        expect(result.month, 2);
        expect(result.day, 15);
        expect(result.hour, 14);
        expect(result.minute, 30);
      });
    });
  });
}
