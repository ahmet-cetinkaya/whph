import 'package:whph/core/domain/features/tasks/task.dart';

class TaskConstants {
  // Default values
  static const int defaultEstimatedTime = 20;
  static const ReminderTime defaultReminderTime = ReminderTime.atTime;
  static const bool defaultSkipQuickAdd = false;

  // Prevent instantiation
  TaskConstants._();
}
