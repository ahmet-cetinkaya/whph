import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';

class TaskForm extends StatefulWidget {
  final Mediator mediator;
  final VoidCallback onTaskAdded;

  const TaskForm({
    super.key,
    required this.mediator,
    required this.onTaskAdded,
  });

  @override
  _TaskFormState createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final TextEditingController _taskTitleController = TextEditingController();

  Future<void> _addTask() async {
    final String title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    var command = SaveTaskCommand(title: title);
    await widget.mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

    _taskTitleController.clear();
    widget.onTaskAdded(); // Notify that a task has been added
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _taskTitleController,
              decoration: const InputDecoration(
                hintText: 'Enter task title',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTask,
          ),
        ],
      ),
    );
  }
}
