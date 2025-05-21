import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/acore/utils/order_rank.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/core/acore/utils/collection_utils.dart';

class TaskList extends StatefulWidget {
  final int size;

  // Filter props to match query parameters
  final List<String>? filterByTags;
  final bool filterNoTags;
  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final bool filterDateOr;
  final bool? filterByCompleted;
  final String? search;
  final String? parentTaskId;
  final bool showDoneOverlayWhenEmpty;

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
  final Key? rebuildKey;
  final SortDirection? sortByPlannedDate;

  const TaskList({
    super.key,
    this.size = 10,
    this.filterByTags,
    this.filterNoTags = false,
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
    this.showDoneOverlayWhenEmpty = false,
    required this.onClickTask,
    this.onList,
    this.onTaskCompleted,
    this.onSelectTask,
    this.onScheduleTask,
    this.trailingButtons,
    this.rebuildKey,
    this.sortByPlannedDate,
  });

  @override
  State<TaskList> createState() => TaskListState();
}

class TaskListState extends State<TaskList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tasksService = container.resolve<TasksService>();
  GetListTasksQueryResponse? _tasks;
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollPosition;
  final PageStorageKey _pageStorageKey = const PageStorageKey<String>('task_list_scroll');

  @override
  void initState() {
    super.initState();
    _getTasks();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _tasksService.onTaskCreated.addListener(_handleTaskUpdate);
    _tasksService.onTaskUpdated.addListener(_handleTaskUpdate);
    _tasksService.onTaskDeleted.addListener(_handleTaskUpdate);
    _tasksService.onTaskCompleted.addListener(_handleTaskUpdate);
  }

  void _removeEventListeners() {
    _tasksService.onTaskCreated.removeListener(_handleTaskUpdate);
    _tasksService.onTaskUpdated.removeListener(_handleTaskUpdate);
    _tasksService.onTaskDeleted.removeListener(_handleTaskUpdate);
    _tasksService.onTaskCompleted.removeListener(_handleTaskUpdate);
  }

  void _handleTaskUpdate() {
    if (!mounted) return;
    refresh();
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _backLastScrollPosition() {
    if (_savedScrollPosition == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.hasViewportDimension &&
          _savedScrollPosition! <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_savedScrollPosition!);
      }
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _saveScrollPosition();
    await _getTasks(isRefresh: true);
    _backLastScrollPosition();
  }

  @override
  void didUpdateWidget(TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isFilterChanged(oldWidget) && mounted) {
      refresh();
    }
  }

  bool _isFilterChanged(TaskList oldWidget) {
    final oldFilters = {
      'completed': oldWidget.filterByCompleted,
      'tags': oldWidget.filterByTags,
      'search': oldWidget.search,
      'plannedStartDate': oldWidget.filterByPlannedStartDate,
      'plannedEndDate': oldWidget.filterByPlannedEndDate,
      'deadlineStartDate': oldWidget.filterByDeadlineStartDate,
      'deadlineEndDate': oldWidget.filterByDeadlineEndDate,
      'sortByPlannedDate': oldWidget.sortByPlannedDate,
    };

    final newFilters = {
      'completed': widget.filterByCompleted,
      'tags': widget.filterByTags,
      'search': widget.search,
      'plannedStartDate': widget.filterByPlannedStartDate,
      'plannedEndDate': widget.filterByPlannedEndDate,
      'deadlineStartDate': widget.filterByDeadlineStartDate,
      'deadlineEndDate': widget.filterByDeadlineEndDate,
      'sortByPlannedDate': widget.sortByPlannedDate,
    };

    return CollectionUtils.hasAnyMapValueChanged(oldFilters, newFilters);
  }

  Future<void> _getTasks({int pageIndex = 0, bool isRefresh = false}) async {
    List<TaskListItem>? existingItems;
    if (isRefresh && _tasks != null) {
      existingItems = List.from(_tasks!.items);
    }

    await AsyncErrorHandler.execute<GetListTasksQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.getTagsError),
      operation: () async {
        final query = GetListTasksQuery(
          pageIndex: pageIndex,
          pageSize: widget.size,
          filterByPlannedStartDate: widget.filterByPlannedStartDate != null
              ? DateTimeHelper.toUtcDateTime(widget.filterByPlannedStartDate!)
              : null,
          filterByPlannedEndDate: widget.filterByPlannedEndDate != null
              ? DateTimeHelper.toUtcDateTime(widget.filterByPlannedEndDate!)
              : null,
          filterByDeadlineStartDate: widget.filterByDeadlineStartDate != null
              ? DateTimeHelper.toUtcDateTime(widget.filterByDeadlineStartDate!)
              : null,
          filterByDeadlineEndDate: widget.filterByDeadlineEndDate != null
              ? DateTimeHelper.toUtcDateTime(widget.filterByDeadlineEndDate!)
              : null,
          filterDateOr: widget.filterDateOr,
          filterByTags: widget.filterByTags,
          filterNoTags: widget.filterNoTags,
          filterByCompleted: widget.filterByCompleted,
          search: widget.search,
          parentTaskId: widget.parentTaskId,
          sortByPlannedDate: widget.sortByPlannedDate,
        );

        return await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_tasks == null || !isRefresh) {
            _tasks = result;
          } else {
            _tasks = GetListTasksQueryResponse(
              items: [...result.items],
              totalItemCount: result.totalItemCount,
              totalPageCount: result.totalPageCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }
        });
      },
      onError: (_) {
        if (existingItems != null && _tasks != null) {
          // Restore previous items on error
          setState(() {
            _tasks = GetListTasksQueryResponse(
              items: existingItems!,
              totalItemCount: _tasks!.totalItemCount,
              totalPageCount: _tasks!.totalPageCount,
              pageIndex: _tasks!.pageIndex,
              pageSize: _tasks!.pageSize,
            );
          });
        }
      },
    );
  }

  void _onTaskCompleted() {
    widget.onTaskCompleted?.call();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!mounted) return;

    final items = List<TaskListItem>.from(_tasks!.items)..sort((a, b) => a.order.compareTo(b.order));
    final task = items[oldIndex];

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final existingOrders = items.map((item) => item.order).toList()..removeAt(oldIndex);

    try {
      double targetOrder;
      if (newIndex == 0) {
        targetOrder = existingOrders.first - OrderRank.initialStep;
      } else {
        targetOrder = OrderRank.getTargetOrder(existingOrders, newIndex);
        // Collision check
        if (existingOrders.contains(targetOrder)) {
          throw RankGapTooSmallException();
        }
        // Gap check
        if (newIndex > 0 && (existingOrders[newIndex] - existingOrders[newIndex - 1]).abs() < 1e-8) {
          throw RankGapTooSmallException();
        }
      }

      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
        operation: () async {
          await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
            UpdateTaskOrderCommand(
              taskId: task.id,
              parentTaskId: widget.parentTaskId,
              beforeTaskOrder: task.order,
              afterTaskOrder: targetOrder,
            ),
          );
        },
        onSuccess: () {
          refresh();
        },
      );
    } catch (e) {
      if (e is RankGapTooSmallException) {
        final targetOrder = items.last.order + OrderRank.initialStep * 2;
        if (mounted) {
          await AsyncErrorHandler.executeVoid(
            context: context,
            errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
            operation: () async {
              await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
                UpdateTaskOrderCommand(
                  taskId: task.id,
                  parentTaskId: widget.parentTaskId,
                  beforeTaskOrder: task.order,
                  afterTaskOrder: targetOrder,
                ),
              );
            },
            onSuccess: () {
              refresh();
            },
          );
        }
      }
    }
  }

  List<Widget> _buildTaskCards() {
    final items = _tasks!.items.where((task) => task.id != widget.selectedTask?.id).toList();
    return items
        .map((task) => Material(
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
                  if (widget.enableReordering && widget.filterByCompleted != true)
                    ReorderableDragStartListener(
                      index: items.indexOf(task),
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                ],
                onCompleted: _onTaskCompleted,
                onOpenDetails: () => widget.onClickTask(task),
                onScheduled: !task.isCompleted && widget.onScheduleTask != null
                    ? () => widget.onScheduleTask!(task, DateTime.now())
                    : null,
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) {
      // No loading indicator because local DB is fast
      return const SizedBox.shrink();
    }

    if (_tasks!.items.isEmpty || (_tasks!.items.length == 1 && widget.selectedTask != null)) {
      return widget.showDoneOverlayWhenEmpty
          ? IconOverlay(
              icon: Icons.done_all_rounded,
              iconSize: AppTheme.iconSize2XLarge,
              message: _translationService.translate(TaskTranslationKeys.allTasksDone),
            )
          : IconOverlay(
              icon: Icons.check_circle_outline,
              message: _translationService.translate(TaskTranslationKeys.noTasks),
            );
    }

    return ListView(
      key: _pageStorageKey,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      controller: _scrollController,
      children: [
        if (widget.enableReordering && widget.filterByCompleted != true)
          Material(
            type: MaterialType.transparency,
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              proxyDecorator: (child, index, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.scale(
                  scale: Curves.easeInOut.transform(animation.value) * 0.02 + 1,
                  child: Material(
                    elevation: Curves.easeInOut.transform(animation.value) * 5 + 1,
                    child: child,
                  ),
                ),
                child: child,
              ),
              onReorder: _onReorder,
              children: _buildTaskCards(),
            ),
          )
        else
          ..._buildTaskCards(),
        if (_tasks!.hasNext)
          LoadMoreButton(
            onPressed: () => _getTasks(pageIndex: _tasks!.pageIndex + 1),
          ),
      ],
    );
  }
}
