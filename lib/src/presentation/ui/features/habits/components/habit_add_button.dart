import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/src/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/habits/services/habits_service.dart';

class HabitAddButton extends StatefulWidget {
  /// The color of the button icon
  final Color? buttonColor;

  /// The background color of the button
  final Color? buttonBackgroundColor;

  /// Callback when a habit is created
  final Function(String habitId)? onHabitCreated;

  /// Initial tag IDs for filtering new habits
  final List<String>? initialTagIds;

  /// Initial name for the habit
  final String? initialName;

  /// Initial description for the habit
  final String? initialDescription;

  /// Whether to initialize the habit with an archive status
  final bool? initialArchived;

  const HabitAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onHabitCreated,
    this.initialTagIds,
    this.initialName,
    this.initialDescription,
    this.initialArchived,
  });

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
          name: widget.initialName ?? "",
          description: widget.initialDescription ?? "",
          archivedDate: widget.initialArchived == true ? DateTime.now() : null,
        );
        return await _mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);
      },
      onSuccess: (response) {
        _habitsService.notifyHabitCreated(response.id);

        // If tag IDs were provided, add tags to the newly created habit
        if (widget.initialTagIds != null && widget.initialTagIds!.isNotEmpty) {
          _addTagsToHabit(response.id, widget.initialTagIds!);
        }

        widget.onHabitCreated?.call(response.id);
      },
    );
  }

  /// Adds tags to a newly created habit
  Future<void> _addTagsToHabit(String habitId, List<String> tagIds) async {
    // Add each tag to the habit
    for (final tagId in tagIds) {
      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(HabitTranslationKeys.addingTagError),
        operation: () async {
          final command = AddHabitTagCommand(habitId: habitId, tagId: tagId);
          await _mediator.send(command);
        },
      );
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
      tooltip: _translationService.translate(HabitTranslationKeys.addHabit),
    );
  }
}
