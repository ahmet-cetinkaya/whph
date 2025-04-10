import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/acore/utils/order_rank.dart';

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
  final bool enableReordering;

  final void Function(TaskListItem task) onClickTask;
  final void Function(int count)? onList;
  final void Function()? onTaskCompleted;
  final void Function(TaskListItem task)? onSelectTask;
  final void Function(TaskListItem task, DateTime date)? onScheduleTask;
  final List<Widget> Function(TaskListItem task)? trailingButtons;
  // Add rebuildKey parameter to force rebuild when needed
  final Key? rebuildKey;

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
    this.enableReordering = false,
    required this.onClickTask,
    this.onList,
    this.onTaskCompleted,
    this.onSelectTask,
    this.onScheduleTask,
    this.trailingButtons,
    this.rebuildKey,
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
          pageSize: isRefresh && _tasks!.items.length > widget.size ? _tasks!.items.length : widget.size,
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

  Widget _buildProxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(1, 6, animValue)!;
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: elevation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!mounted) return;

    final items = List<TaskListItem>.from(_tasks!.items)..sort((a, b) => a.order.compareTo(b.order));
    final task = items[oldIndex];

    // Adjust newIndex for removal of item
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Get existing orders for calculation
    List<double> existingOrders = items.map((item) => item.order).toList();
    // Remove the task being moved from the order list
    existingOrders.removeAt(oldIndex);

    // Calculate target order using OrderRank utility
    double targetOrder;
    try {
      targetOrder = OrderRank.getTargetOrder(existingOrders, newIndex);
    } on RankGapTooSmallException {
      // If gap is too small, place at end using a larger step to ensure proper ordering
      targetOrder = items.last.order + OrderRank.initialStep * 2;
    }

    try {
      await widget.mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
        UpdateTaskOrderCommand(
          taskId: task.id,
          parentTaskId: widget.parentTaskId,
          beforeTaskOrder: task.order, // Original order
          afterTaskOrder: targetOrder,
        ),
      );

      await refresh();
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget.translationService.translate(SharedTranslationKeys.unexpectedError),
        );
      }
    }
  }

  List<Widget> _buildTaskCards() {
    final items = _tasks!.items.where((task) => task.id != widget.selectedTask?.id).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return items.map((task) {
      final index = items.indexOf(task);
      return Material(
        key: ValueKey(task.id),
        type: MaterialType.transparency,
        child: TaskCard(
          taskItem: task,
          transparent: widget.transparentCards,
          trailingButtons: [
            if (widget.trailingButtons != null) ...widget.trailingButtons!(task),
            if (widget.showSelectButton)
              IconButton(
                icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
                onPressed: () => widget.onSelectTask?.call(task),
              ),
            if (widget.enableReordering)
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
          ],
          onCompleted: _onTaskCompleted,
          onOpenDetails: () => widget.onClickTask(task),
          onScheduled: widget.onScheduleTask != null ? () => widget.onScheduleTask!(task, DateTime.now()) : null,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) {
      return const SizedBox.shrink();
    }

    if (_tasks!.items.isEmpty || (_tasks!.items.length == 1 && widget.selectedTask != null)) {
      return Center(
        child: Text(widget.translationService.translate(SharedTranslationKeys.noItemsFoundMessage)),
      );
    }

    if (widget.enableReordering) {
      return Material(
        type: MaterialType.transparency,
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          proxyDecorator: _buildProxyDecorator,
          onReorder: _onReorder,
          children: _buildTaskCards(),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      controller: _scrollController,
      children: [
        ..._buildTaskCards(),
        if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
      ],
    );
  }
}
