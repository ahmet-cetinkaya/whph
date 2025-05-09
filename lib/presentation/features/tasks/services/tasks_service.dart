import 'package:flutter/foundation.dart';

class TasksService extends ChangeNotifier {
  // Event listeners for task-related events - keeping nullable for the value
  final ValueNotifier<String?> onTaskCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskDeleted = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskTimeRecordUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskCompleted = ValueNotifier<String?>(null);

  void notifyTaskCreated(String taskId) {
    onTaskCreated.value = taskId;
    onTaskCreated.notifyListeners();
  }

  void notifyTaskUpdated(String taskId) {
    onTaskUpdated.value = taskId;
    onTaskUpdated.notifyListeners();
  }

  void notifyTaskDeleted(String taskId) {
    onTaskDeleted.value = taskId;
    onTaskDeleted.notifyListeners();
  }

  void notifyTaskTimeRecordUpdated(String taskId) {
    onTaskTimeRecordUpdated.value = taskId;
    onTaskTimeRecordUpdated.notifyListeners();
  }

  void notifyTaskCompleted(String taskId) {
    onTaskCompleted.value = taskId;
    onTaskCompleted.notifyListeners();
  }

  @override
  void dispose() {
    onTaskCreated.dispose();
    onTaskUpdated.dispose();
    onTaskDeleted.dispose();
    onTaskTimeRecordUpdated.dispose();
    onTaskCompleted.dispose();
    super.dispose();
  }
}
