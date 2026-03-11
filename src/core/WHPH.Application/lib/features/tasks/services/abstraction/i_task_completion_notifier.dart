/// Interface for task completion notification service.
/// This abstraction allows the application layer to notify about task completions
/// without depending on presentation layer services.
abstract class ITaskCompletionNotifier {
  /// Notify listeners that a task has been completed.
  /// This triggers UI updates and recurring task creation.
  void notifyTaskCompleted(String taskId);
}
