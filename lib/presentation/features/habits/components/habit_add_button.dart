import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';

class HabitAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String habitId)? onHabitCreated;

  const HabitAddButton({super.key, this.buttonColor, this.buttonBackgroundColor, this.onHabitCreated});

  @override
  State<HabitAddButton> createState() => _HabitAddButtonState();
}

class _HabitAddButtonState extends State<HabitAddButton> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  Future<void> _createHabit(BuildContext context) async {
    await AsyncErrorHandler.execute<SaveHabitCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () async {
        final command = SaveHabitCommand(
          name: _translationService.translate(HabitTranslationKeys.newHabit),
          description: "",
        );
        return await _mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);
      },
      onSuccess: (response) {
        _habitsService.notifyHabitCreated(response.id);
        widget.onHabitCreated?.call(response.id);
      },
    );
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
      tooltip: _translationService.translate(HabitTranslationKeys.addHabit),
    );
  }
}
