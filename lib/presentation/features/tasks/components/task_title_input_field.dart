import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/main.dart';

class TaskTitleInputField extends StatefulWidget {
  final int taskId;

  const TaskTitleInputField({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskTitleInputField> createState() => _TaskTitleInputFieldState();
}

class _TaskTitleInputFieldState extends State<TaskTitleInputField> {
  final Mediator _mediator = container.resolve<Mediator>();
  final TextEditingController _titleController = TextEditingController();

  GetTaskQueryResponse? task;

  @override
  void initState() {
    super.initState();
    _fetchTask();
  }

  Future<void> _fetchTask() async {
    var query = GetTaskQuery(id: widget.taskId);
    var response = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
    setState(() {
      task = response;
      _titleController.text = task!.title;
    });
  }

  void _updateTask() {
    var command = SaveTaskCommand(
      id: widget.taskId,
      title: _titleController.text,
      deadlineDate: task!.deadlineDate,
      description: task!.description,
      elapsedTime: task!.elapsedTime,
      estimatedTime: task!.estimatedTime,
      isCompleted: task!.isCompleted,
      plannedDate: task!.plannedDate,
      priority: task!.priority,
    );

    _mediator.send(command);
  }

  @override
  Widget build(BuildContext context) {
    return task == null
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              TaskCompleteButton(
                taskId: widget.taskId,
                isCompleted: task!.isCompleted,
                onToggleCompleted: _fetchTask,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  onChanged: (value) {
                    _updateTask();
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter task title',
                  ),
                ),
              ),
            ],
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
