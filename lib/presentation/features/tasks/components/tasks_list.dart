import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/features/shared/components/load_more_button.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';

class TaskList extends StatefulWidget {
  final Mediator mediator;
  final int size;

  // Update filter props to match query parameters
  final List<String>? filterByTags;
  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final bool filterDateOr;
  final bool? filterByCompleted;
  final String? search;

  final TaskListItem? selectedTask;
  final bool showSelectButton;
  final bool transparentCards;

  final void Function(TaskListItem task) onClickTask;
  final void Function(int count)? onList;
  final void Function()? onTaskCompleted;
  final void Function(TaskListItem task)? onSelectTask;
  final List<Widget> Function(TaskListItem task)? trailingButtons;

  const TaskList({
    super.key,
    required this.mediator,
    this.size = 10,
    this.filterByTags,
    this.filterByPlannedStartDate,
    this.filterByPlannedEndDate,
    this.filterByDeadlineStartDate,
    this.filterByDeadlineEndDate,
    this.filterDateOr = false,
    this.filterByCompleted,
    this.search,
    this.selectedTask,
    this.showSelectButton = false,
    this.transparentCards = false,
    required this.onClickTask,
    this.onList,
    this.onTaskCompleted,
    this.onSelectTask,
    this.trailingButtons,
  });

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
        filterByDeadlineStartDate: widget.filterByDeadlineStartDate,
        filterByDeadlineEndDate: widget.filterByDeadlineEndDate,
        filterDateOr: widget.filterDateOr,
        filterByTags: widget.filterByTags,
        filterByCompleted: widget.filterByCompleted,
        searchQuery: widget.search);
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
      // Remove completed task from the list
      setState(() {
        _tasks!.items.removeWhere((task) => task.isCompleted);
      });
    }

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
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tasks!.items.where((task) => task.id != widget.selectedTask?.id).length,
          itemBuilder: (context, index) {
            final task = _tasks!.items.where((task) => task.id != widget.selectedTask?.id).toList()[index];

            return TaskCard(
              task: task,
              onOpenDetails: () => widget.onClickTask(task),
              onCompleted: _onTaskCompleted,
              transparent: widget.transparentCards,
              trailingButtons: [
                if (widget.trailingButtons != null) ...widget.trailingButtons!(task),
                if (widget.showSelectButton)
                  IconButton(
                    icon: Icon(Icons.push_pin_outlined, color: Colors.grey),
                    onPressed: () => widget.onSelectTask?.call(task),
                  ),
              ],
            );
          },
        ),
        if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
      ],
    );
  }
}
