import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';

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
  final String? recurringTaskId;

  CompleteTaskCommandResponse({required this.taskId, this.recurringTaskId});
}

class CompleteTaskCommandHandler implements IRequestHandler<CompleteTaskCommand, CompleteTaskCommandResponse> {
  final ITaskRepository _taskRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ITaskRecurrenceService _recurrenceService;
  final Mediator _mediator;
  final ITaskEvents _taskEvents;

  CompleteTaskCommandHandler(
    this._taskRepository,
    this._taskTimeRecordRepository,
    this._recurrenceService,
    this._mediator,
    this._taskEvents,
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
    if (task.isCompleted) {
      return CompleteTaskCommandResponse(taskId: command.id);
    }

    final completedTask = task.copyWith(
      completedAt: DateTime.now().toUtc(),
      statusId: TaskStatusConstants.doneId,
    );

    if (completedTask.recurrenceType != RecurrenceType.none) {
      completedTask.setRecurrenceDays(_recurrenceService.getRecurrenceDays(completedTask));
    }

    await _taskRepository.update(completedTask);

    // Auto-add time record if task has estimated time but no existing time records
    // (matching SaveTaskCommand behavior for consistency)
    if (completedTask.estimatedTime != null && completedTask.estimatedTime! > 0) {
      final existingTimeRecords = await _taskTimeRecordRepository.getList(
        0,
        1,
        customWhereFilter: CustomWhereFilter('task_id = ? AND deleted_date IS NULL', [completedTask.id]),
      );

      if (existingTimeRecords.items.isEmpty) {
        final now = DateTime.now().toUtc();

        await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: _taskTimeRecordRepository,
          taskId: completedTask.id,
          targetDate: now,
          durationToAdd: completedTask.estimatedTime! * 60,
        );
      }
    }

    final recurringTaskId = await _recurrenceService.handleCompletedRecurringTask(command.id, _mediator);
    _taskEvents.notifyTaskCompleted(command.id);

    return CompleteTaskCommandResponse(taskId: command.id, recurringTaskId: recurringTaskId);
  }
}
