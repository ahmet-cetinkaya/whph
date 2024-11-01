import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/components/habit_delete_button.dart';
import 'package:whph/presentation/features/habits/components/habit_details_content.dart';
import 'package:whph/presentation/features/habits/components/habit_title_input_field.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: HabitDeleteButton(
              habitId: habitId,
              onDeleteSuccess: () {
                Navigator.of(context).pop();
              },
              buttonColor: AppTheme.primaryColor,
              buttonBackgroundColor: AppTheme.surface2,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: HabitDetailsContent(
          habitId: habitId,
          isNameFieldVisible: false,
        ),
      ),
    );
  }
}
