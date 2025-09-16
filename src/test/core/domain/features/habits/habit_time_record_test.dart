import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';

void main() {
  group('HabitTimeRecord Domain Entity Tests', () {
    test('should create HabitTimeRecord with correct properties', () {
      // Arrange
      const id = 'test-id';
      const habitId = 'habit-123';
      const duration = 1800; // 30 minutes
      final createdDate = DateTime.utc(2024, 1, 15, 14);

      // Act
      final record = HabitTimeRecord(
        id: id,
        habitId: habitId,
        duration: duration,
        createdDate: createdDate,
      );

      // Assert
      expect(record.id, id);
      expect(record.habitId, habitId);
      expect(record.duration, duration);
      expect(record.createdDate, createdDate);
      expect(record.modifiedDate, isNull);
      expect(record.deletedDate, isNull);
    });

    test('should create HabitTimeRecord with optional properties', () {
      // Arrange
      const id = 'test-id';
      const habitId = 'habit-123';
      const duration = 1800;
      final createdDate = DateTime.utc(2024, 1, 15, 14);
      final modifiedDate = DateTime.utc(2024, 1, 15, 15);

      // Act
      final record = HabitTimeRecord(
        id: id,
        habitId: habitId,
        duration: duration,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
      );

      // Assert
      expect(record.modifiedDate, modifiedDate);
      expect(record.deletedDate, isNull);
    });

    test('should support JSON serialization', () {
      // Arrange
      final record = HabitTimeRecord(
        id: 'test-id',
        habitId: 'habit-123',
        duration: 1800,
        createdDate: DateTime.utc(2024, 1, 15, 14),
      );

      // Act
      final json = record.toJson();
      final fromJson = HabitTimeRecord.fromJson(json);

      // Assert
      expect(fromJson.id, record.id);
      expect(fromJson.habitId, record.habitId);
      expect(fromJson.duration, record.duration);
      expect(fromJson.createdDate, record.createdDate);
    });

    test('should handle different duration values', () {
      // Test various duration scenarios
      final testCases = [
        0, // No time
        60, // 1 minute
        3600, // 1 hour
        7200, // 2 hours
        86400, // 24 hours
      ];

      for (final duration in testCases) {
        final record = HabitTimeRecord(
          id: 'test-$duration',
          habitId: 'habit-123',
          duration: duration,
          createdDate: DateTime.utc(2024, 1, 15, 14),
        );

        expect(record.duration, duration);
        expect(record.duration, greaterThanOrEqualTo(0));
      }
    });
  });
}
