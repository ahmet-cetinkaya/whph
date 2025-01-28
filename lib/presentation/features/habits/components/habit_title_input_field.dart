import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class HabitNameInputField extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final HabitsService _habitsService = container.resolve<HabitsService>();

  final String habitId;

  HabitNameInputField({
    super.key,
    required this.habitId,
  });

  @override
  State<HabitNameInputField> createState() => _HabitNameInputFieldState();
}

class _HabitNameInputFieldState extends State<HabitNameInputField> {
  GetHabitQueryResponse? habit;
  final TextEditingController _titleController = TextEditingController();
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    _getHabit();

    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _getHabit() async {
    try {
      var query = GetHabitQuery(id: widget.habitId);
      var response = await widget._mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      if (mounted) {
        setState(() {
          habit = response;
          _titleController.text = habit!.name;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(HabitTranslationKeys.loadingHabitError),
        );
      }
    }
  }

  Future<void> _updateHabit() async {
    try {
      var command = SaveHabitCommand(
        id: widget.habitId,
        name: _titleController.text,
        description: habit!.description,
        estimatedTime: habit!.estimatedTime,
      );
      var result = await widget._mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

      widget._habitsService.onHabitSaved.value = result;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(HabitTranslationKeys.savingHabitError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (habit == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _titleController,
            onChanged: (value) {
              _updateHabit();
            },
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
