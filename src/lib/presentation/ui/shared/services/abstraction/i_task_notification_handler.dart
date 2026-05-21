abstract class ITaskNotificationHandler {
  Future<void> handleNotificationTaskCompletion(String taskId);
}
