import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_delete_button.dart';
import 'package:whph/presentation/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/features/tasks/components/task_title_input_field.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;

  const TaskDetailsPage({super.key, required this.taskId});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: TaskTitleInputField(taskId: widget.taskId),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TaskDeleteButton(
                taskId: widget.taskId,
                onDeleteSuccess: () {
                  Navigator.of(context).pop();
                },
                buttonColor: AppTheme.primaryColor,
                buttonBackgroundColor: AppTheme.surface2),
          ),
        ],
      ),
      body: SingleChildScrollView(child: TaskDetailsContent(taskId: widget.taskId)),
    );
  }
}
