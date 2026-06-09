class TaskStatusConstants {
  /// Fixed ids for the seeded built-in statuses. Shared across all devices so
  /// sync never duplicates the built-ins.
  static const String todoId = 'task-status-builtin-todo';
  static const String doneId = 'task-status-builtin-done';

  /// Default colors seeded for the built-in statuses (hex, no leading '#').
  static const String todoColor = '9E9E9E'; // grey
  static const String doneColor = '4CAF50'; // green

  /// Seed order for the built-in statuses.
  static const double todoOrder = 0.0;
  static const double doneOrder = 1.0;

  static bool isTodoStatusId(String? statusId) => statusId == todoId;
  static bool isDoneStatusId(String? statusId) => statusId == doneId;
  static bool isBuiltinStatusId(String? statusId) => isTodoStatusId(statusId) || isDoneStatusId(statusId);

  TaskStatusConstants._();
}
