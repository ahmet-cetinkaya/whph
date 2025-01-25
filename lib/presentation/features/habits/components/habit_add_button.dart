import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class HabitAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String habitId)? onHabitCreated;

  const HabitAddButton({super.key, this.buttonColor, this.buttonBackgroundColor, this.onHabitCreated});

  @override
  State<HabitAddButton> createState() => _HabitAddButtonState();
}

class _HabitAddButtonState extends State<HabitAddButton> {
  final Mediator mediator = container.resolve<Mediator>();

  Future<void> _createHabit(BuildContext context) async {
    try {
      var command = SaveHabitCommand(
        name: "New Habit",
        description: "",
      );
      var response = await mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

      if (widget.onHabitCreated != null) widget.onHabitCreated!(response.id);
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Unexpected error occurred while creating habit.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _createHabit(context),
      icon: const Icon(Icons.add),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
