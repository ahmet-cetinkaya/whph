import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';

// Fake repository for testing
class FakeTaskRepository extends Fake implements ITaskRepository {}

// Test logger that discards all log messages
class TestLogger implements ILogger {
  const TestLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

void main() {
  group('TaskRecurrenceService Tests', () {
    late TaskRecurrenceService service;

    setUp(() {
      service = TaskRecurrenceService(TestLogger(), FakeTaskRepository());
    });

    group('Recurrence Detection', () {
      test('isRecurring should return true for recurring tasks', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Recurring Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
        );

        // Act & Assert
        expect(service.isRecurring(task), isTrue);
      });

      test('isRecurring should return false for non-recurring tasks', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'One-time Task',
          completedAt: null,
          recurrenceType: RecurrenceType.none,
        );

        // Act & Assert
        expect(service.isRecurring(task), isFalse);
      });
    });

    group('Next Instance Creation Validation', () {
      test('canCreateNextInstance should return false when end date is reached', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Ending Recurring Task',
          completedAt: null,
          plannedDate: DateTime(2024, 1, 15),
          recurrenceType: RecurrenceType.daily,
          recurrenceEndDate: DateTime(2024, 1, 10), // Already passed
        );

        // Act & Assert
        expect(service.canCreateNextInstance(task), isFalse);
      });

      test('canCreateNextInstance should return false when recurrence count is zero', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime(2024, 1, 15),
          recurrenceType: RecurrenceType.daily,
          recurrenceCount: 0, // No more occurrences
        );

        // Act & Assert
        expect(service.canCreateNextInstance(task), isFalse);
      });

      test('canCreateNextInstance should return true for unlimited recurring task', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Unlimited Recurring Task',
          completedAt: null,
          plannedDate: DateTime(2024, 1, 15),
          recurrenceType: RecurrenceType.daily,
          // No end date or count limit
        );

        // Act & Assert
        expect(service.canCreateNextInstance(task), isTrue);
      });
    });

    group('Recurrence Days Parsing', () {
      test('getRecurrenceDays should parse days string correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,wednesday,friday',
        );

        // Act
        final days = service.getRecurrenceDays(task);

        // Assert
        expect(days, isNotNull);
        expect(days!.length, 3);
        expect(days, contains(WeekDays.monday));
        expect(days, contains(WeekDays.wednesday));
        expect(days, contains(WeekDays.friday));
      });

      test('getRecurrenceDays should return null for empty string', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Daily Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceDaysString: '',
        );

        // Act
        final days = service.getRecurrenceDays(task);

        // Assert
        expect(days, isNull);
      });

      test('getRecurrenceDays should return null for null string', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Daily Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceDaysString: null,
        );

        // Act
        final days = service.getRecurrenceDays(task);

        // Assert
        expect(days, isNull);
      });
    });

    group('Next Recurrence Date Calculation', () {
      test('calculateNextRecurrenceDate should handle daily recurrence correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Daily Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 2, // Every 2 days
        );

        final currentDate = DateTime(2024, 1, 15);

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 17); // 2 days later
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle weekly recurrence correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Weekly Task',
          completedAt: null,
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 22); // Next Monday (7 days later)
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle weekly recurrence with interval', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Biweekly Task',
          completedAt: null,
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 2, // Every 2 weeks
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 29); // Next Monday in 2 weeks
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence with specific days', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,wednesday,friday',
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 17); // Next Wednesday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence wrapping to next week', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,wednesday,friday',
        );

        final currentDate = DateTime(2024, 1, 17); // Wednesday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 19); // Next Friday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence with interval', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime(2024, 1, 2).toUtc(), // Set reference date to match current date
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'tuesday',
          recurrenceInterval: 2, // Every 2 weeks
        );

        final currentDate = DateTime(2024, 1, 2); // Tuesday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 16); // Next Tuesday in 2 weeks
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence with all days selected', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,tuesday,wednesday,thursday,friday,saturday,sunday',
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 16); // Next day (Tuesday)
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle monthly recurrence correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Monthly Task',
          completedAt: null,
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 15);

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate.year, 2024);
        expect(nextDate.month, 2);
        expect(nextDate.day, 15);
      });

      test('calculateNextRecurrenceDate should handle monthly recurrence with day adjustment', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Monthly Task',
          completedAt: null,
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 31); // January 31st

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate.year, 2024);
        expect(nextDate.month, 2);
        expect(nextDate.day, 29); // February only has 29 days in 2024 (leap year)
      });

      test('calculateNextRecurrenceDate should handle yearly recurrence correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Yearly Task',
          completedAt: null,
          recurrenceType: RecurrenceType.yearly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 15);

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate.year, 2025);
        expect(nextDate.month, 1);
        expect(nextDate.day, 15);
      });

      test('calculateNextRecurrenceDate should handle yearly recurrence with interval', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Biennial Task',
          completedAt: null,
          recurrenceType: RecurrenceType.yearly,
          recurrenceInterval: 2, // Every 2 years
        );

        final currentDate = DateTime(2024, 1, 15);

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate.year, 2026);
        expect(nextDate.month, 1);
        expect(nextDate.day, 15);
      });

      test('calculateNextRecurrenceDate should return same date for none recurrence type', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Non-recurring Task',
          completedAt: null,
          recurrenceType: RecurrenceType.none,
        );

        final currentDate = DateTime(2024, 1, 15);

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate, currentDate);
      });
    });

    group('Edge Cases and Backward Compatibility', () {
      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence without specified days', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          // No recurrenceDaysString specified
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - Should fallback to simple weekly recurrence
        final expectedDate = DateTime(2024, 1, 22); // Next Monday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence with empty days string', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: '', // Empty string
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - Should fallback to simple weekly recurrence
        final expectedDate = DateTime(2024, 1, 22); // Next Monday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence at week boundary', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,tuesday',
        );

        final currentDate = DateTime(2024, 1, 28); // Sunday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - Should wrap to next week Monday
        final expectedDate = DateTime(2024, 1, 29); // Next Monday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle weekly recurrence across month boundaries', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Weekly Task',
          completedAt: null,
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 31); // January 31st (Thursday)

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 2, 7); // February 7th (Thursday)
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle daysOfWeek recurrence across year boundaries', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Days of Week Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'wednesday',
        );

        final currentDate = DateTime(2023, 12, 27); // December 27th (Wednesday)

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - Should go to next Wednesday in January
        final expectedDate = DateTime(2024, 1, 3); // January 3rd (Wednesday)
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });
    });

    group('Date Spacing Preservation', () {
      test('should preserve 3-day gap between planned and deadline dates for daily recurrence', () {
        // Arrange
        final completedDate = DateTime(2024, 1, 15);
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with date spacing',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15),
          deadlineDate: DateTime(2024, 1, 18), // 3-day gap
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        final gap = result.deadlineDate!.difference(result.plannedDate);
        expect(gap.inDays, 3); // Should maintain 3-day gap

        // Verify dates are correctly calculated from completion date (15th) + 1 day = 16th
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 16); // Next day

        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 1);
        expect(result.deadlineDate!.day, 19); // Next deadline (16 + 3 days)
      });

      test('should preserve 1-week gap between planned and deadline dates for weekly recurrence', () {
        // Arrange
        final completedDate = DateTime(2024, 1, 15);
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with weekly date spacing',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15),
          deadlineDate: DateTime(2024, 1, 22), // 1-week gap
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 2, // Every 2 weeks
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        final gap = result.deadlineDate!.difference(result.plannedDate);
        expect(gap.inDays, 7); // Should maintain 1-week gap

        // Verify dates are correctly calculated from completion date (15th) + 14 days = 29th
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 29); // 2 weeks later

        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 2);
        expect(result.deadlineDate!.day, 5); // 1 week after planned date
      });

      test('should preserve 2-day gap for daysOfWeek recurrence', () {
        // Arrange
        final completedDate = DateTime(2024, 1, 15); // Monday
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with daysOfWeek date spacing',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15), // Monday
          deadlineDate: DateTime(2024, 1, 17), // Wednesday (2-day gap)
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,wednesday,friday',
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        final gap = result.deadlineDate!.difference(result.plannedDate);
        expect(gap.inDays, 2); // Should maintain 2-day gap

        // Next valid day after Mon 15th is Wed 17th
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 17); // Next Wednesday

        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 1);
        expect(result.deadlineDate!.day, 19); // 2 days after planned date (Friday)
      });

      test('should handle planned date only (no deadline date)', () {
        // Arrange
        final completedDate = DateTime(2024, 1, 15);
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with only planned date',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15),
          deadlineDate: null, // No deadline
          recurrenceType: RecurrenceType.daily,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNull); // Should remain null
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 16); // Next day after completion
      });

      test('should handle deadline date only (no planned date)', () {
        // Arrange
        final completedDate = DateTime(2024, 1, 18);
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with only deadline date',
          completedAt: completedDate,
          plannedDate: null, // No planned date
          deadlineDate: DateTime(2024, 1, 18),
          recurrenceType: RecurrenceType.weekly,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        expect(result.plannedDate, isNotNull); // Should be calculated from deadline

        // Verify deadline is calculated correctly (18th + 7 days = 25th)
        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 1);
        expect(result.deadlineDate!.day, 25); // Next week

        // Verify planned date is 1 day before deadline (24th)
        expect(result.plannedDate.day, 24);
      });

      test('should handle complex time offset with hours and minutes', () {
        // Arrange
        final completedDate = DateTime(2024, 1, 15, 10, 0); // Completed at 10:00 (1 hour after planned)
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with complex time offset',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15, 9, 0), // 9:00 AM
          deadlineDate: DateTime(2024, 1, 15, 17, 30), // 5:30 PM (8.5 hours later)
          recurrenceType: RecurrenceType.daily,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        final gap = result.deadlineDate!.difference(result.plannedDate);
        expect(gap.inMinutes, 8 * 60 + 30, reason: 'The time gap should be exactly 8 hours and 30 minutes.');

        // Verify time uses completion time (10:00) as base
        expect(result.plannedDate.hour, 10);
        expect(result.plannedDate.minute, 0);
        expect(result.plannedDate.day, 16); // Next day

        // Deadline should be 10:00 + 8h30m = 18:30
        expect(result.deadlineDate!.hour, 18);
        expect(result.deadlineDate!.minute, 30);
      });
    });

    group('Recurrence from Completion Date', () {
      test('should recur from completion date when completed late (daily)', () {
        // Arrange
        // Planned for 15th, but completed on 17th (2 days late)
        final completedDate = DateTime(2024, 1, 17);
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Late Daily Task',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15),
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        // Should be 17th + 1 day = 18th.
        // (Old behavior would be 15th + 1 = 16th, effectively immediately overdue)
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 18);
      });

      test('should recur from planned date when completed early (daily)', () {
        // Arrange
        // Planned for 15th, completed on 14th (1 day early)
        final completedDate = DateTime(2024, 1, 14);
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Early Daily Task',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15),
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        // Planned (15th) is after Completed (14th).
        // Recurrence base should be Planned (15th).
        // Next date = 15th + 1 = 16th.
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 16);
      });

      test('should find next valid weekday after completion date (Days of Week)', () {
        // Arrange
        // Mondays and Fridays.
        // Planned Mon 15th. Completed Tue 16th (Late).
        final completedDate = DateTime(2024, 1, 16); // Tuesday
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Late Weekday Task',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15), // Monday
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,friday',
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        // Next valid day after Tue 16th is Fri 19th.
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 19);
      });

      test('should skip missed slots if completed very late (Days of Week)', () {
        // Arrange
        // Mondays and Fridays.
        // Planned Mon 15th. Completed Fri 19th (Very Late).
        final completedDate = DateTime(2024, 1, 19); // Friday
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Very Late Weekday Task',
          completedAt: completedDate,
          plannedDate: DateTime(2024, 1, 15), // Monday
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,friday',
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        // Next valid day after Fri 19th is Mon 22nd.
        // Note: It skips the "Fri 19th" slot itself because we effectively "used" it up
        // or passed it by completing *on* that day.
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 22);
      });
    });

    group('Input Validation Tests', () {
      test('should throw ArgumentError for negative recurrence interval', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Invalid Recurring Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: -1, // Negative interval
        );

        // Act & Assert
        expect(
          () => service.calculateNextRecurrenceDate(task, DateTime.now()),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for zero recurrence interval', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Invalid Recurring Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 0, // Zero interval
        );

        // Act & Assert
        expect(
          () => service.calculateNextRecurrenceDate(task, DateTime.now()),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for future recurrence start date', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Future Date Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceStartDate: DateTime.now().add(const Duration(days: 400)), // Too far in future
        );

        // Act & Assert
        expect(
          () => service.calculateNextRecurrenceDate(task, DateTime.now()),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle daysOfWeek with no days specified (backward compatibility)', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'No Days Specified Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: '', // Empty days string - should fallback to weekly
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act & Assert - Should fallback to simple weekly recurrence
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);
        final expectedDate = DateTime(2024, 1, 22); // Next Monday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('should validate parameters in canCreateNextInstance method', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Invalid Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: -1, // Invalid interval
        );

        // Act & Assert
        expect(
          () => service.canCreateNextInstance(task),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Boundary Condition Tests', () {
      test('should handle year boundaries correctly for monthly recurrence', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Year Boundary Task',
          completedAt: null,
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2023, 12, 15); // December 15th

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate.year, 2024);
        expect(nextDate.month, 1);
        expect(nextDate.day, 15);
      });

      test('should handle leap years correctly for monthly recurrence', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Leap Year Task',
          completedAt: null,
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 31); // January 31st in leap year

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - Should cap to February 29th in leap year
        expect(nextDate.year, 2024);
        expect(nextDate.month, 2);
        expect(nextDate.day, 29);
      });

      test('should handle month end boundaries correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Month End Task',
          completedAt: null,
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 3, 31); // March 31st

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - April has 30 days
        expect(nextDate.year, 2024);
        expect(nextDate.month, 4);
        expect(nextDate.day, 30);
      });

      test('should handle extreme daysOfWeek search scenario', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Extreme Search Task',
          completedAt: null,
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'saturday', // Only Saturday
          recurrenceInterval: 13, // Every 13 weeks
        );

        // Start from a Monday far from a Saturday matching the interval
        final currentDate = DateTime(2024, 1, 1); // Monday

        // Act - Should not hang or take too long
        final stopwatch = Stopwatch()..start();
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);
        stopwatch.stop();

        // Assert
        expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Should be very fast
        expect(nextDate.weekday, DateTime.saturday);
      });

      test('should handle non-leap year February correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Non-leap Year February Task',
          completedAt: null,
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2023, 1, 31); // January 31st, 2023 (not leap year)

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - February 2023 has 28 days
        expect(nextDate.year, 2023);
        expect(nextDate.month, 2);
        expect(nextDate.day, 28);
      });
    });

    group('weeklySchedule (Per-Day Times) Tests', () {
      group('Basic Per-Day Time Calculation', () {
        test('should calculate next recurrence with different times for different days', () {
          // Arrange: Monday 9AM, Tuesday 10AM, Wednesday 9AM
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Varied Time Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 9, 0), // Monday 9:00 AM
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
                const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0), // Tuesday 10:00
                const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0), // Wednesday 9:00
              ],
            ),
          );

          // Act: Calculate from Monday 9:00 AM
          final currentDate = DateTime(2024, 1, 8, 9, 30); // Monday 9:30 AM
          final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

          // Assert: Next should be Tuesday at 10:00 AM (not 9:00 AM)
          expect(nextDate.year, 2024);
          expect(nextDate.month, 1);
          expect(nextDate.day, 9); // Tuesday
          expect(nextDate.hour, 10);
          expect(nextDate.minute, 0);
        });

        test('should sequence through week with per-day times correctly', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Work Schedule Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 9, 0), // Monday 9:00
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
                const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0), // Tue 10:00
                const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0), // Wed 9:00
                const WeeklySchedule(dayOfWeek: 4, hour: 14, minute: 0), // Thu 14:00
                const WeeklySchedule(dayOfWeek: 5, hour: 9, minute: 0), // Fri 9:00
              ],
            ),
          );

          // After Monday, next is Tuesday at 10:00
          final result1 = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 9, 30),
          );
          expect(result1, DateTime(2024, 1, 9, 10, 0)); // Tuesday 10:00

          // After Tuesday, next is Wednesday at 9:00
          final result2 = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 9, 10, 30),
          );
          expect(result2, DateTime(2024, 1, 10, 9, 0)); // Wednesday 9:00

          // After Wednesday, next is Thursday at 14:00
          final result3 = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 10, 9, 30),
          );
          expect(result3, DateTime(2024, 1, 11, 14, 0)); // Thursday 14:00
        });

        test('should wrap to next week with correct time', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'End of Week Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 12, 17, 0), // Friday
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
                const WeeklySchedule(dayOfWeek: 3, hour: 10, minute: 0), // Wednesday 10:00
              ],
            ),
          );

          // From Friday, next is Monday at 9:00
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 12, 17, 30),
          );

          expect(result, DateTime(2024, 1, 15, 9, 0)); // Next Monday 9:00
        });

        test('should handle weekend with different times', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Weekend Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 13, 10, 0), // Saturday
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 6, hour: 10, minute: 0), // Saturday 10:00
                const WeeklySchedule(dayOfWeek: 7, hour: 12, minute: 0), // Sunday 12:00
              ],
            ),
          );

          // From Saturday 11:00, next is Sunday 12:00
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 13, 11, 0),
          );

          expect(result, DateTime(2024, 1, 14, 12, 0)); // Sunday 12:00
        });
      });

      group('weeklySchedule with Interval', () {
        test('should respect biweekly interval with per-day times', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Biweekly Task',
            completedAt: null,
            recurrenceStartDate: DateTime(2024, 1, 2), // Tuesday (reference)
            plannedDate: DateTime(2024, 1, 2, 10, 0),
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              interval: 2, // Every 2 weeks
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 2, hour: 10, minute: 0), // Tuesday 10:00
              ],
            ),
          );

          // From Tuesday (1 week later), next should be Tuesday in 2 weeks
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 9, 10, 0), // 1 week after reference
          );

          expect(result, DateTime(2024, 1, 16, 10, 0)); // 2 weeks from reference
        });

        test('should handle multiple days with biweekly interval', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Biweekly Multi-Day Task',
            completedAt: null,
            recurrenceStartDate: DateTime(2024, 1, 1), // Monday reference
            plannedDate: DateTime(2024, 1, 1, 9, 0),
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              interval: 2, // Every 2 weeks
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
                const WeeklySchedule(dayOfWeek: 3, hour: 14, minute: 0), // Wednesday 14:00
              ],
            ),
          );

          // From Wednesday of week 2, should skip to Monday of week 3
          // (week 2 Wednesday is not on interval, so next is Monday of week 3)
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 10, 14, 30), // Wednesday Jan 10 (week 2)
          );

          // Week 1: Jan 1 (Mon), Jan 3 (Wed)
          // Week 2: Jan 8 (Mon), Jan 10 (Wed) - not on interval from reference
          // Week 3: Jan 15 (Mon) - this is 2 weeks from Jan 1
          expect(result, DateTime(2024, 1, 15, 9, 0)); // Monday Jan 15
        });
      });

      group('weeklySchedule Edge Cases', () {
        test('should fall back to daysOfWeek when weeklySchedule is null', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Legacy Days Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8), // Monday
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              daysOfWeek: [1, 3, 5], // Monday, Wednesday, Friday
              weeklySchedule: null, // No per-day times
            ),
          );

          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 10, 0),
          );

          // Should use daysOfWeek logic (same time)
          expect(result, DateTime(2024, 1, 10, 10, 0)); // Wednesday same time
        });

        test('should fall back to daysOfWeek when weeklySchedule is empty', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Empty Schedule Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8), // Monday
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              daysOfWeek: [2, 4], // Tuesday, Thursday
              weeklySchedule: [], // Empty list
            ),
          );

          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 10, 0),
          );

          // Should use daysOfWeek logic
          expect(result, DateTime(2024, 1, 9, 10, 0)); // Tuesday same time
        });

        test('should prefer weeklySchedule over daysOfWeek when both exist', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Dual Schedule Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 9, 0), // Monday 9:00
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              daysOfWeek: [1, 2, 3], // Monday, Tuesday, Wednesday (same time)
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Monday 9:00
                const WeeklySchedule(dayOfWeek: 2, hour: 14, minute: 0), // Tuesday 14:00 (different!)
                const WeeklySchedule(dayOfWeek: 3, hour: 9, minute: 0), // Wednesday 9:00
              ],
            ),
          );

          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 9, 30), // Monday 9:30
          );

          // Should use weeklySchedule (Tuesday at 14:00, not same time)
          expect(result, DateTime(2024, 1, 9, 14, 0)); // Tuesday 14:00
        });
      });

      group('weeklySchedule with End Conditions', () {
        test('should respect end date with weeklySchedule', () {
          final futureEndDate = DateTime.now().add(const Duration(days: 30));
          final futurePlannedDate = DateTime.now().add(const Duration(days: 1));

          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Date Limited Task',
            completedAt: null,
            plannedDate: futurePlannedDate,
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                WeeklySchedule(dayOfWeek: futurePlannedDate.weekday, hour: 9, minute: 0),
              ],
              endCondition: RecurrenceEndCondition.date,
              endDate: futureEndDate,
            ),
          );

          // Should allow since there are occurrences before end date
          final canCreate = service.canCreateNextInstance(task);
          expect(canCreate, isTrue);
        });

        test('should stop when next occurrence is after end date', () {
          final futureEndDate = DateTime.now().add(const Duration(hours: 2));
          final futurePlannedDate = DateTime.now().add(const Duration(hours: 1));

          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Ending Task',
            completedAt: null,
            plannedDate: futurePlannedDate,
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                WeeklySchedule(dayOfWeek: futurePlannedDate.weekday, hour: futurePlannedDate.hour, minute: 0),
              ],
              endCondition: RecurrenceEndCondition.date,
              endDate: futureEndDate,
            ),
          );

          // End date is soon, so next occurrence would be after end date
          final canCreate = service.canCreateNextInstance(task);
          expect(canCreate, isFalse);
        });

        test('should track occurrence count with weeklySchedule', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Count Limited Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 9, 0),
            recurrenceCount: 5, // 5 remaining
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0),
                const WeeklySchedule(dayOfWeek: 3, hour: 10, minute: 0),
              ],
              endCondition: RecurrenceEndCondition.count,
              occurrenceCount: 10,
            ),
          );

          // Should allow since count > 0
          final canCreate = service.canCreateNextInstance(task);
          expect(canCreate, isTrue);
        });
      });

      group('weeklySchedule Real-World Scenarios', () {
        test('should handle work week with meeting at different time', () {
          // Mon-Fri 9AM, but Wednesday meeting at 2PM
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Work Week Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 9, 0),
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
                const WeeklySchedule(dayOfWeek: 2, hour: 9, minute: 0), // Tue 9:00
                const WeeklySchedule(dayOfWeek: 3, hour: 14, minute: 0), // Wed 14:00 (meeting)
                const WeeklySchedule(dayOfWeek: 4, hour: 9, minute: 0), // Thu 9:00
                const WeeklySchedule(dayOfWeek: 5, hour: 9, minute: 0), // Fri 9:00
              ],
            ),
          );

          // From Tuesday 10:00, next is Wednesday 14:00
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 9, 10, 0),
          );

          expect(result, DateTime(2024, 1, 10, 14, 0)); // Wednesday 14:00
        });

        test('should handle exercise schedule: morning weekdays, evening weekends', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Exercise Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 7, 0), // Monday 7:00
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 7, minute: 0), // Mon 7:00
                const WeeklySchedule(dayOfWeek: 2, hour: 7, minute: 0), // Tue 7:00
                const WeeklySchedule(dayOfWeek: 3, hour: 7, minute: 0), // Wed 7:00
                const WeeklySchedule(dayOfWeek: 4, hour: 7, minute: 0), // Thu 7:00
                const WeeklySchedule(dayOfWeek: 5, hour: 7, minute: 0), // Fri 7:00
                const WeeklySchedule(dayOfWeek: 6, hour: 18, minute: 0), // Sat 18:00
                const WeeklySchedule(dayOfWeek: 7, hour: 18, minute: 0), // Sun 18:00
              ],
            ),
          );

          // From Friday 8:00, next is Saturday 18:00
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 12, 8, 0),
          );

          expect(result, DateTime(2024, 1, 13, 18, 0)); // Saturday 18:00
        });

        test('should handle medication schedule: different times on different days', () {
          // Morning meds on Mon/Wed/Fri, evening meds on Tue/Thu
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Medication Task',
            completedAt: null,
            plannedDate: DateTime(2024, 1, 8, 8, 0), // Monday 8:00
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 8, minute: 0), // Mon 8:00
                const WeeklySchedule(dayOfWeek: 2, hour: 20, minute: 0), // Tue 20:00
                const WeeklySchedule(dayOfWeek: 3, hour: 8, minute: 0), // Wed 8:00
                const WeeklySchedule(dayOfWeek: 4, hour: 20, minute: 0), // Thu 20:00
                const WeeklySchedule(dayOfWeek: 5, hour: 8, minute: 0), // Fri 8:00
              ],
            ),
          );

          // After Monday 9:00, next is Tuesday 20:00
          final result1 = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 9, 0),
          );
          expect(result1, DateTime(2024, 1, 9, 20, 0)); // Tuesday 20:00

          // After Tuesday 21:00, next is Wednesday 8:00
          final result2 = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 9, 21, 0),
          );
          expect(result2, DateTime(2024, 1, 10, 8, 0)); // Wednesday 8:00
        });
      });

      group('weeklySchedule with From Policy', () {
        test('should use planned date as base when fromPolicy is plannedDate', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Planned Date Task',
            completedAt: DateTime(2024, 1, 8, 10, 0), // Completed at 10:00
            plannedDate: DateTime(2024, 1, 8, 9, 0), // Planned for 9:00
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              fromPolicy: RecurrenceFromPolicy.plannedDate,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
                const WeeklySchedule(dayOfWeek: 2, hour: 14, minute: 0), // Tue 14:00
              ],
            ),
          );

          // Should base calculation on planned date (9:00), not completion (10:00)
          // From Monday 9:00, next is Tuesday 14:00
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 10, 0), // Completed at 10:00
          );

          expect(result, DateTime(2024, 1, 9, 14, 0)); // Tuesday 14:00
        });

        test('should use completion date as base when fromPolicy is completionDate', () {
          final task = Task(
            id: 'task-1',
            createdDate: DateTime.now().toUtc(),
            title: 'Completion Date Task',
            completedAt: DateTime(2024, 1, 8, 10, 0), // Completed at 10:00
            plannedDate: DateTime(2024, 1, 8, 9, 0), // Planned for 9:00
            recurrenceConfiguration: RecurrenceConfiguration(
              frequency: RecurrenceFrequency.weekly,
              fromPolicy: RecurrenceFromPolicy.completionDate,
              weeklySchedule: [
                const WeeklySchedule(dayOfWeek: 1, hour: 9, minute: 0), // Mon 9:00
                const WeeklySchedule(dayOfWeek: 2, hour: 14, minute: 0), // Tue 14:00
              ],
            ),
          );

          // Should base calculation on completion date (10:00)
          // From Monday 10:00, next is Tuesday 14:00
          final result = service.calculateNextRecurrenceDate(
            task,
            DateTime(2024, 1, 8, 10, 0), // Completed at 10:00
          );

          expect(result, DateTime(2024, 1, 9, 14, 0)); // Tuesday 14:00
        });
      });
    });
  });
}
