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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
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
          title: 'Weekly Task',
          isCompleted: false,
          recurrenceType: RecurrenceType.weekly,
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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 1,
        );

        final currentDate = DateTime(2024, 1, 15); // Monday

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        final expectedDate = DateTime(2024, 1, 22); // Next Monday
        expect(nextDate.year, expectedDate.year);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.day, expectedDate.day);
      });

      test('calculateNextRecurrenceDate should handle weekly recurrence with specific days', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Weekly Task',
          isCompleted: false,
          recurrenceType: RecurrenceType.weekly,
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

      test('calculateNextRecurrenceDate should handle monthly recurrence correctly', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Monthly Task',
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
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
          isCompleted: false,
          recurrenceType: RecurrenceType.none,
        );

        final currentDate = DateTime(2024, 1, 15);

        // Act
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert
        expect(nextDate, currentDate);
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
