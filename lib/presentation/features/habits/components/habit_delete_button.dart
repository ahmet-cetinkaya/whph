import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/delete_habit_command.dart';
import 'package:whph/main.dart';

class HabitDeleteButton extends StatefulWidget {
  final String habitId;
  final VoidCallback? onDeleteSuccess;
  Color? buttonColor;
  Color? buttonBackgroundColor;

  HabitDeleteButton({
    super.key,
    required this.habitId,
    this.onDeleteSuccess,
    this.buttonColor,
    this.buttonBackgroundColor,
  });

  @override
  State<HabitDeleteButton> createState() => _HabitDeleteButtonState();
}

class _HabitDeleteButtonState extends State<HabitDeleteButton> {
  final Mediator mediator = container.resolve<Mediator>();

  Future<void> _deleteHabit(BuildContext context) async {
    try {
      var command = DeleteHabitCommand(id: widget.habitId);
      await mediator.send(command);

      if (widget.onDeleteSuccess != null) {
        widget.onDeleteSuccess!();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete habit. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this habit?'),
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

    if (confirmed == true && context.mounted) _deleteHabit(context);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _confirmDelete(context),
      icon: const Icon(Icons.delete),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
