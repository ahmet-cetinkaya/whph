import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/features/shared/components/load_more_button.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';

class TasksList extends StatefulWidget {
  final Mediator mediator;
  final int size;
  final void Function(TaskListItem task) onClickTask;
  final DateTime? filterByPlannedDate;
  final DateTime? filterByDueDate;

  const TasksList({
    super.key,
    required this.mediator,
    required this.onClickTask,
    this.size = 10,
    this.filterByPlannedDate,
    this.filterByDueDate,
  });

  @override
  State<TasksList> createState() => _TasksListState();
}

class _TasksListState extends State<TasksList> {
  GetListTasksQueryResponse? _tasks;
  List<String> _selectedFilterTags = [];

  @override
  void initState() {
    super.initState();
    _getTasks();
  }

  Future<void> _getTasks({int pageIndex = 0}) async {
    var query = GetListTasksQuery(
        pageIndex: pageIndex,
        pageSize: widget.size,
        filterByPlannedDate: widget.filterByPlannedDate,
        filterByDeadlineDate: widget.filterByDueDate,
        filterByTags: _selectedFilterTags);
    var result = await widget.mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);

    setState(() {
      if (_tasks == null) {
        _tasks = result;
        return;
      }

      _tasks!.items.addAll(result.items);
      _tasks!.pageIndex = result.pageIndex;
    });
  }

  void _onTagFilter(List<String> tags) {
    _tasks = null;
    _selectedFilterTags = (tags);

    _getTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: TagSelectDropdown(
            isMultiSelect: true,
            onTagsSelected: _onTagFilter,
          ),
        ),

        // List
        ..._tasks!.items.map((task) {
          return TaskCard(
            task: task,
            onOpenDetails: () => widget.onClickTask(task),
            onCompleted: () {
              _getTasks();
            },
          );
        }),
        if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
      ],
    );
  }
}
