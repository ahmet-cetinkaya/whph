import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/utils/task_recurrence_validator.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

void main() {
  group('TaskRecurrenceValidator Tests', () {
    group('validateRecurrenceInterval', () {
      test('should pass for valid positive intervals', () {
        expect(() => TaskRecurrenceValidator.validateRecurrenceInterval(1), returnsNormally);
        expect(() => TaskRecurrenceValidator.validateRecurrenceInterval(5), returnsNormally);
        expect(() => TaskRecurrenceValidator.validateRecurrenceInterval(365), returnsNormally);
      });

      test('should pass for null interval', () {
        expect(() => TaskRecurrenceValidator.validateRecurrenceInterval(null), returnsNormally);
      });

      test('should throw ArgumentError for zero interval', () {
        expect(
          () => TaskRecurrenceValidator.validateRecurrenceInterval(0),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'interval')
              .having((e) => e.message, 'message', contains('must be greater than 0'))),
        );
      });

      test('should throw ArgumentError for negative intervals', () {
        expect(
          () => TaskRecurrenceValidator.validateRecurrenceInterval(-1),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'interval')
              .having((e) => e.message, 'message', contains('must be greater than 0'))),
        );

        expect(() => TaskRecurrenceValidator.validateRecurrenceInterval(-100), throwsA(isA<ArgumentError>()));
      });
    });

    group('validateRecurrenceStartDate', () {
      test('should pass for null start date', () {
        expect(() => TaskRecurrenceValidator.validateRecurrenceStartDate(null), returnsNormally);
      });

      test('should pass for reasonable future dates', () {
        final validDate = DateTime.now().add(const Duration(days: 30));
        expect(() => TaskRecurrenceValidator.validateRecurrenceStartDate(validDate), returnsNormally);
      });

      test('should pass for past dates', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 30));
        expect(() => TaskRecurrenceValidator.validateRecurrenceStartDate(pastDate), returnsNormally);
      });

      test('should pass for exactly 1 year in future', () {
        final futureDate = DateTime.now().add(const Duration(days: 365));
        expect(() => TaskRecurrenceValidator.validateRecurrenceStartDate(futureDate), returnsNormally);
      });

      test('should throw ArgumentError for dates too far in future', () {
        final futureDate = DateTime.now().add(const Duration(days: 400));
        expect(
          () => TaskRecurrenceValidator.validateRecurrenceStartDate(futureDate),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'startDate')
              .having((e) => e.message, 'message', contains('cannot be more than 1 year in the future'))),
        );
      });
    });

    group('validateDaysOfWeekRecurrence', () {
      test('should pass for non-daysOfWeek recurrence types', () {
        final dailyTask = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Daily Task',
          recurrenceType: RecurrenceType.daily,
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(dailyTask), returnsNormally);
      });

      test('should pass for valid daysOfWeek with multiple days', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Days Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,wednesday,friday',
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(task), returnsNormally);
      });

      test('should pass for valid daysOfWeek with single day', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Single Day Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday',
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(task), returnsNormally);
      });

      test('should pass for empty days string for backward compatibility', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Empty Days Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: '',
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(task), returnsNormally);
      });

      test('should pass for null days string for backward compatibility', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Null Days Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: null,
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(task), returnsNormally);
      });

      test('should pass for days string with only commas for backward compatibility', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Comma Only Days Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: ',,,',
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(task), returnsNormally);
      });

      test('should pass for days string with only whitespace for backward compatibility', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Whitespace Days Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: '   ,   ,   ',
        );

        expect(() => TaskRecurrenceValidator.validateDaysOfWeekRecurrence(task), returnsNormally);
      });
    });

    group('validateRecurrenceParameters', () {
      test('should pass for valid task with all parameters', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Valid Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceInterval: 2,
          recurrenceStartDate: DateTime.now().add(const Duration(days: 30)),
          recurrenceDaysString: 'monday,wednesday',
        );

        expect(() => TaskRecurrenceValidator.validateRecurrenceParameters(task), returnsNormally);
      });

      test('should throw when interval is invalid', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Invalid Interval Task',
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 0,
        );

        expect(() => TaskRecurrenceValidator.validateRecurrenceParameters(task), throwsA(isA<ArgumentError>()));
      });

      test('should throw when start date is invalid', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Invalid Date Task',
          recurrenceType: RecurrenceType.daily,
          recurrenceStartDate: DateTime.now().add(const Duration(days: 400)),
        );

        expect(() => TaskRecurrenceValidator.validateRecurrenceParameters(task), throwsA(isA<ArgumentError>()));
      });

      test('should pass when days are empty for backward compatibility', () {
        final task = Task(
          id: 'test',
          createdDate: DateTime.now(),
          title: 'Empty Days Task',
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: '', // Empty days allowed for backward compatibility
        );

        expect(() => TaskRecurrenceValidator.validateRecurrenceParameters(task), returnsNormally);
      });
    });
  });
}
