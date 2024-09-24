import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/main.dart';

class HabitAddButton extends StatefulWidget {
  final Function(int habitId)? onHabitCreated; // Yeni habit id'sini geri döndürecek callback

  const HabitAddButton({super.key, this.onHabitCreated});

  @override
  State<HabitAddButton> createState() => _HabitAddButtonState();
}

class _HabitAddButtonState extends State<HabitAddButton> {
  final Mediator mediator = container.resolve<Mediator>();
  bool isLoading = false;

  Future<void> _createHabit(BuildContext context) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      var command = SaveHabitCommand(
        name: "New Habit",
        description: "# Goals\n - [ ] Goal 1\n - [ ] Goal 2\n# Notes\n",
      );
      var response = await mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

      if (widget.onHabitCreated != null) widget.onHabitCreated!(response.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create habit. Please try again.'),
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
      onPressed: () => _createHabit(context),
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
