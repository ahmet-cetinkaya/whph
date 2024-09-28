import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/delete_task_command.dart';
import 'package:whph/main.dart';

class TaskDeleteButton extends StatefulWidget {
  final int taskId;
  final VoidCallback? onDeleteSuccess;

  const TaskDeleteButton({
    super.key,
    required this.taskId,
    this.onDeleteSuccess,
  });

  @override
  State<TaskDeleteButton> createState() => _TaskDeleteButtonState();
}

class _TaskDeleteButtonState extends State<TaskDeleteButton> {
  bool isLoading = false;

  Future<void> _deleteTask(BuildContext context) async {
    final Mediator mediator = container.resolve<Mediator>();

    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      var command = DeleteTaskCommand(id: widget.taskId);
      await mediator.send(command);

      if (widget.onDeleteSuccess != null) {
        widget.onDeleteSuccess!();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete task. Please try again.'),
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

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) _deleteTask(context);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _confirmDelete(context),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            )
          : const Icon(Icons.delete),
    );
  }
}
