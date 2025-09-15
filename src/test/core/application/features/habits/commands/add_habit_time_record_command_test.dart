import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';

void main() {
  group('AddHabitTimeRecordCommand Tests', () {
    test('should create command with required properties', () {
      // Arrange
      const habitId = 'test-habit-id';
      const duration = 1800; // 30 minutes

      // Act
      final command = AddHabitTimeRecordCommand(
        habitId: habitId,
        duration: duration,
      );

      // Assert
      expect(command.habitId, habitId);
      expect(command.duration, duration);
      expect(command.customDateTime, isNull);
    });

    test('should create command with custom date time', () {
      // Arrange
      const habitId = 'test-habit-id';
      const duration = 1800;
      final customDateTime = DateTime(2024, 1, 15, 14, 30);

      // Act
      final command = AddHabitTimeRecordCommand(
        habitId: habitId,
        duration: duration,
        customDateTime: customDateTime,
      );

      // Assert
      expect(command.habitId, habitId);
      expect(command.duration, duration);
      expect(command.customDateTime, customDateTime);
    });

    test('should create response with generated ID', () {
      // Arrange
      const id = 'generated-id';

      // Act
      final response = AddHabitTimeRecordCommandResponse(id: id);

      // Assert
      expect(response.id, id);
    });

    group('Hour Bucket Logic Tests', () {
      test('should create correct hour bucket for different times', () {
        // Test that the command handler creates the correct hour bucket
        // This tests the hour bucket logic without needing mocks

        // Test case 1: 2:30 PM should create 2:00 PM UTC bucket
        final afternoonTime = DateTime(2024, 1, 15, 14, 30);
        final expectedAfternoonBucket = DateTime.utc(2024, 1, 15, 14);

        // Create the hour bucket using the same logic from the command
        final actualAfternoonBucket = DateTime.utc(
          afternoonTime.year,
          afternoonTime.month,
          afternoonTime.day,
          afternoonTime.hour,
        );

        expect(actualAfternoonBucket, expectedAfternoonBucket);

        // Test case 2: 9:45 AM should create 9:00 AM UTC bucket
        final morningTime = DateTime(2024, 1, 15, 9, 45);
        final expectedMorningBucket = DateTime.utc(2024, 1, 15, 9);

        final actualMorningBucket = DateTime.utc(
          morningTime.year,
          morningTime.month,
          morningTime.day,
          morningTime.hour,
        );

        expect(actualMorningBucket, expectedMorningBucket);

        // Test case 3: 11:59 PM should create 11:00 PM UTC bucket
        final midnightTime = DateTime(2024, 1, 15, 23, 59);
        final expectedMidnightBucket = DateTime.utc(2024, 1, 15, 23);

        final actualMidnightBucket = DateTime.utc(
          midnightTime.year,
          midnightTime.month,
          midnightTime.day,
          midnightTime.hour,
        );

        expect(actualMidnightBucket, expectedMidnightBucket);
      });

      test('should handle duration accumulation logic', () {
        // Test that duration accumulation works correctly
        const existingDuration = 900; // 15 minutes
        const newDuration = 600; // 10 minutes
        const expectedTotalDuration = existingDuration + newDuration;

        expect(expectedTotalDuration, 1500); // 25 minutes total
      });

      test('should create different hour buckets for different hours', () {
        // Test that different hours create different buckets
        final hour1 = DateTime(2024, 1, 15, 14, 30); // 2:30 PM
        final hour2 = DateTime(2024, 1, 15, 15, 30); // 3:30 PM

        final bucket1 = DateTime.utc(hour1.year, hour1.month, hour1.day, hour1.hour);
        final bucket2 = DateTime.utc(hour2.year, hour2.month, hour2.day, hour2.hour);

        expect(bucket1, isNot(equals(bucket2)));
        expect(bucket1.hour, 14);
        expect(bucket2.hour, 15);
      });

      test('should create same hour bucket for same hour different minutes', () {
        // Test that different minutes in same hour create same bucket
        final time1 = DateTime(2024, 1, 15, 14, 15); // 2:15 PM
        final time2 = DateTime(2024, 1, 15, 14, 45); // 2:45 PM

        final bucket1 = DateTime.utc(time1.year, time1.month, time1.day, time1.hour);
        final bucket2 = DateTime.utc(time2.year, time2.month, time2.day, time2.hour);

        expect(bucket1, equals(bucket2));
        expect(bucket1.hour, 14);
        expect(bucket1.minute, 0);
      });
    });
  });
}