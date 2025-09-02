import 'package:flutter/foundation.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

class TasksService extends ChangeNotifier {
  final ITaskRecurrenceService _taskRecurrenceService;
  final Mediator _mediator;
  final ILogger _logger;

  TasksService(this._taskRecurrenceService, this._mediator, this._logger);

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
    _logger.debug('TasksService: notifyTaskCompleted called for task: $taskId');

    onTaskCompleted.value = taskId;
    onTaskCompleted.notifyListeners();

    // When a task is completed, check if it's a recurring task and create the next instance if needed
    // Handle this asynchronously but don't wait for completion to avoid blocking the UI
    _handleRecurringTaskCreation(taskId);
  }

  Future<void> _handleRecurringTaskCreation(String taskId) async {
    _logger.debug('TasksService: Starting recurring task creation workflow for $taskId');

    try {
      final nextTaskId = await _taskRecurrenceService.handleCompletedRecurringTask(taskId, _mediator);
      if (nextTaskId != null) {
        _logger.debug('TasksService: Successfully created next recurring task instance: $nextTaskId');
        // Notify about the newly created recurring task
        notifyTaskCreated(nextTaskId);
        _logger.debug('TasksService: Notified listeners about new recurring task: $nextTaskId');
      } else {
        _logger.debug(
            'TasksService: No next recurring task instance created for $taskId (task may not be recurring or reached limits)');
      }
    } catch (e) {
      _logger.error('TasksService: Failed to create recurring task instance for $taskId: $e');
      // Don't rethrow to avoid breaking the completion flow
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
