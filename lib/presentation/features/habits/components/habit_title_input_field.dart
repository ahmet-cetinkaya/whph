import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';

class HabitNameInputField extends StatefulWidget {
  final int habitId;

  const HabitNameInputField({
    super.key,
    required this.habitId,
  });

  @override
  State<HabitNameInputField> createState() => _HabitNameInputFieldState();
}

class _HabitNameInputFieldState extends State<HabitNameInputField> {
  final Mediator _mediator = container.resolve<Mediator>();
  final TextEditingController _titleController = TextEditingController();

  GetHabitQueryResponse? habit;

  @override
  void initState() {
    super.initState();
    _fetchHabit();
  }

  Future<void> _fetchHabit() async {
    var query = GetHabitQuery(id: widget.habitId);
    var response = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
    setState(() {
      habit = response;
      _titleController.text = habit!.name;
    });
  }

  void _updateHabit() {
    var command = SaveHabitCommand(
      id: widget.habitId,
      name: _titleController.text,
      description: habit!.description,
    );

    _mediator.send(command);
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
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter habit title',
                  ),
                ),
              ),
            ],
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
