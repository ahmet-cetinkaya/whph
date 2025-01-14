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
  final bool filterDateOr;
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
      this.filterDateOr = false,
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getTasks();
  }

  Future<void> _getTasks({int pageIndex = 0}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    var query = GetListTasksQuery(
        pageIndex: pageIndex,
        pageSize: widget.size,
        filterByPlannedStartDate: widget.filterByPlannedStartDate,
        filterByPlannedEndDate: widget.filterByPlannedEndDate,
        filterByDeadlineStartDate: widget.filterByDueStartDate,
        filterByDeadlineEndDate: widget.filterByDueEndDate,
        filterDateOr: widget.filterDateOr,
        filterByTags: widget.filterByTags,
        filterByCompleted: widget.filterByCompleted);
    var result = await widget.mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);

    if (mounted) {
      setState(() {
        if (_tasks == null || pageIndex == 0) {
          _tasks = result;
        } else {
          _tasks!.items.addAll(result.items);
          _tasks!.pageIndex = result.pageIndex;
        }
        _isLoading = false;
      });
    }
  }

  void _onTaskCompleted() {
    if (_tasks != null) {
      // Tamamlanan task'ı listeden kaldır
      setState(() {
        _tasks!.items.removeWhere((task) => task.isCompleted);
      });
    }

    // Listeyi arka planda güncelle
    // _getTasks();

    if (widget.onTaskCompleted != null) {
      widget.onTaskCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) {
      return const SizedBox.shrink();
    }

    if (_tasks!.items.isEmpty) {
      return const Center(
        child: Text('No tasks found'),
      );
    }

    if (widget.onList != null) {
      widget.onList!(_tasks!.items.length);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _tasks!.items.length,
          itemBuilder: (context, index) {
            final task = _tasks!.items[index];
            return TaskCard(
              task: task,
              onOpenDetails: () => widget.onClickTask(task),
              onCompleted: _onTaskCompleted,
            );
          },
        ),
        if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
      ],
    );
  }
}
