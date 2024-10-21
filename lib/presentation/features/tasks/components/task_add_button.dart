import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/main.dart';

class TaskAddButton extends StatefulWidget {
  final Function(String taskId)? onTaskCreated;

  const TaskAddButton({super.key, this.onTaskCreated});

  @override
  State<TaskAddButton> createState() => _TaskAddButtonState();
}

class _TaskAddButtonState extends State<TaskAddButton> {
  final Mediator mediator = container.resolve<Mediator>();
  bool isLoading = false;

  Future<void> _createTask(BuildContext context) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      var command = SaveTaskCommand(
        title: "New Task",
        description: "# Steps\n - [ ] Step 1\n - [ ] Step 2\n# Notes\n",
      );
      var response = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      if (widget.onTaskCreated != null) widget.onTaskCreated!(response.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create task. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _createTask(context),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add),
    );
  }
}
