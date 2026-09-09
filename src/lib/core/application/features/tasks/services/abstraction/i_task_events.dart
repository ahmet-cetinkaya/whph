abstract class ITaskEvents {
  void notifyTaskCreated(String taskId);
  void notifyTaskUpdated(String taskId);
  void notifyTaskDeleted(String taskId);
  void notifyTaskTimeRecordUpdated(String taskId);
  void notifyTaskCompleted(String taskId);
}
