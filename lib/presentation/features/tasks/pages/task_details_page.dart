import 'package:flutter/material.dart';
import 'package:whph/presentation/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/features/tasks/components/task_title_input_field.dart';

class TaskDetailsPage extends StatefulWidget {
  final int taskId;

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
      appBar: AppBar(
        title: TaskTitleInputField(taskId: widget.taskId),
      ),
      body:
          SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: TaskDetailsContent(taskId: widget.taskId)),
    );
  }
}
