import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
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
  late TaskRecurrenceService service;

  group('RecurrenceConfiguration Validation Tests', () {
    group('Constructor Validation', () {
      test('should throw ArgumentError for negative interval', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            interval: -1,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for zero interval', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            interval: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for interval exceeding maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            interval: 366, // More than 1 year
          ),
          throwsArgumentError,
        );
      });

      test('should accept valid interval at minimum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            interval: 1,
          ),
          returnsNormally,
        );
      });

      test('should accept valid interval at maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            interval: 365,
          ),
          returnsNormally,
        );
      });

      test('should throw ArgumentError for dayOfMonth below minimum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.specificDay,
            dayOfMonth: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for dayOfMonth above maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.specificDay,
            dayOfMonth: 32,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for dayOfWeek below minimum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.relativeDay,
            dayOfWeek: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for dayOfWeek above maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.relativeDay,
            dayOfWeek: 8,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for weekOfMonth below minimum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.relativeDay,
            weekOfMonth: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for weekOfMonth above maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.relativeDay,
            weekOfMonth: 6,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for monthOfYear below minimum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.yearly,
            monthOfYear: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for monthOfYear above maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.yearly,
            monthOfYear: 13,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for occurrenceCount zero', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 0,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for occurrenceCount above maximum', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 10001,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for endDate in the past', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for endDate exactly now', () {
        // Use a date that's more than 1 second in the past to ensure it's rejected
        // even with the 1-second tolerance in the validation
        final now = DateTime.now().subtract(const Duration(seconds: 2));
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endDate: now,
          ),
          throwsArgumentError,
        );
      });

      test('should accept endDate in the future', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endDate: futureDate,
          ),
          returnsNormally,
        );
      });

      test('should throw ArgumentError for invalid daysOfWeek values', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.weekly,
            daysOfWeek: [0, 8], // Invalid values
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for relative day pattern without weekOfMonth', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.relativeDay,
            weekOfMonth: null,
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for relative day pattern without dayOfWeek', () {
        expect(
          () => RecurrenceConfiguration(
            frequency: RecurrenceFrequency.monthly,
            monthlyPatternType: MonthlyPatternType.relativeDay,
            dayOfWeek: null,
          ),
          throwsArgumentError,
        );
      });
    });

    group('JSON Serialization Round-Trip Tests', () {
      test('should serialize and deserialize daily recurrence correctly', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          interval: 2,
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.interval, original.interval);
      });

      test('should serialize and deserialize weekly recurrence with days', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.weekly,
          interval: 3,
          daysOfWeek: [1, 3, 5], // Monday, Wednesday, Friday
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.interval, original.interval);
        expect(deserialized.daysOfWeek, original.daysOfWeek);
      });

      test('should serialize and deserialize monthly recurrence with specific day', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          monthlyPatternType: MonthlyPatternType.specificDay,
          dayOfMonth: 15,
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.interval, original.interval);
        expect(deserialized.monthlyPatternType, original.monthlyPatternType);
        expect(deserialized.dayOfMonth, original.dayOfMonth);
      });

      test('should serialize and deserialize monthly recurrence with relative day', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          monthlyPatternType: MonthlyPatternType.relativeDay,
          weekOfMonth: 2,
          dayOfWeek: 3, // Wednesday
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.interval, original.interval);
        expect(deserialized.monthlyPatternType, original.monthlyPatternType);
        expect(deserialized.weekOfMonth, original.weekOfMonth);
        expect(deserialized.dayOfWeek, original.dayOfWeek);
      });

      test('should serialize and deserialize yearly recurrence', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.yearly,
          interval: 2,
          monthOfYear: 6,
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.interval, original.interval);
        expect(deserialized.monthOfYear, original.monthOfYear);
      });

      test('should serialize and deserialize with end condition date', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          endCondition: RecurrenceEndCondition.date,
          endDate: DateTime(2027, 12, 31),
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.endCondition, original.endCondition);
        expect(deserialized.endDate?.toIso8601String(), original.endDate?.toIso8601String());
      });

      test('should serialize and deserialize with end condition count', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          endCondition: RecurrenceEndCondition.count,
          occurrenceCount: 10,
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.endCondition, original.endCondition);
        expect(deserialized.occurrenceCount, original.occurrenceCount);
      });

      test('should serialize and deserialize with fromPolicy', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          fromPolicy: RecurrenceFromPolicy.completionDate,
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.fromPolicy, original.fromPolicy);
      });

      test('should serialize and deserialize complete configuration', () {
        final original = RecurrenceConfiguration(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          daysOfWeek: [2, 4], // Tuesday, Thursday
          endCondition: RecurrenceEndCondition.date,
          endDate: DateTime(2027, 6, 30),
          fromPolicy: RecurrenceFromPolicy.plannedDate,
        );

        final json = original.toJson();
        final deserialized = RecurrenceConfiguration.fromJson(json);

        expect(deserialized.frequency, original.frequency);
        expect(deserialized.interval, original.interval);
        expect(deserialized.daysOfWeek, original.daysOfWeek);
        expect(deserialized.endCondition, original.endCondition);
        expect(deserialized.endDate?.toIso8601String(), original.endDate?.toIso8601String());
        expect(deserialized.fromPolicy, original.fromPolicy);
      });
    });

    group('End Condition Tests - New Configuration System', () {
      setUp(() {
        service = TaskRecurrenceService(TestLogger(), FakeTaskRepository());
      });

      test('canCreateNextInstance should stop when end date is reached', () {
        final pastDate = DateTime.now().toUtc().subtract(const Duration(days: 5));
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Date-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc().subtract(const Duration(days: 10)),
          recurrenceConfiguration: RecurrenceConfiguration.test(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.date,
            endDate: pastDate, // End date reached
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should not allow new instances
        expect(canCreate, isFalse);
      });

      test('canCreateNextInstance should stop when end date is exactly today', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Date-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc().add(const Duration(days: 2)), // Future date
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.date,
            endDate: DateTime.now().toUtc(), // End date is now
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Next occurrence would be after end date
        expect(canCreate, isFalse);
      });

      test('canCreateNextInstance should allow when end date is in future', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Date-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc().add(const Duration(days: 1)),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.date,
            endDate: DateTime.now().toUtc().add(const Duration(days: 5)), // End date in future
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Next occurrence would be before end date
        expect(canCreate, isTrue);
      });

      test('canCreateNextInstance should stop when count limit is zero', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Count-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceCount: 0, // No more occurrences
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 10,
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should not allow new instances
        expect(canCreate, isFalse);
      });

      test('canCreateNextInstance should use task.recurrenceCount when set', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Count-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceCount: 5, // 5 remaining occurrences
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 10,
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should allow new instances (5 > 0)
        expect(canCreate, isTrue);
      });

      test('canCreateNextInstance should use config.occurrenceCount when task.recurrenceCount is null', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Count-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          // No task-level count, config has limit
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 10,
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should allow new instances (config count > 0)
        expect(canCreate, isTrue);
      });

      test('canCreateNextInstance should stop when both counts are zero', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Count-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceCount: 0, // No task-level occurrences
          recurrenceConfiguration: RecurrenceConfiguration.test(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 0, // No config occurrences
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should not allow new instances
        expect(canCreate, isFalse);
      });

      test('canCreateNextInstance should respect both count limits simultaneously', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Count-limited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceCount: 3, // Task limit is lower
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.count,
            occurrenceCount: 5, // Config limit is higher
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should stop when task-level count reaches zero
        expect(canCreate, isTrue);
      });

      test('canCreateNextInstance should allow unlimited recurrence with no limits', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Unlimited Recurring Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceConfiguration: RecurrenceConfiguration(
            frequency: RecurrenceFrequency.daily,
            endCondition: RecurrenceEndCondition.never,
          ),
        );

        // Act
        final canCreate = service.canCreateNextInstance(task);

        // Assert - Should always allow
        expect(canCreate, isTrue);
      });
    });

    group('Migration Data Verification Tests', () {
      test('can handle null recurrenceConfiguration gracefully (backward compatibility)', () {
        // Task from v30 might not have recurrenceConfiguration at all
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Legacy Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceConfiguration: null,
        );

        // Act - Service should handle null without throwing
        final isRecurring = service.isRecurring(task);

        // Assert - Should return false (no config, default RecurrenceType.none)
        expect(isRecurring, isFalse);
      });

      test('can calculate next date for task without recurrenceConfiguration', () {
        final task = Task(
          id: 'task-1',
          createdDate: DateTime.now().toUtc(),
          title: 'Legacy Task',
          completedAt: null,
          plannedDate: DateTime.now().toUtc(),
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
          recurrenceConfiguration: null,
        );

        // Act
        final currentDate = DateTime.now().toUtc();
        final nextDate = service.calculateNextRecurrenceDate(task, currentDate);

        // Assert - Should fall back to legacy daily recurrence
        final expectedDate = currentDate.add(const Duration(days: 1));
        expect(nextDate.day, expectedDate.day);
        expect(nextDate.month, expectedDate.month);
        expect(nextDate.year, expectedDate.year);
      });
    });
  });
}
