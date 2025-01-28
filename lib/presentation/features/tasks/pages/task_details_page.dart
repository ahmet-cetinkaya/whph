import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_delete_button.dart';
import 'package:whph/presentation/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/features/tasks/components/task_title_input_field.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';

class TaskDetailsPage extends StatefulWidget {
  static const String route = '/tasks/details';
  final String taskId;

  const TaskDetailsPage({super.key, required this.taskId});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: TaskTitleInputField(
        key: _titleKey,
        taskId: widget.taskId,
        onTaskUpdated: _refreshContent,
      ),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TaskDeleteButton(
            taskId: widget.taskId,
            onDeleteSuccess: () {
              Navigator.of(context).pop();
            },
            buttonColor: AppTheme.primaryColor,
          ),
        ),
        HelpMenu(
          titleKey: TaskTranslationKeys.detailsHelpTitle,
          markdownContentKey: TaskTranslationKeys.detailsHelpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => Container(
        width: double.infinity,
        alignment: Alignment.topLeft,
        child: TaskDetailsContent(
          key: _contentKey,
          taskId: widget.taskId,
          onTaskUpdated: _refreshTitle,
        ),
      ),
    );
  }
}
