import 'package:flutter/foundation.dart';
import 'package:whph/main.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:mediatr/mediatr.dart';

class TasksService extends ChangeNotifier {
  final ITaskRecurrenceService _taskRecurrenceService = container.resolve<ITaskRecurrenceService>();
  final Mediator _mediator = container.resolve<Mediator>();

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

  void notifyTaskCompleted(String taskId) async {
    if (kDebugMode) debugPrint('🔔 TasksService: notifyTaskCompleted called for task: $taskId');

    onTaskCompleted.value = taskId;
    onTaskCompleted.notifyListeners();

    // When a task is completed, check if it's a recurring task and create the next instance if needed
    final nextTaskId = await _taskRecurrenceService.handleCompletedRecurringTask(taskId, _mediator);
    if (nextTaskId != null) {
      // Notify about the newly created recurring task
      notifyTaskCreated(nextTaskId);
    }
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
