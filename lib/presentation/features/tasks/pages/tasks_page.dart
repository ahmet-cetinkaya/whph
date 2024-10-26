import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final Mediator _mediator = container.resolve<Mediator>();
  Key _tasksListKey = UniqueKey();

  void _refreshTasks() {
    setState(() {
      _tasksListKey = UniqueKey();
    });
  }

  Future<void> _openTaskDetails(String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(taskId: taskId),
      ),
    );
    _refreshTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Tasks'),
        actions: [
          TaskAddButton(
            onTaskCreated: (taskId) => _openTaskDetails(taskId),
          ),
        ],
      ),
      body: ListView(
        children: [
          TaskList(
            key: _tasksListKey,
            mediator: _mediator,
            onClickTask: (task) => _openTaskDetails(task.id),
          )
        ],
      ),
    );
  }
}
