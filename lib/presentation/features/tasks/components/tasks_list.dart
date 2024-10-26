import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/features/shared/components/load_more_button.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';

class TaskList extends StatefulWidget {
  final Mediator mediator;

  final int size;
  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDueStartDate;
  final DateTime? filterByDueEndDate;
  final List<String>? filterByTags;
  final bool? filterByCompleted;

  final void Function(TaskListItem task) onClickTask;
  final void Function(int count)? onList;
  final void Function()? onTaskCompleted;

  const TaskList(
      {super.key,
      required this.mediator,
      this.size = 10,
      this.filterByPlannedStartDate,
      this.filterByPlannedEndDate,
      this.filterByDueStartDate,
      this.filterByDueEndDate,
      this.filterByTags = const [],
      this.filterByCompleted,
      required this.onClickTask,
      this.onList,
      this.onTaskCompleted});

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  GetListTasksQueryResponse? _tasks;

  @override
  void initState() {
    super.initState();
    _getTasks();
  }

  Future<void> _getTasks({int pageIndex = 0}) async {
    var query = GetListTasksQuery(
        pageIndex: pageIndex,
        pageSize: widget.size,
        filterByPlannedStartDate: widget.filterByPlannedStartDate,
        filterByPlannedEndDate: widget.filterByPlannedEndDate,
        filterByDeadlineStartDate: widget.filterByDueStartDate,
        filterByDeadlineEndDate: widget.filterByDueEndDate,
        filterByTags: widget.filterByTags,
        filterByCompleted: widget.filterByCompleted);
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

  void _onTaskCompleted() {
    _tasks = null;
    _getTasks();

    if (widget.onTaskCompleted != null) {
      widget.onTaskCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (widget.onList != null) {
      widget.onList!(_tasks!.items.length);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._tasks!.items.map((task) {
          return TaskCard(
            task: task,
            onOpenDetails: () => widget.onClickTask(task),
            onCompleted: _onTaskCompleted,
          );
        }),
        if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
      ],
    );
  }
}
