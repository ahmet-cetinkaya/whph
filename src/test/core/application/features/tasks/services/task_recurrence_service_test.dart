import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

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
      service = TaskRecurrenceService(TestLogger());
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
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with date spacing',
          completedAt: null,
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

        // Verify dates are correctly calculated
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 16); // Next day

        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 1);
        expect(result.deadlineDate!.day, 19); // Next deadline (16 + 3 days)
      });

      test('should preserve 1-week gap between planned and deadline dates for weekly recurrence', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with weekly date spacing',
          completedAt: null,
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

        // Verify dates are correctly calculated (every 2 weeks)
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 29); // 2 weeks later

        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 2);
        expect(result.deadlineDate!.day, 5); // 1 week after planned date
      });

      test('should preserve 2-day gap for daysOfWeek recurrence', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with daysOfWeek date spacing',
          completedAt: null,
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

        // Should go to next Wednesday (from Monday 15th to Wednesday 17th)
        expect(result.plannedDate.year, 2024);
        expect(result.plannedDate.month, 1);
        expect(result.plannedDate.day, 17); // Next Wednesday

        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 1);
        expect(result.deadlineDate!.day, 19); // 2 days after planned date (Friday)
      });

      test('should handle planned date only (no deadline date)', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with only planned date',
          completedAt: null,
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
        expect(result.plannedDate.day, 16); // Next day
      });

      test('should handle deadline date only (no planned date)', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with only deadline date',
          completedAt: null,
          plannedDate: null, // No planned date
          deadlineDate: DateTime(2024, 1, 18),
          recurrenceType: RecurrenceType.weekly,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        expect(result.plannedDate, isNotNull); // Should be calculated from deadline

        // Verify deadline is calculated correctly
        expect(result.deadlineDate!.year, 2024);
        expect(result.deadlineDate!.month, 1);
        expect(result.deadlineDate!.day, 25); // Next week
      });

      test('should handle complex time offset with hours and minutes', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Task with complex time offset',
          completedAt: null,
          plannedDate: DateTime(2024, 1, 15, 9, 0), // 9:00 AM
          deadlineDate: DateTime(2024, 1, 15, 17, 30), // 5:30 PM (8.5 hours later)
          recurrenceType: RecurrenceType.daily,
        );

        // Act
        final result = service.calculateNextDatesForTesting(task);

        // Assert
        expect(result.deadlineDate, isNotNull);
        final gap = result.deadlineDate!.difference(result.plannedDate);
        expect(gap.inHours, 8);
        expect(gap.inMinutes % 60, 30); // Should maintain 8 hour 30 minute gap (30 minutes beyond full hours)
        expect(gap.inMinutes, 8 * 60 + 30); // Total minutes should be 510

        // Verify time is preserved
        expect(result.plannedDate.hour, 9);
        expect(result.plannedDate.minute, 0);

        expect(result.deadlineDate!.hour, 17);
        expect(result.deadlineDate!.minute, 30);
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
  });
}
