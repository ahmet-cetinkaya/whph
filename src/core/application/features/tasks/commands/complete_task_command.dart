import 'package:mediatr/mediatr.dart';
import 'package:application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:application/features/tasks/services/task_time_record_service.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/shared/constants/task_error_ids.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';

/// Command to complete a task by ID.
///
/// This command consolidates the task completion logic that was previously
/// duplicated across multiple locations (task_complete_button, notification services,
/// and various pages). By centralizing this logic, we ensure consistent behavior
/// and make maintenance easier.
///
/// The command:
/// 1. Fetches the task from the repository (not via Query - proper CQRS)
/// 2. Sets completedAt to now (UTC)
/// 3. Preserves all existing task properties
/// 4. Handles recurrence days via ITaskRecurrenceService
/// 5. Auto-adds time record if task has estimated time (matching SaveTaskCommand behavior)
/// 6. Notifies TasksService to trigger UI updates and recurring task creation
class CompleteTaskCommand implements IRequest<CompleteTaskCommandResponse> {
  /// The ID of the task to complete
  final String id;

  CompleteTaskCommand({required this.id});
}

class CompleteTaskCommandResponse {
  /// The ID of the completed task
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
    // Step 1: Fetch the task from repository (proper CQRS - not calling a Query)
    final task = await _taskRepository.getById(command.id);
    if (task == null) {
      throw BusinessException(
        'Task with id ${command.id} not found',
        TaskErrorIds.taskNotFound,
      );
    }

    // Step 2: Set completedAt to now (UTC)
    task.completedAt = DateTime.now().toUtc();

    // Update recurrence days if needed (preserves existing behavior)
    if (task.recurrenceType != RecurrenceType.none) {
      task.setRecurrenceDays(_recurrenceService.getRecurrenceDays(task));
    }

    // Step 3: Update the task in repository (proper CQRS - not calling another Command)
    await _taskRepository.update(task);

    // Step 4: Auto-add time record if task has estimated time (matching SaveTaskCommand behavior)
    // This ensures time tracking consistency whether completing via SaveTaskCommand or CompleteTaskCommand
    if (task.estimatedTime != null && task.estimatedTime! > 0) {
      // Check if there are already time records for this task
      final existingTimeRecords = await _taskTimeRecordRepository.getList(
        0, 1, // Only need to check if any exist
        customWhereFilter: CustomWhereFilter('task_id = ? AND deleted_date IS NULL', [task.id]),
      );

      // If no time records exist, create one with the estimated time
      if (existingTimeRecords.items.isEmpty) {
        final now = DateTime.now().toUtc();

        await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: _taskTimeRecordRepository,
          taskId: task.id,
          targetDate: now,
          durationToAdd: task.estimatedTime! * 60, // Convert minutes to seconds
        );
      }
    }

    // Step 5: Notify listeners about task completion
    // This triggers UI updates and recurring task creation
    // Note: This is a void method, so we don't await it
    _tasksService.notifyTaskCompleted(command.id);

    return CompleteTaskCommandResponse(taskId: command.id);
  }
}
