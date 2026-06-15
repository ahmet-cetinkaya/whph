import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
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
  group('All Day Recurring Task Integration Tests', () {
    late AppDatabase database;
    late DriftTaskRepository taskRepository;
    late TaskRecurrenceService recurrenceService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      taskRepository = DriftTaskRepository.withDatabase(database);
      recurrenceService = TaskRecurrenceService(TestLogger(), taskRepository);
    });

    tearDown(() async {
      await database.close();
    });

    group('Daily All Day Recurrence', () {
      test('should create next instance as all-day when completing all-day daily task', () async {
        // Arrange - Create an all-day daily recurring task
        final today = DateTime.utc(2024, 1, 15, 0, 0); // All Day (00:00)
        final task = Task(
          id: 'all-day-daily-1',
          createdDate: today,
          title: 'Daily All Day Task',
          completedAt: null,
          plannedDate: today,
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instance date from all-day task
        final nextInstanceDate = recurrenceService.calculateNextRecurrenceDate(
          task,
          DateTime.utc(2024, 1, 15, 0, 0),
        );

        // Assert - Verify next instance is all-day
        expect(nextInstanceDate.day, 16, reason: 'Should be next day');
        expect(nextInstanceDate.hour, 0, reason: 'Should be all-day (00:00)');
        expect(nextInstanceDate.minute, 0, reason: 'Should be all-day (00:00)');
      });

      test('should preserve all-day status across multiple completions', () async {
        // Arrange - Create an all-day daily recurring task
        final task = Task(
          id: 'multi-all-day-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0),
          title: 'Multi-Completion All Day Task',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 0, 0),
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instances for 3 days
        final dates = <DateTime>[];
        for (int i = 0; i < 3; i++) {
          final currentDate = DateTime.utc(2024, 1, 15 + i, 0, 0);
          final nextDate = recurrenceService.calculateNextRecurrenceDate(task, currentDate);
          dates.add(nextDate);
        }

        // Assert - Verify all calculated dates are all-day
        expect(dates.length, 3);
        for (int i = 0; i < 3; i++) {
          expect(dates[i].hour, 0, reason: 'Day ${i + 1} should be all-day');
          expect(dates[i].minute, 0, reason: 'Day ${i + 1} should be all-day');
        }
      });
    });

    group('Weekly All Day Recurrence', () {
      test('should create next instance as all-day when completing all-day weekly task', () async {
        // Arrange - Create an all-day weekly recurring task
        final task = Task(
          id: 'all-day-weekly-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0), // Monday
          title: 'Weekly All Day Task',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 0, 0),
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instance date
        final nextDate = recurrenceService.calculateNextRecurrenceDate(
          task,
          DateTime.utc(2024, 1, 15, 0, 0),
        );

        // Assert - Verify it's 7 days later and all-day
        expect(nextDate.day, 22, reason: 'Should be 7 days later');
        expect(nextDate.hour, 0, reason: 'Should be all-day');
        expect(nextDate.minute, 0, reason: 'Should be all-day');
      });
    });

    group('Monthly All Day Recurrence', () {
      test('should create next instance as all-day when completing all-day monthly task', () async {
        // Arrange - Create an all-day monthly recurring task
        final task = Task(
          id: 'all-day-monthly-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0),
          title: 'Monthly All Day Task',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 0, 0),
          recurrenceType: RecurrenceType.monthly,
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instance date
        final nextDate = recurrenceService.calculateNextRecurrenceDate(
          task,
          DateTime.utc(2024, 1, 15, 0, 0),
        );

        // Assert - Verify it's next month same day and all-day
        expect(nextDate.month, 2, reason: 'Should be next month');
        expect(nextDate.day, 15, reason: 'Should be same day of month');
        expect(nextDate.hour, 0, reason: 'Should be all-day');
        expect(nextDate.minute, 0, reason: 'Should be all-day');
      });
    });

    group('Yearly All Day Recurrence', () {
      test('should create next instance as all-day when completing all-day yearly task', () async {
        // Arrange - Create an all-day yearly recurring task
        final task = Task(
          id: 'all-day-yearly-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0),
          title: 'Yearly All Day Task',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 0, 0),
          recurrenceType: RecurrenceType.yearly,
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instance date
        final nextDate = recurrenceService.calculateNextRecurrenceDate(
          task,
          DateTime.utc(2024, 1, 15, 0, 0),
        );

        // Assert - Verify it's next year same date and all-day
        expect(nextDate.year, 2025, reason: 'Should be next year');
        expect(nextDate.month, 1, reason: 'Should be same month');
        expect(nextDate.day, 15, reason: 'Should be same day');
        expect(nextDate.hour, 0, reason: 'Should be all-day');
        expect(nextDate.minute, 0, reason: 'Should be all-day');
      });
    });

    group('Days of Week All Day Recurrence', () {
      test('should create next instance as all-day when completing all-day days of week task', () async {
        // Arrange - Create an all-day Mon/Wed/Fri recurring task
        final task = Task(
          id: 'all-day-dow-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0), // Monday
          title: 'Mon/Wed/Fri All Day Task',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 0, 0),
          recurrenceType: RecurrenceType.daysOfWeek,
          recurrenceDaysString: 'monday,wednesday,friday',
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instance date from Monday
        final nextDate = recurrenceService.calculateNextRecurrenceDate(
          task,
          DateTime.utc(2024, 1, 15, 0, 0),
        );

        // Assert - Verify it's Wednesday and all-day
        expect(nextDate.day, 17, reason: 'Should be Wednesday (2 days after Monday)');
        expect(nextDate.hour, 0, reason: 'Should be all-day');
        expect(nextDate.minute, 0, reason: 'Should be all-day');
      });
    });

    group('End-to-End Workflow Tests', () {
      test('should handle complete recurrence workflow for all-day tasks', () async {
        // Arrange - Create an all-day weekly recurring task
        final originalTask = Task(
          id: 'workflow-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0),
          title: 'Team Standup',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 0, 0),
          recurrenceType: RecurrenceType.weekly,
          recurrenceInterval: 1,
        );

        await taskRepository.add(originalTask);

        // Act - Simulate completing the task and creating the next instance
        final completedTask = originalTask.copyWith(
          completedAt: DateTime.utc(2024, 1, 15, 10, 0),
        );
        await taskRepository.update(completedTask);

        // Calculate next instance date
        final nextDate = recurrenceService.calculateNextRecurrenceDate(
          originalTask,
          originalTask.plannedDate!,
        );

        // Create next instance
        final nextInstance = Task(
          id: 'workflow-2',
          createdDate: DateTime.utc(2024, 1, 15, 10, 0),
          title: originalTask.title,
          completedAt: null,
          plannedDate: nextDate,
          recurrenceType: originalTask.recurrenceType,
          recurrenceInterval: originalTask.recurrenceInterval,
        );

        await taskRepository.add(nextInstance);

        // Assert - Verify the workflow completed correctly
        final retrievedOriginal = await taskRepository.getById('workflow-1');
        expect(retrievedOriginal, isNotNull);
        expect(retrievedOriginal!.completedAt, isNotNull);

        // Verify the next instance date calculation was correct (before storage)
        expect(nextDate.hour, 0, reason: 'Calculated next instance should be all-day');
        expect(nextDate.minute, 0, reason: 'Calculated next instance should be all-day');
      });
    });

    group('Backward Compatibility Tests', () {
      test('should preserve time component for non-all-day recurring tasks', () async {
        // Arrange - Create a recurring task with a specific time
        final task = Task(
          id: 'compat-timed-1',
          createdDate: DateTime.utc(2024, 1, 15, 0, 0),
          title: '9AM Daily Task',
          completedAt: null,
          plannedDate: DateTime.utc(2024, 1, 15, 9, 30), // 9:30 AM
          recurrenceType: RecurrenceType.daily,
          recurrenceInterval: 1,
        );

        await taskRepository.add(task);

        // Act - Calculate next instance
        final nextDate = recurrenceService.calculateNextRecurrenceDate(
          task,
          DateTime.utc(2024, 1, 15, 9, 30),
        );

        // Assert - Verify time is preserved
        expect(nextDate.day, 16, reason: 'Should be next day');
        expect(nextDate.hour, 9, reason: 'Should preserve hour');
        expect(nextDate.minute, 30, reason: 'Should preserve minute');
      });
    });
  });
}
