import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';

class TaskCompleteButton extends StatelessWidget {
  final Mediator mediator = container.resolve<Mediator>();

  final int taskId;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;

  TaskCompleteButton({super.key, required this.taskId, required this.isCompleted, required this.onToggleCompleted});

  Future<void> _toggleCompleteTask() async {
    var query = GetTaskQuery(id: taskId);
    var queryResponse = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);

    var command = SaveTaskCommand(
      id: queryResponse.id,
      title: queryResponse.title,
      description: queryResponse.description,
      topicId: queryResponse.topicId,
      priority: queryResponse.priority,
      plannedDate: queryResponse.plannedDate,
      deadlineDate: queryResponse.deadlineDate,
      estimatedTime: queryResponse.estimatedTime,
      elapsedTime: queryResponse.elapsedTime,
      isCompleted: !queryResponse.isCompleted,
    );
    await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
    onToggleCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Center(
          child: Icon(
        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isCompleted ? Colors.green : null,
      )),
      onPressed: _toggleCompleteTask,
    );
  }
}
