import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';

class TasksList extends StatefulWidget {
  final Mediator mediator;
  final VoidCallback onTaskAdded;
  final void Function(TaskListItem task) onClickTask;

  const TasksList({
    super.key,
    required this.mediator,
    required this.onTaskAdded,
    required this.onClickTask,
  });

  @override
  _TasksListState createState() => _TasksListState();
}

class _TasksListState extends State<TasksList> {
  List<TaskListItem> _tasks = [];
  int _pageIndex = 0;
  bool _hasNext = false;
  final ScrollController _scrollController = ScrollController();
  int _loadingCount = 0;

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

    var query = GetListTasksQuery(pageIndex: pageIndex, pageSize: 100); //TODO: Add lazy loading
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _tasks.clear();
          _pageIndex = 0;
        });
        await _fetchTasks();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _tasks.length + (_loadingCount > 0 ? 1 : 0),
        itemBuilder: (context, index) {
          if (_loadingCount > 0) {
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
              widget.onClickTask(task); // Use the passed callback here
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
    );
  }
}
