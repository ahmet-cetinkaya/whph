import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/delete_habit_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class HabitDeleteButton extends StatefulWidget {
  final String habitId;
  final VoidCallback? onDeleteSuccess;
  final Color? buttonColor;
  final Color? buttonBackgroundColor;

  const HabitDeleteButton({
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
  final Mediator _mediator = container.resolve<Mediator>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final HabitsService _habitsService = container.resolve<HabitsService>();

  Future<void> _deleteHabit(BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.deletingError),
      operation: () async {
        final command = DeleteHabitCommand(id: widget.habitId);
        await _mediator.send(command);
      },
      onSuccess: () {
        // Notify service about habit deletion
        _habitsService.notifyHabitDeleted(widget.habitId);

        // Call callback if provided (for backward compatibility)
        widget.onDeleteSuccess?.call();
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(HabitTranslationKeys.deleteConfirmTitle)),
        content: Text(_translationService.translate(HabitTranslationKeys.deleteConfirmMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
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
      icon: Icon(SharedUiConstants.deleteIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
      tooltip: _translationService.translate(SharedTranslationKeys.deleteButton),
    );
  }
}
