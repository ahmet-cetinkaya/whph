import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';

class TaskCompleteButton extends StatelessWidget {
  final int taskId;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;

  const TaskCompleteButton({
    super.key,
    required this.taskId,
    required this.isCompleted,
    required this.onToggleCompleted,
  });

  Future<void> _toggleCompleteTask(BuildContext context) async {
    final mediator = container.resolve<Mediator>();

    try {
      var task = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: taskId),
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
      onToggleCompleted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling task completion: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isCompleted ? Colors.green : null,
      ),
      onPressed: () => _toggleCompleteTask(context),
    );
  }
}
