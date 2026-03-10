import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

class TasksService extends ChangeNotifier {
  final ITaskRecurrenceService _taskRecurrenceService;
  final Mediator _mediator;
  final ILogger _logger;

  /// Tracks task IDs currently being processed for recurrence creation
  /// to prevent duplicate recurring task generation from rapid consecutive completions.
  final Set<String> _processingRecurrenceTasks = {};

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
    onTaskCompleted.value = taskId;
    onTaskCompleted.notifyListeners();

    // When a task is completed, check if it's a recurring task and create the next instance if needed
    // Handle this asynchronously but don't wait for completion to avoid blocking the UI
    _handleRecurringTaskCreation(taskId);
  }

  Future<void> _handleRecurringTaskCreation(String taskId) async {
    // Prevent concurrent processing for the same task (race condition fix)
    if (_processingRecurrenceTasks.contains(taskId)) {
      return;
    }

    _processingRecurrenceTasks.add(taskId);

    try {
      // Add retry logic for robustness
      int retryCount = 0;
      const maxRetries = 3;
      bool success = false;

      while (!success && retryCount < maxRetries) {
        try {
          final nextTaskId = await _taskRecurrenceService.handleCompletedRecurringTask(taskId, _mediator);
          if (nextTaskId != null) {
            // Notify about the newly created recurring task
            notifyTaskCreated(nextTaskId);
          }
          success = true;
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            _logger.warning('TasksService: Retry $retryCount/$maxRetries for task $taskId after error: $e');
            await Future.delayed(Duration(milliseconds: 500 * retryCount)); // Exponential backoff
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      _logger.error('TasksService: Failed to create recurring task instance for $taskId after multiple retries: $e');
    } finally {
      _processingRecurrenceTasks.remove(taskId);
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
