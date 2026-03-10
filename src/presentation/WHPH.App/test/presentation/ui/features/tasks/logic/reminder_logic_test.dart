import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

// Logic copied from ReminderService for isolation testing
DateTime calculateTaskReminderTime(DateTime taskDate, ReminderTime reminderTime, [int? customOffset]) {
  switch (reminderTime) {
    case ReminderTime.atTime:
      return taskDate;
    case ReminderTime.fiveMinutesBefore:
      return taskDate.subtract(const Duration(minutes: 5));
    case ReminderTime.fifteenMinutesBefore:
      return taskDate.subtract(const Duration(minutes: 15));
    case ReminderTime.oneHourBefore:
      return taskDate.subtract(const Duration(hours: 1));
    case ReminderTime.oneDayBefore:
      return taskDate.subtract(const Duration(days: 1));
    case ReminderTime.custom:
      if (customOffset != null) {
        return taskDate.subtract(Duration(minutes: customOffset));
      }
      return taskDate; // Fallback if offset is missing
    case ReminderTime.none:
      return taskDate;
  }
}

void main() {
  group('Reminder Logic Test', () {
    test('Calculate custom reminder time correctly', () {
      final taskDate = DateTime(2023, 10, 27, 10, 0);

      // Test 30 minutes before
      final reminderTime30Min = calculateTaskReminderTime(taskDate, ReminderTime.custom, 30);
      expect(reminderTime30Min, DateTime(2023, 10, 27, 9, 30));

      // Test 2 hours (120 minutes) before
      final reminderTime2Hours = calculateTaskReminderTime(taskDate, ReminderTime.custom, 120);
      expect(reminderTime2Hours, DateTime(2023, 10, 27, 8, 0));

      // Test 1 day (1440 minutes) before
      final reminderTime1Day = calculateTaskReminderTime(taskDate, ReminderTime.custom, 1440);
      expect(reminderTime1Day, DateTime(2023, 10, 26, 10, 0));

      // Test fallback (null offset)
      final reminderTimeFallback = calculateTaskReminderTime(taskDate, ReminderTime.custom, null);
      expect(reminderTimeFallback, taskDate);
    });

    test('Calculate standard reminder times correctly', () {
      final taskDate = DateTime(2023, 10, 27, 10, 0);

      expect(calculateTaskReminderTime(taskDate, ReminderTime.atTime), taskDate);

      expect(calculateTaskReminderTime(taskDate, ReminderTime.fiveMinutesBefore),
          taskDate.subtract(const Duration(minutes: 5)));

      expect(
          calculateTaskReminderTime(taskDate, ReminderTime.oneHourBefore), taskDate.subtract(const Duration(hours: 1)));
    });
  });
}
