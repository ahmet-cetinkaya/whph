import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

class TasksService extends ChangeNotifier implements ITaskEvents {
  TasksService([ITaskRecurrenceService? recurrenceService, Mediator? mediator, ILogger? logger]);

  final ValueNotifier<String?> onTaskCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskDeleted = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskTimeRecordUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTaskCompleted = ValueNotifier<String?>(null);

  @override
  void notifyTaskCreated(String taskId) {
    onTaskCreated.value = taskId;
    onTaskCreated.notifyListeners();
    notifyListeners();
  }

  @override
  void notifyTaskUpdated(String taskId) {
    onTaskUpdated.value = taskId;
    onTaskUpdated.notifyListeners();
    notifyListeners();
  }

  @override
  void notifyTaskDeleted(String taskId) {
    onTaskDeleted.value = taskId;
    onTaskDeleted.notifyListeners();
    notifyListeners();
  }

  @override
  void notifyTaskTimeRecordUpdated(String taskId) {
    onTaskTimeRecordUpdated.value = taskId;
    onTaskTimeRecordUpdated.notifyListeners();
    notifyTaskUpdated(taskId);
  }

  @override
  void notifyTaskCompleted(String taskId) {
    onTaskCompleted.value = taskId;
    onTaskCompleted.notifyListeners();
    notifyListeners();
  }

  void notifyRefresh() {
    onTaskCreated.value = null;
    onTaskUpdated.value = null;
    onTaskDeleted.value = null;
    onTaskTimeRecordUpdated.value = null;
    onTaskCompleted.value = null;
    onTaskCreated.notifyListeners();
    onTaskUpdated.notifyListeners();
    onTaskDeleted.notifyListeners();
    onTaskTimeRecordUpdated.notifyListeners();
    onTaskCompleted.notifyListeners();
    notifyListeners();
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
