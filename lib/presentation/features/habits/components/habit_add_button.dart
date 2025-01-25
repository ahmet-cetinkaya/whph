import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';

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
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: HabitUiConstants.errorSavingHabit);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _createHabit(context),
      icon: Icon(SharedUiConstants.addIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
