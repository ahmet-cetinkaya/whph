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

  // Smooth refresh method that preserves UI state
  Future<void> refresh({bool showLoading = false}) async {
    await _getTasks(isRefresh: true, showLoading: showLoading);
  }

  // Add a task to the list without full refresh
  void addTask(TaskListItem task) {
    if (_tasks != null && mounted) {
      setState(() {
        // Add the task to the beginning of the list
        _tasks!.items.insert(0, task);
      });

      if (widget.onList != null) {
        widget.onList!(_tasks!.items.length);
      }
    } else {
      // If tasks is null, do a full refresh
      refresh(showLoading: false);
    }
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

  Future<void> _getTasks({int pageIndex = 0, bool isRefresh = false, bool showLoading = true}) async {
    if (_isLoading) return;

    // Only show loading indicator if explicitly requested
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Calculate page size - preserve existing items if refreshing
      final pageSize =
          isRefresh && _tasks != null && _tasks!.items.length > widget.size ? _tasks!.items.length : widget.size;

      final query = GetListTasksQuery(
          pageIndex: pageIndex,
          pageSize: pageSize,
          filterByPlannedStartDate: widget.filterByPlannedStartDate,
          filterByPlannedEndDate: widget.filterByPlannedEndDate,
          filterByDeadlineStartDate: widget.filterByDeadlineStartDate,
          filterByDeadlineEndDate: widget.filterByDeadlineEndDate,
          filterDateOr: widget.filterDateOr,
          filterByTags: widget.filterByTags,
          filterByCompleted: widget.filterByCompleted,
          searchQuery: widget.search,
          parentTaskId: widget.parentTaskId);

      // We'll use the current tasks for smooth transition if needed

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
        // Only show error if loading indicator was shown
        if (showLoading) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: widget.translationService.translate(TaskTranslationKeys.getTaskError),
          );
        } else {
          // Just log the error if we're doing a silent refresh
          debugPrint('Error refreshing tasks: $e');
        }

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
    // Initial loading state
    if (_tasks == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Check if the list is empty and show a message
    if (_tasks!.items.isEmpty || (_tasks!.items.length == 1 && widget.selectedTask != null)) {
      return Center(
        child: Text(widget.translationService.translate(SharedTranslationKeys.noItemsFoundMessage)),
      );
    }

    return Stack(
      children: [
        // Main content
        ListView(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          controller: _scrollController,
          children: [
            // Task Cards
            if (widget.enableReordering)
              Material(
                type: MaterialType.transparency,
                child: ReorderableListView(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  proxyDecorator: _buildProxyDecorator,
                  onReorder: _onReorder,
                  children: _buildTaskCards(),
                ),
              )
            else
              ..._buildTaskCards(),

            // Load More Button
            if (_tasks!.hasNext) LoadMoreButton(onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1)),
          ],
        ),

        // Overlay loading indicator (only shown when _isLoading is true)
        if (_isLoading)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
