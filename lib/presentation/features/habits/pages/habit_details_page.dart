import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/components/habit_delete_button.dart';
import 'package:whph/presentation/features/habits/components/habit_details_content.dart';
import 'package:whph/presentation/features/habits/components/habit_title_input_field.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';

class HabitDetailsPage extends StatelessWidget {
  static const String route = '/habits/details';
  final String habitId;

  const HabitDetailsPage({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: HabitNameInputField(habitId: habitId),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: HabitDeleteButton(
            habitId: habitId,
            onDeleteSuccess: () => Navigator.of(context).pop(),
            buttonColor: AppTheme.primaryColor,
            buttonBackgroundColor: AppTheme.surface2,
          ),
        ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: HabitDetailsContent(habitId: habitId),
      ),
    );
  }
}
