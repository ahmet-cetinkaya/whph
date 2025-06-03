import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/corePackages/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_sounds.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';

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
  final _soundPlayer = container.resolve<ISoundPlayer>();
  final _translationService = container.resolve<ITranslationService>();
  final _tasksService = container.resolve<TasksService>();
  bool _isCompleted = false;
  bool _isProcessing = false; // Flag to prevent multiple rapid taps

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
          isCompleted: !originalCompletedState,
          plannedDateReminderTime: task.plannedDateReminderTime,
          deadlineDateReminderTime: task.deadlineDateReminderTime,
        );

        // Perform the actual API call
        await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

        if (command.isCompleted) {
          _soundPlayer.play(SharedSounds.done);
        }
      },
      onSuccess: () {
        // Notify the service about the completed task
        if (_isCompleted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _tasksService.notifyTaskCompleted(widget.taskId);
            _tasksService.notifyTaskUpdated(widget.taskId);
            widget.onToggleCompleted?.call();
          });
        } else {
          _tasksService.notifyTaskUpdated(widget.taskId);
          widget.onToggleCompleted?.call();
        }
      },
      onError: (_) {
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
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => _toggleCompleteTask(context),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // Background circle
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.borderColor,
                    width: 2,
                  ),
                  color: _isCompleted ? primaryColor : Colors.transparent,
                ),
              ),

              // Progress ring for subtasks (only show if not completed and has subtask progress)
              if (!_isCompleted && widget.subTasksCompletionPercentage > 0)
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: widget.subTasksCompletionPercentage / 100,
                    strokeWidth: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),

              // Checkmark icon when completed
              if (_isCompleted)
                Center(
                  child: Icon(
                    Icons.check,
                    size: widget.size * 0.7,
                    color: AppTheme.surface1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
