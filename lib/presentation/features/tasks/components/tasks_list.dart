import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';

class TaskList extends StatefulWidget {
  final Mediator mediator;
  final ITranslationService translationService;
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
  final String? parentTaskId;

  final TaskListItem? selectedTask;
  final bool showSelectButton;
  final bool transparentCards;

  final void Function(TaskListItem task) onClickTask;
  final void Function(int count)? onList;
  final void Function()? onTaskCompleted;
  final void Function(TaskListItem task)? onSelectTask;
  final void Function(TaskListItem task, DateTime date)? onScheduleTask;
  final List<Widget> Function(TaskListItem task)? trailingButtons;

  const TaskList({
    super.key,
    required this.mediator,
    required this.translationService,
    this.size = 10,
    this.filterByTags,
    this.filterByPlannedStartDate,
    this.filterByPlannedEndDate,
    this.filterByDeadlineStartDate,
    this.filterByDeadlineEndDate,
    this.filterDateOr = false,
    this.filterByCompleted,
    this.search,
    this.parentTaskId,
    this.selectedTask,
    this.showSelectButton = false,
    this.transparentCards = false,
    required this.onClickTask,
    this.onList,
    this.onTaskCompleted,
    this.onSelectTask,
    this.onScheduleTask,
    this.trailingButtons,
  });

  @override
  State<TaskList> createState() => TaskListState();
}

class TaskListState extends State<TaskList> {
  GetListTasksQueryResponse? _tasks;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollPosition;

  Future<void> refresh() async {
    await _getTasks(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) {
      _savedScrollPosition = _scrollController.position.pixels;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_savedScrollPosition != null && _scrollController.hasClients) {
          _scrollController.jumpTo(_savedScrollPosition!);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getTasks();
  }

  Future<void> _getTasks({int pageIndex = 0, bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final query = GetListTasksQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh ? _tasks!.items.length : widget.size,
          filterByPlannedStartDate: widget.filterByPlannedStartDate,
          filterByPlannedEndDate: widget.filterByPlannedEndDate,
          filterByDeadlineStartDate: widget.filterByDeadlineStartDate,
          filterByDeadlineEndDate: widget.filterByDeadlineEndDate,
          filterDateOr: widget.filterDateOr,
          filterByTags: widget.filterByTags,
          filterByCompleted: widget.filterByCompleted,
          searchQuery: widget.search,
          parentTaskId: widget.parentTaskId);
      final result = await widget.mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);

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

        if (widget.onList != null) {
          widget.onList!(_tasks!.items.length);
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget.translationService.translate(TaskTranslationKeys.getTaskError),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onTaskCompleted() {
    Future.delayed(const Duration(seconds: 2), () {
      widget.onTaskCompleted?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) {
      return const SizedBox.shrink();
    }

    if (_tasks!.items.isEmpty) {
      return Center(
        child: Text(widget.translationService.translate(SharedTranslationKeys.noItemsFoundMessage)),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      controller: _scrollController,
      children: [
        ...(_tasks!.items
            .where((task) => task.id != widget.selectedTask?.id)
            .map((task) => FutureBuilder<GetListTasksQueryResponse>(
                  future: widget.mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
                    GetListTasksQuery(
                      pageIndex: 0,
                      pageSize: 10,
                      parentTaskId: task.id,
                    ),
                  ),
                  builder: (context, snapshot) {
                    final subTasks = snapshot.data?.items ?? [];
                    double subTasksCompletionPercentage = 0;
                    if (subTasks.isNotEmpty) {
                      final completedSubTasks = subTasks.where((subTask) => subTask.isCompleted).length;
                      subTasksCompletionPercentage = (completedSubTasks / subTasks.length) * 100;
                    }

                    return TaskCard(
                      key: ValueKey(task.id),
                      taskItem: task.copyWith(
                        subTasks: subTasks,
                        subTasksCompletionPercentage: subTasksCompletionPercentage,
                      ),
                      transparent: widget.transparentCards,
                      trailingButtons: [
                        if (widget.trailingButtons != null) ...widget.trailingButtons!(task),
                        if (widget.showSelectButton)
                          IconButton(
                            icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
                            onPressed: () => widget.onSelectTask?.call(task),
                          ),
                      ],
                      onCompleted: _onTaskCompleted,
                      onOpenDetails: () => widget.onClickTask(task),
                      onScheduled:
                          widget.onScheduleTask != null ? () => widget.onScheduleTask!(task, DateTime.now()) : null,
                    );
                  },
                ))),
        if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
      ],
    );
  }
}
