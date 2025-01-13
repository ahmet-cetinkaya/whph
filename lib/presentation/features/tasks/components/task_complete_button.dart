import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

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
        elapsedTime: task.elapsedTime,
        isCompleted: !task.isCompleted,
      );

      await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      if (command.isCompleted) _soundPlayer.play(SharedSounds.done);
      widget.onToggleCompleted();
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: 'Unexpected error occurred while saving task.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: widget.isCompleted,
      onChanged: (_) => _toggleCompleteTask(context),
      activeColor: widget.color,
      shape: const CircleBorder(),
      side: BorderSide(
        color: widget.color ?? Colors.white,
        width: 2,
      ),
    );
  }
}
