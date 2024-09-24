import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/components/habit_delete_button.dart';
import 'package:whph/presentation/features/habits/components/habit_details_content.dart';
import 'package:whph/presentation/features/habits/components/habit_title_input_field.dart';

class HabitDetailsPage extends StatelessWidget {
  final int habitId;

  const HabitDetailsPage({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HabitNameInputField(
          habitId: habitId,
        ),
        actions: [
          HabitDeleteButton(
            habitId: habitId,
            onDeleteSuccess: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: HabitDetailsContent(
        habitId: habitId,
        isNameFieldVisible: false,
      ),
    );
  }
}
