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
  group('TaskRecurrenceService Comparative Tests', () {
    late TaskRecurrenceService service;

    setUp(() {
      service = TaskRecurrenceService(MockLogger(), MockTaskRepository());
    });

    test('Legacy Daily vs Config Daily', () {
      final baseTask = Task(
        id: 'legacy',
        title: 'Legacy',
        createdDate: DateTime(2024, 1, 1),
        completedAt: null,
      );

      final legacyTask = baseTask.copyWith(
        recurrenceType: RecurrenceType.daily,
        recurrenceInterval: 1,
      );

      final configTask = baseTask.copyWith(
        // RecurrenceType left as none/default or ignored by service logic
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          interval: 1,
        ),
      );

      final currentDate = DateTime(2024, 1, 1);
      final legacyNext = service.calculateNextRecurrenceDate(legacyTask, currentDate);
      final configNext = service.calculateNextRecurrenceDate(configTask, currentDate);

      // Both should be Jan 2
      expect(legacyNext, equals(configNext));
      expect(legacyNext, equals(DateTime(2024, 1, 2)));
    });

    test('Legacy Weekly vs Config Weekly', () {
      final baseTask = Task(
        id: 'legacy',
        title: 'Legacy',
        createdDate: DateTime(2024, 1, 1), // Monday
        completedAt: null,
      );

      final legacyTask = baseTask.copyWith(
        recurrenceType: RecurrenceType.weekly,
        recurrenceInterval: 1,
      );

      final configTask = baseTask.copyWith(
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.weekly,
          interval: 1,
        ),
      );

      final currentDate = DateTime(2024, 1, 1); // Monday
      final legacyNext = service.calculateNextRecurrenceDate(legacyTask, currentDate);
      final configNext = service.calculateNextRecurrenceDate(configTask, currentDate);

      // Both should be Jan 8 (Monday + 7 days)
      expect(legacyNext, equals(configNext));
      expect(legacyNext, equals(DateTime(2024, 1, 8)));
    });

    test('Regenerate Policy: Planned vs Completion Date', () {
      final baseTask = Task(
        id: 'task',
        title: 'Task',
        createdDate: DateTime(2024, 1, 1),
        plannedDate: DateTime(2024, 1, 1), // Planned for Jan 1
      );

      // Scenario: Task was planned for Jan 1, but completed on Jan 5.
      final completionDate = DateTime(2024, 1, 5);

      // 1. From Planned Date (Standard)
      final plannedPolicyTask = baseTask.copyWith(
        // We set completedAt to simulate completion state
        completedAt: completionDate,
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          interval: 1,
          fromPolicy: RecurrenceFromPolicy.plannedDate,
        ),
      );

      // 2. From Completion Date (Regenerate)
      final completionPolicyTask = baseTask.copyWith(
        completedAt: completionDate,
        recurrenceConfiguration: RecurrenceConfiguration(
          frequency: RecurrenceFrequency.daily,
          interval: 1,
          fromPolicy: RecurrenceFromPolicy.completionDate,
        ),
      );

      // We use the testing helper or just calculateNextRecurrenceDate directly?
      // _calculateNextDates(task) (exposed as calculateNextDatesForTesting) is what uses the policy logic!
      // calculateNextRecurrenceDate only calculates "Next Date based on a given Anchor".
      // We need to test the "Anchor Selection" logic which is in _calculateNextDates.

      final plannedPolicyResult = service.calculateNextDatesForTesting(plannedPolicyTask);
      final completionPolicyResult = service.calculateNextDatesForTesting(completionPolicyTask);

      // Planned Policy: Anchor = Planned (Jan 1). Next = Jan 2.
      expect(plannedPolicyResult.plannedDate, equals(DateTime(2024, 1, 2)));

      // Completion Policy: Anchor = Completed (Jan 5). Next = Jan 6.
      expect(completionPolicyResult.plannedDate, equals(DateTime(2024, 1, 6)));

      expect(plannedPolicyResult.plannedDate, isNot(equals(completionPolicyResult.plannedDate)));
    });
  });
}
