import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TasksPage extends StatefulWidget {
  final Mediator mediator = container.resolve<Mediator>();

  TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<TaskListItem> _tasks = [];
  int _pageIndex = 0;
  bool _hasNext = false;
  final ScrollController _scrollController = ScrollController();
  int _loadingCount = 0;
  final TextEditingController _taskTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    _setupScrollListener();
  }

  Future<void> _fetchTasks({int pageIndex = 0}) async {
    setState(() {
      _loadingCount++;
    });

    const pageSize = 20;
    var query = GetListTasksQuery(pageIndex: pageIndex, pageSize: pageSize);
    var queryResponse = await widget.mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);

    setState(() {
      _tasks = [..._tasks, ...queryResponse.items];
      _pageIndex = pageIndex;
      _hasNext = queryResponse.hasNext;
      _loadingCount--;
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasNext) {
        await _fetchTasks(pageIndex: _pageIndex + 1);
      }
    });
  }

  Future<void> _openDetails(TaskListItem task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(taskId: task.id),
      ),
    );
    _tasks.clear();
    _fetchTasks();
  }

  Future<void> _addTask() async {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    var command = SaveTaskCommand(title: title);
    await widget.mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

    setState(() {
      _tasks.clear();
      _pageIndex = 0;
    });
    await _fetchTasks();

    _taskTitleController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _tasks.clear();
                _pageIndex = 0;
              });
              await _fetchTasks();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskTitleController,
                    decoration: const InputDecoration(
                      hintText: 'Enter task title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _tasks.clear();
                });
                await _fetchTasks();
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _tasks.length + (_loadingCount > 0 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_loadingCount > 0 && index == _tasks.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final task = _tasks[index];
                  return TaskCard(
                    task: task,
                    onOpenDetails: () {
                      _openDetails(task);
                    },
                    onCompleted: () {
                      setState(() {
                        _tasks.clear();
                      });
                      _fetchTasks();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
