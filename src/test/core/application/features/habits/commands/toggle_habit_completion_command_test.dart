import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';

void main() {
  group('ToggleHabitCompletionCommand Tests', () {
    test('should create command with required properties', () {
      // Arrange
      const habitId = 'test-habit-id';
      final date = DateTime(2024, 1, 15);

      // Act
      final command = ToggleHabitCompletionCommand(
        habitId: habitId,
        date: date,
      );

      // Assert
      expect(command.habitId, habitId);
      expect(command.date, date);
      expect(command.useIncrementalBehavior, false); // default value
    });

    test('should create command with incremental behavior flag', () {
      // Arrange
      const habitId = 'test-habit-id';
      final date = DateTime(2024, 1, 15);
      const useIncrementalBehavior = true;

      // Act
      final command = ToggleHabitCompletionCommand(
        habitId: habitId,
        date: date,
        useIncrementalBehavior: useIncrementalBehavior,
      );

      // Assert
      expect(command.habitId, habitId);
      expect(command.date, date);
      expect(command.useIncrementalBehavior, useIncrementalBehavior);
    });

    test('should create response', () {
      // Act
      final response = ToggleHabitCompletionCommandResponse();

      // Assert
      expect(response, isNotNull);
    });
  });
}
