import 'package:flutter_test/flutter_test.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/utils/task_date_time_normalizer.dart';

void main() {
  group('isAllDay', () {
    test('returns true for date-only DateTime', () {
      expect(TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12)), true);
    });

    test('returns true for explicit midnight DateTime', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 0, 0, 0, 0, 0)),
        true,
      );
    });

    test('returns false when hours are non-zero', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 1, 0, 0, 0, 0)),
        false,
      );
    });

    test('returns false when minutes are non-zero', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 0, 1, 0, 0, 0)),
        false,
      );
    });

    test('returns false when seconds are non-zero', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 0, 0, 1, 0, 0)),
        false,
      );
    });

    test('returns false when milliseconds are non-zero', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 0, 0, 0, 1, 0)),
        false,
      );
    });

    test('returns false when microseconds are non-zero', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 0, 0, 0, 0, 1)),
        false,
      );
    });

    test('returns false for timed DateTime', () {
      expect(
        TaskDateTimeNormalizer.isAllDay(DateTime(2026, 3, 12, 14, 30)),
        false,
      );
    });
  });

  group('normalize', () {
    test('returns null for null input', () {
      expect(TaskDateTimeNormalizer.normalize(null), null);
    });

    test('preserves all-day dates as midnight UTC', () {
      final result = TaskDateTimeNormalizer.normalize(DateTime(2026, 3, 12));
      expect(result, DateTimeHelper.toUtcDateTime(DateTime(2026, 3, 12)));
    });

    test('preserves explicit midnight as all-day', () {
      final result = TaskDateTimeNormalizer.normalize(
        DateTime(2026, 3, 12, 0, 0, 0, 0, 0),
      );
      expect(result, DateTimeHelper.toUtcDateTime(DateTime(2026, 3, 12)));
    });

    test('preserves explicit times in UTC', () {
      final input = DateTime(2026, 3, 12, 14, 30);
      final result = TaskDateTimeNormalizer.normalize(input);
      expect(result, DateTimeHelper.toUtcDateTime(input));
    });

    test('handles all-day with explicit midnight components', () {
      final result = TaskDateTimeNormalizer.normalize(
        DateTime(2026, 3, 12, 0, 0, 0, 0, 0),
      );
      expect(result, isNotNull);
      expect(TaskDateTimeNormalizer.isAllDay(result!), true);
    });

    test('distinguishes all-day from one-millisecond-after-midnight', () {
      final allDayResult = TaskDateTimeNormalizer.normalize(
        DateTime(2026, 3, 12, 0, 0, 0, 0, 0),
      );
      final timedResult = TaskDateTimeNormalizer.normalize(
        DateTime(2026, 3, 12, 0, 0, 0, 1, 0),
      );

      expect(TaskDateTimeNormalizer.isAllDay(allDayResult!), true);
      expect(TaskDateTimeNormalizer.isAllDay(timedResult!), false);
    });

    test('distinguishes all-day from one-microsecond-after-midnight', () {
      final allDayResult = TaskDateTimeNormalizer.normalize(
        DateTime(2026, 3, 12, 0, 0, 0, 0, 0),
      );
      final timedResult = TaskDateTimeNormalizer.normalize(
        DateTime(2026, 3, 12, 0, 0, 0, 0, 1),
      );

      expect(TaskDateTimeNormalizer.isAllDay(allDayResult!), true);
      expect(TaskDateTimeNormalizer.isAllDay(timedResult!), false);
    });
  });
}
