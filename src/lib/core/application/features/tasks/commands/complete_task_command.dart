import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';

/// Command to complete a task by ID.
///
/// Consolidates task completion logic previously duplicated across UI and notification code.
/// Handles: completion, recurrence, auto time records, and UI notification.
class CompleteTaskCommand implements IRequest<CompleteTaskCommandResponse> {
  final String id;

  CompleteTaskCommand({required this.id});
}

class CompleteTaskCommandResponse {
  final String taskId;

  CompleteTaskCommandResponse({required this.taskId});
}

class CompleteTaskCommandHandler implements IRequestHandler<CompleteTaskCommand, CompleteTaskCommandResponse> {
  final ITaskRepository _taskRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ITaskRecurrenceService _recurrenceService;
  final TasksService _tasksService;

  CompleteTaskCommandHandler(
    this._taskRepository,
    this._taskTimeRecordRepository,
    this._recurrenceService,
    this._tasksService,
  );

  @override
  Future<CompleteTaskCommandResponse> call(CompleteTaskCommand command) async {
    final task = await _taskRepository.getById(command.id);
    if (task == null) {
      throw BusinessException(
        'Task with id ${command.id} not found',
        TaskErrorIds.taskNotFound,
      );
    }

    task.completedAt = DateTime.now().toUtc();
    task.statusId = TaskStatusConstants.doneId;

    if (task.recurrenceType != RecurrenceType.none) {
      task.setRecurrenceDays(_recurrenceService.getRecurrenceDays(task));
    }

    await _taskRepository.update(task);

    // Auto-add time record if task has estimated time but no existing time records
    // (matching SaveTaskCommand behavior for consistency)
    if (task.estimatedTime != null && task.estimatedTime! > 0) {
      final existingTimeRecords = await _taskTimeRecordRepository.getList(
        0,
        1,
        customWhereFilter: CustomWhereFilter('task_id = ? AND deleted_date IS NULL', [task.id]),
      );

      if (existingTimeRecords.items.isEmpty) {
        final now = DateTime.now().toUtc();

        await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: _taskTimeRecordRepository,
          taskId: task.id,
          targetDate: now,
          durationToAdd: task.estimatedTime! * 60,
        );
      }
    }

    // Notify UI to update and trigger recurring task creation
    _tasksService.notifyTaskCompleted(command.id);

    return CompleteTaskCommandResponse(taskId: command.id);
  }
}
