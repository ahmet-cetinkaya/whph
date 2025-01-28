import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/components/habit_delete_button.dart';
import 'package:whph/presentation/features/habits/components/habit_details_content.dart';
import 'package:whph/presentation/features/habits/components/habit_title_input_field.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';

class HabitDetailsPage extends StatefulWidget {
  static const String route = '/habits/details';
  final String habitId;

  const HabitDetailsPage({super.key, required this.habitId});

  @override
  State<HabitDetailsPage> createState() => _HabitDetailsPageState();
}

class _HabitDetailsPageState extends State<HabitDetailsPage> {
  Key _titleKey = UniqueKey();
  Key _contentKey = UniqueKey();

  void _refreshTitle() {
    if (mounted) {
      setState(() {
        _titleKey = UniqueKey();
      });
    }
  }

  void _refreshContent() {
    if (mounted) {
      setState(() {
        _contentKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: HabitNameInputField(
        key: _titleKey,
        habitId: widget.habitId,
        onHabitUpdated: _refreshContent,
      ),
      appBarActions: [
        HabitDeleteButton(
          habitId: widget.habitId,
          onDeleteSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
        ),
        HelpMenu(
          titleKey: HabitTranslationKeys.detailsHelpTitle,
          markdownContentKey: HabitTranslationKeys.detailsHelpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: HabitDetailsContent(
          key: _contentKey,
          habitId: widget.habitId,
          onHabitUpdated: _refreshTitle,
        ),
      ),
    );
  }
}
