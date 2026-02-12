import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/tasks/commands/save_task_command.dart';
import 'package:application/features/tasks/queries/get_task_query.dart';
import 'package:acore/acore.dart' show DateTimeHelper, ILogger;
import 'package:whph/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/main.dart';
import 'package:whph/features/tasks/services/tasks_service.dart';
import 'package:application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/utils/async_error_handler.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

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

    _logger.info('TaskCompleteButton: Toggling completion for task ${widget.taskId}');

    setState(() {
      _isProcessing = true;
    });

    // Store original completed state to revert in case of error
    final originalCompletedState = _isCompleted;

    // Update UI first for smoother user experience
    setState(() {
      _isCompleted = !_isCompleted;
    });

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.taskCompleteError),
      operation: () async {
        final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
          GetTaskQuery(id: widget.taskId),
        );

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

        // Perform the actual API call
        await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

        if (command.completedAt != null) {
          _soundManagerService.playTaskCompletion();
        }
      },
      onSuccess: () {
        // Notify the service about the completed task
        if (_isCompleted) {
          // Immediately notify task completion - the service handles async recurrence creation safely
          _tasksService.notifyTaskCompleted(widget.taskId);
          _tasksService.notifyTaskUpdated(widget.taskId);
          widget.onToggleCompleted?.call();
        } else {
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
        }
      },
    );

    // Always reset processing state
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
    _logger.info('TaskCompleteButton: Successfully toggled completion for task ${widget.taskId}');
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
