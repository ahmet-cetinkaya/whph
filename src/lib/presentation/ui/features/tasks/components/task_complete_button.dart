import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:acore/acore.dart' show DateTimeHelper, ILogger;
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TaskCompleteButton extends StatefulWidget {
  final String taskId;
  final bool isCompleted;
  final VoidCallback? onToggleCompleted;
  final Color? color;
  final double subTasksCompletionPercentage;
  final double size;

  const TaskCompleteButton({
    super.key,
    required this.taskId,
    required this.isCompleted,
    this.onToggleCompleted,
    this.color,
    this.subTasksCompletionPercentage = 0.0,
    this.size = AppTheme.buttonSize2XSmall,
  });

  @override
  State<TaskCompleteButton> createState() => _TaskCompleteButtonState();
}

class _TaskCompleteButtonState extends State<TaskCompleteButton> {
  final _mediator = container.resolve<Mediator>();
  final _soundManagerService = container.resolve<ISoundManagerService>();
  final _translationService = container.resolve<ITranslationService>();
  final _tasksService = container.resolve<TasksService>();
  final _recurrenceService = container.resolve<ITaskRecurrenceService>();
  final _logger = container.resolve<ILogger>();
  bool _isCompleted = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.isCompleted;
  }

  @override
  void didUpdateWidget(TaskCompleteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted != widget.isCompleted) {
      _isCompleted = widget.isCompleted;
    }
  }

  Future<void> _toggleCompleteTask(BuildContext context) async {
    // Prevent multiple rapid taps
    if (_isProcessing) return;

    _logger.debug('TaskCompleteButton: Toggling completion for task ${widget.taskId}');
    _logger.debug('TaskCompleteButton: Current state - isCompleted: $_isCompleted, isProcessing: $_isProcessing');

    setState(() {
      _isProcessing = true;
    });

    // Store original completed state to revert in case of error
    final originalCompletedState = _isCompleted;

    // Update UI first for smoother user experience
    setState(() {
      _isCompleted = !_isCompleted;
    });

    _logger.debug('TaskCompleteButton: Updated UI state to ${_isCompleted ? "completed" : "not completed"}');

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.taskCompleteError),
      operation: () async {
        _logger.debug('TaskCompleteButton: Fetching task details for ${widget.taskId}');
        final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
          GetTaskQuery(id: widget.taskId),
        );

        _logger.debug('TaskCompleteButton: Retrieved task ${task.id} with recurrence type: ${task.recurrenceType}');
        _logger.debug(
            'TaskCompleteButton: Task recurrence settings - Interval: ${task.recurrenceInterval}, StartDate: ${task.recurrenceStartDate}, EndDate: ${task.recurrenceEndDate}, Count: ${task.recurrenceCount}');

        final command = SaveTaskCommand(
          id: task.id,
          title: task.title,
          description: task.description,
          priority: task.priority,
          plannedDate: task.plannedDate != null ? DateTimeHelper.toUtcDateTime(task.plannedDate!) : null,
          deadlineDate: task.deadlineDate != null ? DateTimeHelper.toUtcDateTime(task.deadlineDate!) : null,
          estimatedTime: task.estimatedTime,
          completedAt: !originalCompletedState ? DateTime.now().toUtc() : null,
          plannedDateReminderTime: task.plannedDateReminderTime,
          deadlineDateReminderTime: task.deadlineDateReminderTime,
          recurrenceType: task.recurrenceType,
          recurrenceInterval: task.recurrenceInterval,
          recurrenceDays: _recurrenceService.getRecurrenceDays(task),
          recurrenceStartDate: task.recurrenceStartDate,
          recurrenceEndDate: task.recurrenceEndDate,
          recurrenceCount: task.recurrenceCount,
        );

        _logger.debug('TaskCompleteButton: Saving task with completedAt: ${command.completedAt}');
        _logger.debug(
            'TaskCompleteButton: Task planned date before save: ${task.plannedDate} -> after UTC conversion: ${command.plannedDate}');

        // Perform the actual API call
        await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

        _logger.debug('TaskCompleteButton: Task save completed successfully');

        if (command.completedAt != null) {
          _soundManagerService.playTaskCompletion();
        }
      },
      onSuccess: () {
        // Notify the service about the completed task
        if (_isCompleted) {
          _logger.debug('TaskCompleteButton: Task ${widget.taskId} completed successfully, notifying services');
          // Immediately notify task completion - the service handles async recurrence creation safely
          _tasksService.notifyTaskCompleted(widget.taskId);
          _tasksService.notifyTaskUpdated(widget.taskId);
          widget.onToggleCompleted?.call();
          _logger.debug('TaskCompleteButton: Completed task notifications sent for ${widget.taskId}');
        } else {
          _logger.debug('TaskCompleteButton: Task ${widget.taskId} marked as not completed');
          _tasksService.notifyTaskUpdated(widget.taskId);
          widget.onToggleCompleted?.call();
        }
      },
      onError: (error) {
        _logger.error('TaskCompleteButton: Failed to toggle task completion for ${widget.taskId}: $error');
        // Revert UI state if there was an error
        if (mounted) {
          setState(() {
            _isCompleted = originalCompletedState;
          });
          _logger.debug('TaskCompleteButton: Reverted UI state back to $originalCompletedState');
        }
      },
    );

    // Always reset processing state
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? Theme.of(context).colorScheme.primary;
    final borderColor = widget.color ?? AppTheme.borderColor;
    const double hoverSize = AppTheme.buttonSizeMedium;

    return SizedBox(
      width: hoverSize,
      height: hoverSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
              color: _isCompleted ? primaryColor : Colors.transparent,
            ),
          ),

          Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: () => _toggleCompleteTask(context),
              containedInkWell: false,
              highlightShape: BoxShape.circle,
              radius: hoverSize / 2,
              child: SizedBox(
                width: hoverSize,
                height: hoverSize,
                child: Center(
                  child: !_isCompleted && widget.subTasksCompletionPercentage > 0
                      ? SizedBox(
                          width: widget.size,
                          height: widget.size,
                          child: CircularProgressIndicator(
                            value: widget.subTasksCompletionPercentage / 100,
                            strokeWidth: AppTheme.sizeXSmall,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          if (_isCompleted)
            IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.check,
                  size: widget.size * 0.7,
                  color: AppTheme.surface1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
