import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';

// Mock classes
class MockTaskRepository extends Fake implements ITaskRepository {}

class MockLogger extends Fake implements ILogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

void main() {
  group('TaskRecurrenceService Advanced Tests', () {
    late TaskRecurrenceService service;

    setUp(() {
      service = TaskRecurrenceService(MockLogger(), MockTaskRepository());
    });

    test('Should prioritize RecurrenceConfiguration over legacy RecurrenceType', () {
      final task = Task(
        id: '1',
        title: 'Test',
        createdDate: DateTime(2023, 1, 1),
        // Legacy says Daily
        recurrenceType: RecurrenceType.daily,
        recurrenceInterval: 1,
        // Config says Weekly
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.weekly,
          interval: 1,
        ),
      );

      final currentDate = DateTime(2023, 1, 1); // Sunday
      // Daily would be Jan 2. Weekly (default 1 week) would be Jan 8.
      final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

      expect(nextDate, equals(DateTime(2023, 1, 8)));
    });

    test('Monthly Relative: 2nd Tuesday', () {
      final task = Task(
        id: '1',
        title: 'Meeting',
        createdDate: DateTime(2023, 1, 1),
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          monthlyPatternType: MonthlyPatternType.relativeDay,
          weekOfMonth: 2, // 2nd
          dayOfWeek: 2, // Tuesday
        ),
      );

      // Current: Jan 1, 2023. Next should be Feb 2023, 2nd Tuesday.
      // Feb 1, 2023 is Wednesday.
      // 1st Tuesday is Feb 7.
      // 2nd Tuesday is Feb 14.
      final currentDate = DateTime(2023, 1, 1, 10, 30); // 10:30 AM
      final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

      // Should be Feb 14, 2023 at 10:30 AM
      expect(nextDate, equals(DateTime(2023, 2, 14, 10, 30)));
      expect(nextDate.year, 2023);
      expect(nextDate.month, 2);
      expect(nextDate.day, 14);
      expect(nextDate.hour, 10);
      expect(nextDate.minute, 30);
    });

    test('Monthly Specific: Last Day (31st clamped to 28th)', () {
      final task = Task(
        id: '1',
        title: 'Pay',
        createdDate: DateTime(2023, 1, 31),
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          dayOfMonth: 31,
        ),
      );

      // Current: Jan 31. Next: Feb. Feb 2023 has 28 days.
      final currentDate = DateTime(2023, 1, 31);
      final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

      expect(nextDate.month, 2);
      expect(nextDate.day, 28);
    });

    test('Nth Weekday: Last Friday', () {
      final task = Task(
        id: '1',
        title: 'Last Friday',
        createdDate: DateTime(2023, 1, 1),
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          monthlyPatternType: MonthlyPatternType.relativeDay,
          weekOfMonth: 5, // Last
          dayOfWeek: 5, // Friday
        ),
      );

      // Current: Jan 1. Next: Feb.
      // Feb 2023 ends on Feb 28 (Tuesday).
      // Last Friday of Feb 2023: Feb 24.
      final currentDate = DateTime(2023, 1, 1);
      final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

      expect(nextDate.month, 2);
      expect(nextDate.day, 24);
    });

    group('Hourly Recurrence', () {
      test('should create recurrence every 2 hours', () {
        final task = Task(
          id: '1',
          title: 'Hourly Task',
          createdDate: DateTime(2023, 1, 1, 10, 0),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.hourly,
            interval: 2,
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 10, 0);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, equals(DateTime(2023, 1, 1, 12, 0)));
      });

      test('should handle cross-day boundary (23:00 -> 01:00)', () {
        final task = Task(
          id: '1',
          title: 'Hourly Task',
          createdDate: DateTime(2023, 1, 1, 23, 0),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.hourly,
            interval: 2,
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 23, 0);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, equals(DateTime(2023, 1, 2, 1, 0)));
      });

      test('should respect endDate for hourly recurrence', () {
        final task = Task(
          id: '1',
          title: 'Hourly Task',
          createdDate: DateTime(2023, 1, 1, 10, 0),
          recurrenceConfiguration: RecurrenceConfiguration.test(
            frequency: RecurrenceFrequency.hourly,
            interval: 1,
            endCondition: RecurrenceEndCondition.date,
            endDate: DateTime(2023, 1, 1, 14, 0),
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 13, 0);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, equals(DateTime(2023, 1, 1, 14, 0)));
      });

      test('should respect occurrenceCount for hourly recurrence', () {
        final task = Task(
          id: '1',
          title: 'Hourly Task',
          createdDate: DateTime(2023, 1, 1, 10, 0),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.hourly,
            interval: 1,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 3,
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 10, 0);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, isNotNull);
      });
    });

    group('Minutely Recurrence', () {
      test('should create recurrence every 15 minutes', () {
        final task = Task(
          id: '1',
          title: 'Minutely Task',
          createdDate: DateTime(2023, 1, 1, 10, 0),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.minutely,
            interval: 15,
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 10, 0);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, equals(DateTime(2023, 1, 1, 10, 15)));
      });

      test('should handle hour boundary (:45 -> :15 next hour)', () {
        final task = Task(
          id: '1',
          title: 'Minutely Task',
          createdDate: DateTime(2023, 1, 1, 10, 45),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.minutely,
            interval: 30,
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 10, 45);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, equals(DateTime(2023, 1, 1, 11, 15)));
      });

      test('should respect endDate for minutely recurrence', () {
        final task = Task(
          id: '1',
          title: 'Minutely Task',
          createdDate: DateTime(2023, 1, 1, 10, 0),
          recurrenceConfiguration: RecurrenceConfiguration.test(
            frequency: RecurrenceFrequency.minutely,
            interval: 15,
            endCondition: RecurrenceEndCondition.date,
            endDate: DateTime(2023, 1, 1, 11, 0),
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 10, 45);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, equals(DateTime(2023, 1, 1, 11, 0)));
      });

      test('should respect occurrenceCount for minutely recurrence', () {
        final task = Task(
          id: '1',
          title: 'Minutely Task',
          createdDate: DateTime(2023, 1, 1, 10, 0),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.minutely,
            interval: 15,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 5,
          ),
        );

        final currentDate = DateTime(2023, 1, 1, 10, 0);
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        expect(nextDate, isNotNull);
      });
    });
  });
}
