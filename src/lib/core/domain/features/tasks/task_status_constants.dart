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

  /// The done role is fixed to the single built-in done status, so completion
  /// can be derived from a status id without a repository lookup.
  static bool isDoneStatusId(String? statusId) => statusId == doneId;

  TaskStatusConstants._();
}
