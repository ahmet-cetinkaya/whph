import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';

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

  @override
  void initState() {
    _getHabit();
    widget._habitsService.onHabitSaved.addListener(_getHabit);

    super.initState();
  }

  @override
  void dispose() {
    widget._habitsService.onHabitSaved.removeListener(_getHabit);
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _getHabit() async {
    var query = GetHabitQuery(id: widget.habitId);
    var response = await widget._mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
    if (mounted) {
      setState(() {
        habit = response;
        _titleController.text = habit!.name;
      });
    }
  }

  Future<void> _updateHabit() async {
    var command = SaveHabitCommand(
      id: widget.habitId,
      name: _titleController.text,
      description: habit!.description,
    );
    var result = await widget._mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

    widget._habitsService.onHabitSaved.value = result;
  }

  @override
  Widget build(BuildContext context) {
    return habit == null
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  onChanged: (value) {
                    _updateHabit();
                  },
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter title', filled: false),
                ),
              ),
            ],
          );
  }
}
