import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

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
          createdDate: DateTime.now().toUtc(),
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
  });
}

// Test helper class
class TestLogger implements ILogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    // Do nothing in tests
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    // Do nothing in tests
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    // Do nothing in tests
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    // Do nothing in tests
  }

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    // Do nothing in tests
  }
}
