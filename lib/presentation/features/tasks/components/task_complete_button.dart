import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskCompleteButton extends StatefulWidget {
  final String taskId;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;
  final Color? color;

  const TaskCompleteButton({
    super.key,
    required this.taskId,
    required this.isCompleted,
    required this.onToggleCompleted,
    this.color,
  });

  @override
  State<TaskCompleteButton> createState() => _TaskCompleteButtonState();
}

class _TaskCompleteButtonState extends State<TaskCompleteButton> {
  final ISoundPlayer _soundPlayer = container.resolve<ISoundPlayer>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  bool _isCompleted = false;

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
    final mediator = container.resolve<Mediator>();

    try {
      var task = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: widget.taskId),
      );

      var command = SaveTaskCommand(
        id: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        plannedDate: task.plannedDate,
        deadlineDate: task.deadlineDate,
        estimatedTime: task.estimatedTime,
        isCompleted: !_isCompleted,
      );

      await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      if (command.isCompleted) {
        _soundPlayer.play(SharedSounds.done);
      }

      setState(() {
        _isCompleted = !_isCompleted;
      });

      widget.onToggleCompleted();
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(TaskTranslationKeys.taskCompleteError));
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
