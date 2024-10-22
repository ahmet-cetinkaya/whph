import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/components/habit_delete_button.dart';
import 'package:whph/presentation/features/habits/components/habit_details_content.dart';
import 'package:whph/presentation/features/habits/components/habit_title_input_field.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';

class HabitDetailsPage extends StatelessWidget {
  final String habitId;

  const HabitDetailsPage({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
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
