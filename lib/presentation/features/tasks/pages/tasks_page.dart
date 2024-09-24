import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_add_form.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  final Mediator mediator = container.resolve<Mediator>();

  TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  Key _tasksListKey = UniqueKey();

  void _refreshTasks() {
    setState(() {
      _tasksListKey = UniqueKey();
    });
  }

  Future<void> _openTaskDetails(TaskListItem task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(taskId: task.id),
      ),
    );
    _refreshTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          TaskForm(
            mediator: widget.mediator,
            onTaskAdded: _refreshTasks, // Notify to refresh the task list
          ),
          Expanded(
            child: TasksList(
              key: _tasksListKey, // Assign the key to TasksList
              mediator: widget.mediator,
              onTaskAdded: _refreshTasks,
              onClickTask: _openTaskDetails,
            ),
          ),
        ],
      ),
    );
  }
}
