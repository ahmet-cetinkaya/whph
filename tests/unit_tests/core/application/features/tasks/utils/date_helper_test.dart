import 'package:flutter_test/flutter_test.dart';
import 'package:application/features/tasks/utils/date_helper.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
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

      test('should handle large intervals correctly', () {
        // Start near the target week so it's within search range
        final startDate = DateTime(2024, 12, 15); // Sunday, Dec 15
        final targetWeekdays = [1]; // Monday
        const interval = 52; // Every 52 weeks (1 year)
        final referenceDate = DateTime(2024, 1, 1); // Reference from start of year

        final result = DateHelper.findNextWeekdayOccurrence(startDate, targetWeekdays, interval, referenceDate);

        // Should find Monday, Dec 30 (52 weeks from Jan 1)
        expect(result, DateTime(2024, 12, 30));
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

    group('findNextWeekdayOccurrenceWithTimes', () {
      group('Basic Functionality', () {
        test('should find next occurrence with specific times', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
            const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0), // Tuesday 10:00
            const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0), // Wednesday 9:00
          ];

          final baseDate = DateTime(2024, 1, 7, 12, 0); // Sunday, Jan 7, 12:00 PM
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            baseDate,
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 8, 9, 0)); // Monday 9:00 AM
        });

        test('should apply correct time for each day of week', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
            const WeeklySchedule(dayOfWeek: 3, hour: 14, minute: 30), // Wednesday 14:30
            const WeeklySchedule(dayOfWeek: 5, hour: 17, minute: 0), // Friday 17:00
          ];

          // Test from Monday -> should get Wednesday 14:30
          final mondayDate = DateTime(2024, 1, 8, 10, 0); // Monday 10:00
          final result1 = DateHelper.findNextWeekdayOccurrenceWithTimes(
            mondayDate,
            schedule,
            null,
            null,
          );
          expect(result1, DateTime(2024, 1, 10, 14, 30)); // Wednesday 14:30

          // Test from Wednesday -> should get Friday 17:00
          final wednesdayDate = DateTime(2024, 1, 10, 15, 0); // Wednesday 15:00
          final result2 = DateHelper.findNextWeekdayOccurrenceWithTimes(
            wednesdayDate,
            schedule,
            null,
            null,
          );
          expect(result2, DateTime(2024, 1, 12, 17, 0)); // Friday 17:00
        });

        test('should wrap to next week with correct time', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
          ];

          final fridayDate = DateTime(2024, 1, 12, 10, 0); // Friday 10:00
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            fridayDate,
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 15, 9, 0)); // Next Monday 9:00 AM
        });

        test('should handle time at boundary (midnight)', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 0, minute: 0), // Monday 00:00
          ];

          final sundayDate = DateTime(2024, 1, 7, 23, 59); // Sunday 23:59
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            sundayDate,
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 8, 0, 0)); // Monday 00:00
        });

        test('should handle time at boundary (end of day)', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 23, minute: 59), // Monday 23:59
          ];

          final mondayDate = DateTime(2024, 1, 8, 10, 0); // Monday 10:00
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            mondayDate,
            schedule,
            null,
            null,
          );

          // Should find next Monday at 23:59 (a week later)
          expect(result, DateTime(2024, 1, 15, 23, 59));
        });
      });

      group('Interval Pattern', () {
        test('should respect interval of 2 weeks', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0), // Tuesday 10:00
          ];

          final referenceDate = DateTime(2024, 1, 2); // Tuesday Jan 2
          final currentDate = DateTime(2024, 1, 9); // Tuesday Jan 9 (1 week later)

          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            currentDate,
            schedule,
            2, // Every 2 weeks
            referenceDate,
          );

          // Should skip this week and find Tuesday in 2 weeks
          expect(result, DateTime(2024, 1, 16, 10, 0)); // Tuesday Jan 16
        });

        test('should handle interval with same reference date', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
          ];

          final referenceDate = DateTime(2024, 1, 8); // Monday Jan 8
          final currentDate = DateTime(2024, 1, 8); // Same date

          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            currentDate,
            schedule,
            2, // Every 2 weeks
            referenceDate,
          );

          // Should find next occurrence (2 weeks later)
          expect(result, DateTime(2024, 1, 22, 9, 0)); // Monday Jan 22
        });

        test('should handle large interval (every 4 weeks)', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 5, hour: 14, minute: 0), // Friday 14:00
          ];

          final referenceDate = DateTime(2024, 1, 5); // Friday Jan 5
          final currentDate = DateTime(2024, 1, 12); // Friday Jan 12 (1 week later)

          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            currentDate,
            schedule,
            4, // Every 4 weeks
            referenceDate,
          );

          // Should find Friday 4 weeks from reference
          expect(result, DateTime(2024, 2, 2, 14, 0)); // Friday Feb 2
        });
      });

      group('Multiple Days with Different Times', () {
        test('should handle Monday 9AM, Tuesday 10AM, Wednesday 9AM pattern', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0),
            const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0),
            const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0),
          ];

          // Starting from Sunday before Monday
          final startDate = DateTime(2024, 1, 7, 12, 0);
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            startDate,
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 8, 9, 0)); // Monday 9:00
        });

        test('should sequence through days with different times correctly', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
            const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0), // Tue 10:00
            const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0), // Wed 9:00
            const WeeklySchedule(dayOfWeek: 4, hour: 14, minute: 0), // Thu 14:00
            const WeeklySchedule(dayOfWeek: 5, hour: 9, minute: 0), // Fri 9:00
          ];

          // After Monday at 9:00, next should be Tuesday at 10:00
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 8, 9, 30), // Monday 9:30 AM
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 9, 10, 0)); // Tuesday 10:00
        });

        test('should handle weekend with different times', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 6, hour: 10, minute: 0), // Saturday 10:00
            const WeeklySchedule(dayOfWeek: 7, hour: 12, minute: 0), // Sunday 12:00
          ];

          // From Friday, next is Saturday 10:00
          final result1 = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 12, 14, 0), // Friday 14:00
            schedule,
            null,
            null,
          );
          expect(result1, DateTime(2024, 1, 13, 10, 0)); // Saturday 10:00

          // From Saturday 11:00, next is Sunday 12:00
          final result2 = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 13, 11, 0), // Saturday 11:00
            schedule,
            null,
            null,
          );
          expect(result2, DateTime(2024, 1, 14, 12, 0)); // Sunday 12:00
        });
      });

      group('Edge Cases', () {
        test('should throw ArgumentError for empty weeklySchedule', () {
          expect(
            () => DateHelper.findNextWeekdayOccurrenceWithTimes(
              DateTime(2024, 1, 8),
              [],
              null,
              null,
            ),
            throwsArgumentError,
          );
        });

        test('should find next day when current time is before scheduled time', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 15, minute: 0), // Monday 15:00
          ];

          // Monday at 10:00, should find next Monday at 15:00 (next week, not same day)
          // The function finds NEXT occurrence, starting from the next day
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 8, 10, 0), // Monday 10:00
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 15, 15, 0)); // Next Monday at 15:00
        });

        test('should handle consecutive days with same time', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
            const WeeklySchedule(dayOfWeek: 2, hour: 9, minute: 0), // Tue 9:00
            const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0), // Wed 9:00
          ];

          // From Sunday at 8:00, next is Monday 9:00
          final result1 = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 7, 8, 0), // Sunday 8:00
            schedule,
            null,
            null,
          );
          expect(result1, DateTime(2024, 1, 8, 9, 0)); // Monday 9:00

          // From Monday 10:00, next is Tuesday 9:00
          final result2 = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 8, 10, 0), // Monday 10:00
            schedule,
            null,
            null,
          );
          expect(result2, DateTime(2024, 1, 9, 9, 0)); // Tuesday 9:00
        });

        test('should handle all 7 days with different times', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 8, minute: 0), // Mon 8:00
            const WeeklySchedule(dayOfWeek: 2, hour: 9, minute: 0), // Tue 9:00
            const WeeklySchedule(dayOfWeek: 3, hour: 10, minute: 0), // Wed 10:00
            const WeeklySchedule(dayOfWeek: 4, hour: 11, minute: 0), // Thu 11:00
            const WeeklySchedule(dayOfWeek: 5, hour: 12, minute: 0), // Fri 12:00
            const WeeklySchedule(dayOfWeek: 6, hour: 13, minute: 0), // Sat 13:00
            const WeeklySchedule(dayOfWeek: 7, hour: 14, minute: 0), // Sun 14:00
          ];

          // From Sunday at 15:00, next is Monday at 8:00
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 14, 15, 0), // Sunday 15:00
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 15, 8, 0)); // Monday 8:00
        });

        test('should handle month boundary correctly', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
          ];

          // Jan 31, 2024 is Wednesday
          // Next Monday is Feb 5
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 31, 10, 0), // Wednesday Jan 31
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 2, 5, 9, 0)); // Monday Feb 5
        });

        test('should handle year boundary correctly', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
          ];

          // Dec 31, 2023 is Sunday
          // Next Monday is Jan 1, 2024
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2023, 12, 31, 10, 0), // Sunday Dec 31
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 1, 9, 0)); // Monday Jan 1
        });
      });

      group('Real-World Scenarios', () {
        test('should handle work schedule: Mon-Fri 9AM with Wednesday meeting at 2PM', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
            const WeeklySchedule(dayOfWeek: 2, hour: 9, minute: 0), // Tue 9:00
            const WeeklySchedule(dayOfWeek: 3, hour: 14, minute: 0), // Wed 14:00 (meeting)
            const WeeklySchedule(dayOfWeek: 4, hour: 9, minute: 0), // Thu 9:00
            const WeeklySchedule(dayOfWeek: 5, hour: 9, minute: 0), // Fri 9:00
          ];

          // From Tuesday 10:00, next is Wednesday 14:00
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 9, 10, 0), // Tuesday 10:00
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 10, 14, 0)); // Wednesday 14:00
        });

        test('should handle exercise schedule: Mon/Wed/Fri at different times', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 1, hour: 7, minute: 0), // Mon 7:00 AM
            const WeeklySchedule(dayOfWeek: 3, hour: 18, minute: 0), // Wed 6:00 PM
            const WeeklySchedule(dayOfWeek: 5, hour: 7, minute: 0), // Fri 7:00 AM
          ];

          // From Monday at 8:00, next is Wednesday at 18:00
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            DateTime(2024, 1, 8, 8, 0), // Monday 8:00
            schedule,
            null,
            null,
          );

          expect(result, DateTime(2024, 1, 10, 18, 0)); // Wednesday 18:00
        });

        test('should handle biweekly team meeting schedule', () {
          final schedule = [
            const WeeklySchedule(dayOfWeek: 2, hour: 14, minute: 0), // Tuesday 14:00
          ];

          final referenceDate = DateTime(2024, 1, 2); // Tuesday (week 1)
          final currentDate = DateTime(2024, 1, 9); // Tuesday (week 2)

          // Every 2 weeks, so week 2 should be skipped
          final result = DateHelper.findNextWeekdayOccurrenceWithTimes(
            currentDate,
            schedule,
            2, // Every 2 weeks
            referenceDate,
          );

          expect(result, DateTime(2024, 1, 16, 14, 0)); // Tuesday (week 3)
        });
      });
    });

    group('getNthWeekdayOfMonth', () {
      test('should find first Monday of January 2024', () {
        final result = DateHelper.getNthWeekdayOfMonth(2024, 1, DateTime.monday, 1);
        expect(result, DateTime(2024, 1, 1));
      });

      test('should find second Tuesday of February 2024', () {
        final result = DateHelper.getNthWeekdayOfMonth(2024, 2, DateTime.tuesday, 2);
        expect(result, DateTime(2024, 2, 13));
      });

      test('should find third Wednesday of March 2024', () {
        final result = DateHelper.getNthWeekdayOfMonth(2024, 3, DateTime.wednesday, 3);
        expect(result, DateTime(2024, 3, 20));
      });

      test('should handle 5th Friday by falling back to last Friday', () {
        // February 2024 has only 4 Fridays, so 5th should fall back to last (4th)
        final result = DateHelper.getNthWeekdayOfMonth(2024, 2, DateTime.friday, 5);
        expect(result, DateTime(2024, 2, 23)); // 4th Friday (last Friday)
      });

      test('should handle 5th Friday in month with 5 Fridays', () {
        // March 2024 has 5 Fridays
        final result = DateHelper.getNthWeekdayOfMonth(2024, 3, DateTime.friday, 5);
        expect(result, DateTime(2024, 3, 29)); // 5th Friday
      });

      test('should handle leap year February', () {
        final result = DateHelper.getNthWeekdayOfMonth(2024, 2, DateTime.thursday, 5);
        expect(result, DateTime(2024, 2, 29)); // Leap day Thursday
      });

      test('should handle year boundary (December to January)', () {
        final result = DateHelper.getNthWeekdayOfMonth(2024, 12, DateTime.wednesday, 2);
        expect(result, DateTime(2024, 12, 11));
      });
    });

    group('getLastWeekdayOfMonth', () {
      test('should find last Monday of January 2024', () {
        final result = DateHelper.getLastWeekdayOfMonth(2024, 1, DateTime.monday);
        expect(result, DateTime(2024, 1, 29));
      });

      test('should find last Friday of February 2024', () {
        final result = DateHelper.getLastWeekdayOfMonth(2024, 2, DateTime.friday);
        expect(result, DateTime(2024, 2, 23));
      });

      test('should find last Sunday of March 2024', () {
        final result = DateHelper.getLastWeekdayOfMonth(2024, 3, DateTime.sunday);
        expect(result, DateTime(2024, 3, 31));
      });

      test('should handle leap year February', () {
        final result = DateHelper.getLastWeekdayOfMonth(2024, 2, DateTime.thursday);
        expect(result, DateTime(2024, 2, 29)); // Leap day is last Thursday
      });

      test('should find last Wednesday of month with 31 days', () {
        final result = DateHelper.getLastWeekdayOfMonth(2024, 5, DateTime.wednesday);
        expect(result, DateTime(2024, 5, 29));
      });
    });
  });
}
