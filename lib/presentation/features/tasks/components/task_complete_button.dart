import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskCompleteButton extends StatefulWidget {
  final String taskId;
  final bool isCompleted;
  final VoidCallback? onToggleCompleted;
  final Color? color;

  const TaskCompleteButton({
    super.key,
    required this.taskId,
    required this.isCompleted,
    this.onToggleCompleted,
    this.color,
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

    try {
      final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: widget.taskId),
      );

      final command = SaveTaskCommand(
        id: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        plannedDate: task.plannedDate,
        deadlineDate: task.deadlineDate,
        estimatedTime: task.estimatedTime,
        isCompleted: !_isCompleted,
      );

      // We'll update the UI first to make the user experience smoother
      setState(() {
        _isCompleted = !_isCompleted;
      });

      // Now perform the actual API call
      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      if (command.isCompleted) {
        _soundPlayer.play(SharedSounds.done);
      }

      // Notify the service about the completed task
      if (_isCompleted) {
        Future.delayed(const Duration(seconds: 3), () {
          _tasksService.notifyTaskCompleted(widget.taskId);
        });
      } else {
        _tasksService.notifyTaskUpdated(widget.taskId);
      }

      // Still call the callback if provided for backward compatibility
      widget.onToggleCompleted?.call();
    } on BusinessException catch (e) {
      // Revert UI state if there was an error
      setState(() {
        _isCompleted = !_isCompleted;
      });
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      // Revert UI state if there was an error
      setState(() {
        _isCompleted = !_isCompleted;
      });
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(TaskTranslationKeys.taskCompleteError));
      }
    } finally {
      // Always reset processing state
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: _isCompleted,
      onChanged: (_) => _toggleCompleteTask(context),
      activeColor: widget.color,
      shape: const CircleBorder(),
      side: BorderSide(color: widget.color ?? Colors.white, width: 2),
    );
  }
}
