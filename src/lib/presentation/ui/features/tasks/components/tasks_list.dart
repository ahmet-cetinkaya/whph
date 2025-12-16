import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';

class TaskList extends StatefulWidget implements IPaginatedWidget {
  final int pageSize;

  // Filter props to match query parameters
  final List<String>? filterByTags;
  final bool filterNoTags;
  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final bool filterDateOr;
  final bool? filterByCompleted;
  final DateTime? filterByCompletedStartDate;
  final DateTime? filterByCompletedEndDate;
  final String? search;
  final String? parentTaskId;
  final bool includeSubTasks;
  final bool showDoneOverlayWhenEmpty;
  final bool ignoreArchivedTagVisibility;

  final TaskListItem? selectedTask;
  final bool showSelectButton;
  final bool transparentCards;
  final bool enableReordering;
  final bool forceOriginalLayout;
  final bool useParentScroll;

  final void Function(TaskListItem task) onClickTask;
  final void Function(int count)? onList;
  final void Function()? onTaskCompleted;
  final void Function(TaskListItem task)? onSelectTask;
  final void Function(TaskListItem task, DateTime date)? onScheduleTask;
  final void Function(List<TaskListItem> tasks)? onTasksLoaded;
  final List<Widget> Function(TaskListItem task)? trailingButtons;
  final Key? rebuildKey;
  final SortConfig<TaskSortFields>? sortConfig;
  final void Function()? onReorderComplete;
  @override
  final PaginationMode paginationMode;

  const TaskList({
    super.key,
    this.pageSize = 10,
    this.filterByTags,
    this.filterNoTags = false,
    this.filterByPlannedStartDate,
    this.filterByPlannedEndDate,
    this.filterByDeadlineStartDate,
    this.filterByDeadlineEndDate,
    this.filterDateOr = false,
    this.filterByCompleted,
    this.filterByCompletedStartDate,
    this.filterByCompletedEndDate,
    this.search,
    this.parentTaskId,
    this.includeSubTasks = false,
    this.selectedTask,
    this.showSelectButton = false,
    this.transparentCards = false,
    this.enableReordering = false,
    this.forceOriginalLayout = false,
    this.useParentScroll = true,
    this.showDoneOverlayWhenEmpty = false,
    this.ignoreArchivedTagVisibility = false,
    required this.onClickTask,
    this.onList,
    this.onTaskCompleted,
    this.onSelectTask,
    this.onScheduleTask,
    this.onTasksLoaded,
    this.trailingButtons,
    this.rebuildKey,
    this.sortConfig,
    this.onReorderComplete,
    this.paginationMode = PaginationMode.loadMore,
  });

  @override
  State<TaskList> createState() => TaskListState();
}

class TaskListState extends State<TaskList> with PaginationMixin<TaskList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tasksService = container.resolve<TasksService>();
  GetListTasksQueryResponse? _tasks;
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollPosition;
  final PageStorageKey _pageStorageKey = const PageStorageKey<String>('task_list_scroll');

  // Drag state notifier for reorderable list
  late final DragStateNotifier _dragStateNotifier;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _tasks?.hasNext ?? false;

  @override
  void initState() {
    super.initState();
    _dragStateNotifier = DragStateNotifier();
    _getTasksList();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _dragStateNotifier.dispose();
    _removeEventListeners();
    _scrollController.dispose();
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
    await _getTasksList(isRefresh: true);
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
    // Then check other filters
    final oldFilters = {
      'completed': oldWidget.filterByCompleted,
      'completedStartDate': oldWidget.filterByCompletedStartDate?.toIso8601String(),
      'completedEndDate': oldWidget.filterByCompletedEndDate?.toIso8601String(),
      'tags': oldWidget.filterByTags?.join(','),
      'noTags': oldWidget.filterNoTags,
      'search': oldWidget.search,
      'parentTaskId': oldWidget.parentTaskId,
      'includeSubTasks': oldWidget.includeSubTasks,
      'plannedStartDate': oldWidget.filterByPlannedStartDate?.toIso8601String(),
      'plannedEndDate': oldWidget.filterByPlannedEndDate?.toIso8601String(),
      'deadlineStartDate': oldWidget.filterByDeadlineStartDate?.toIso8601String(),
      'deadlineEndDate': oldWidget.filterByDeadlineEndDate?.toIso8601String(),
      'sortConfig': oldWidget.sortConfig,
    };

    final newFilters = {
      'completed': widget.filterByCompleted,
      'completedStartDate': widget.filterByCompletedStartDate?.toIso8601String(),
      'completedEndDate': widget.filterByCompletedEndDate?.toIso8601String(),
      'tags': widget.filterByTags?.join(','),
      'noTags': widget.filterNoTags,
      'search': widget.search,
      'parentTaskId': widget.parentTaskId,
      'includeSubTasks': widget.includeSubTasks,
      'plannedStartDate': widget.filterByPlannedStartDate?.toIso8601String(),
      'plannedEndDate': widget.filterByPlannedEndDate?.toIso8601String(),
      'deadlineStartDate': widget.filterByDeadlineStartDate?.toIso8601String(),
      'deadlineEndDate': widget.filterByDeadlineEndDate?.toIso8601String(),
      'sortConfig': widget.sortConfig,
    };

    return CollectionUtils.hasAnyMapValueChanged(oldFilters, newFilters);
  }

  Future<void> _getTasksList({int pageIndex = 0, bool isRefresh = false}) async {
    await AsyncErrorHandler.execute<GetListTasksQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.getTagsError),
      operation: () async {
        final query = GetListTasksQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh && (_tasks?.items.length ?? 0) > widget.pageSize
              ? _tasks?.items.length ?? widget.pageSize
              : widget.pageSize,
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
          filterByCompletedStartDate: widget.filterByCompletedStartDate != null
              ? DateTimeHelper.toUtcDateTime(widget.filterByCompletedStartDate!)
              : null,
          filterByCompletedEndDate: widget.filterByCompletedEndDate != null
              ? DateTimeHelper.toUtcDateTime(widget.filterByCompletedEndDate!)
              : null,
          filterByTags: widget.filterByTags,
          filterNoTags: widget.filterNoTags,
          filterByCompleted: widget.filterByCompleted,
          filterBySearch: widget.search,
          filterByParentTaskId: widget.parentTaskId,
          areParentAndSubTasksIncluded: widget.includeSubTasks,
          sortBy: widget.sortConfig?.orderOptions,
          sortByCustomSort: widget.sortConfig?.useCustomOrder ?? false,
          ignoreArchivedTagVisibility: widget.ignoreArchivedTagVisibility,
        );

        return await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_tasks == null || isRefresh) {
            _tasks = result;
          } else {
            _tasks = GetListTasksQueryResponse(
              items: [..._tasks!.items, ...result.items],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }
        });

        // Notify about loaded tasks
        widget.onTasksLoaded?.call(_tasks?.items ?? []);

        // Notify about incomplete task count (for confetti logic)
        final incompleteTasks = _tasks?.items.where((task) => !task.isCompleted).length ?? 0;
        widget.onList?.call(incompleteTasks);

        // Check if we need to normalize very small orders
        if (widget.enableReordering && _shouldNormalizeOrders(_tasks!.items)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _normalizeTaskOrders();
          });
        }

        // For infinity scroll: check if viewport needs more content
        if (widget.paginationMode == PaginationMode.infinityScroll && _tasks!.hasNext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndFillViewport();
          });
        }
      },
    );
  }

  void _onTaskCompleted() {
    widget.onTaskCompleted?.call();
  }

  List<TaskListItem> _getFilteredTasks() {
    if (_tasks == null) return [];
    return _tasks!.items.where((task) => task.id != widget.selectedTask?.id).toList();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!mounted) return;

    // Start dragging state
    _dragStateNotifier.startDragging();

    final items = _getFilteredTasks();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final task = items[oldIndex];
    final originalOrder = task.order;

    // Apply visual reordering immediately
    setState(() {
      final reorderedItems = List<TaskListItem>.from(_tasks!.items);
      final taskToMove = reorderedItems.removeAt(oldIndex);
      reorderedItems.insert(newIndex, taskToMove);
      _tasks = GetListTasksQueryResponse(
        items: reorderedItems,
        totalItemCount: _tasks!.totalItemCount,
        pageIndex: _tasks!.pageIndex,
        pageSize: _tasks!.pageSize,
      );
    });

    // Get target order for server update
    final existingOrders = items.map((item) => item.order).toList()..removeAt(oldIndex);
    double targetOrder;

    try {
      if (newIndex == 0) {
        final firstOrder = existingOrders.isNotEmpty ? existingOrders.first : OrderRank.initialStep;
        if (firstOrder <= 0 || firstOrder < 1e-10) {
          targetOrder = OrderRank.initialStep / 2;
        } else if (firstOrder < 1e-6) {
          targetOrder = firstOrder / 1000;
        } else {
          targetOrder = firstOrder - OrderRank.initialStep;
          if (targetOrder <= 0) {
            targetOrder = firstOrder / 2;
          }
        }
      } else {
        targetOrder = OrderRank.getTargetOrder(existingOrders, newIndex);
      }

      if ((targetOrder - originalOrder).abs() < 1e-10) {
        _dragStateNotifier.stopDragging();
        return; // No real change in order
      }

      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
        operation: () async {
          await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
            UpdateTaskOrderCommand(
              taskId: task.id,
              parentTaskId: widget.parentTaskId,
              beforeTaskOrder: originalOrder,
              afterTaskOrder: targetOrder,
            ),
          );
        },
        onSuccess: () {
          _dragStateNotifier.stopDragging();
          widget.onReorderComplete?.call();
          // Refresh in background to sync with server
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) refresh();
          });
        },
        onError: (_) {
          _dragStateNotifier.stopDragging();
          if (mounted) refresh(); // Revert on error
        },
      );
    } catch (e) {
      if (e is RankGapTooSmallException && mounted) {
        // Try to recover by placing at the end
        final targetOrder = items.last.order + OrderRank.initialStep * 2;

        await AsyncErrorHandler.executeVoid(
          context: context,
          errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
          operation: () async {
            await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
              UpdateTaskOrderCommand(
                taskId: task.id,
                parentTaskId: widget.parentTaskId,
                beforeTaskOrder: originalOrder,
                afterTaskOrder: targetOrder,
              ),
            );
          },
          onSuccess: () {
            _dragStateNotifier.stopDragging();
            widget.onReorderComplete?.call();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) refresh();
            });
          },
          onError: (_) {
            _dragStateNotifier.stopDragging();
            if (mounted) refresh(); // Revert on error
          },
        );
      } else {
        _dragStateNotifier.stopDragging();
        if (mounted) refresh(); // Revert on other errors
      }
    }
  }

  @override
  Future<void> onLoadMore() async {
    if (_tasks == null || !_tasks!.hasNext) return;

    _saveScrollPosition();
    await _getTasksList(pageIndex: _tasks!.pageIndex + 1);
    _backLastScrollPosition();
  }

  List<Widget> _buildTaskCards() {
    final items = _getFilteredTasks();
    return items
        .map((task) => Container(
              key: ValueKey(task.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.size3XSmall),
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
                    if (widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout)
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
                  isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                  isCustomOrder:
                      widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout,
                ),
              ),
            ))
        .toList();
  }

  // Helper method to check and normalize very small orders
  bool _shouldNormalizeOrders(List<TaskListItem> items) {
    return items.any((item) => item.order.abs() < 1e-10 || (item.order > 0 && item.order < 1e-6));
  }

  Future<void> _normalizeTaskOrders() async {
    if (_tasks == null) return;

    final items = _tasks!.items;
    final shouldNormalize = _shouldNormalizeOrders(items);

    if (!shouldNormalize) return;

    // Sort items by current order to maintain relative positioning
    final sortedItems = List<TaskListItem>.from(items)..sort((a, b) => a.order.compareTo(b.order));

    // Normalize orders with proper spacing
    for (int i = 0; i < sortedItems.length; i++) {
      final newOrder = (i + 1) * OrderRank.initialStep;
      final item = sortedItems[i];

      if ((item.order - newOrder).abs() > 1e-10) {
        await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
          UpdateTaskOrderCommand(
            taskId: item.id,
            parentTaskId: widget.parentTaskId,
            beforeTaskOrder: item.order,
            afterTaskOrder: newOrder,
          ),
        );
      }
    }

    // Refresh to get updated orders
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DragStateProvider(
      notifier: _dragStateNotifier,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_tasks == null) {
      // No loading indicator because local DB is fast
      return const SizedBox.shrink();
    }

    if (_tasks!.items.isEmpty || (_tasks!.items.length == 1 && widget.selectedTask != null)) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: widget.showDoneOverlayWhenEmpty
            ? IconOverlay(
                icon: Icons.done_all_rounded,
                iconSize: AppTheme.iconSize2XLarge,
                message: _translationService.translate(TaskTranslationKeys.allTasksDone),
              )
            : IconOverlay(
                icon: Icons.check_circle_outline,
                message: _translationService.translate(TaskTranslationKeys.noTasks),
              ),
      );
    }

    if (widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout) {
      return ReorderableListView(
        key: _pageStorageKey,
        buildDefaultDragHandles: false,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        proxyDecorator: (child, index, animation) => Material(
          elevation: 2,
          child: child,
        ),
        onReorder: _onReorder,
        children: [
          ..._buildTaskCards(),
          if (_tasks!.hasNext && widget.paginationMode == PaginationMode.loadMore)
            Padding(
              key: const ValueKey('load_more_button'),
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(
                  child: LoadMoreButton(
                onPressed: onLoadMore,
              )),
            ),
          if (_tasks!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore)
            Padding(
              key: const ValueKey('loading_indicator'),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    } else {
      final taskCards = _buildTaskCards();
      final showLoadMore = _tasks!.hasNext && widget.paginationMode == PaginationMode.loadMore;
      final showInfinityLoading =
          _tasks!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
      final extraItemCount = (showLoadMore || showInfinityLoading) ? 1 : 0;

      return ListView.builder(
        key: _pageStorageKey,
        controller: widget.paginationMode == PaginationMode.infinityScroll && !widget.useParentScroll
            ? _scrollController
            : null,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        itemCount: taskCards.length + extraItemCount,
        itemBuilder: (context, index) {
          if (index < taskCards.length) {
            return taskCards[index];
          } else if (showLoadMore) {
            // Load more button
            return Padding(
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(
                  child: LoadMoreButton(
                onPressed: onLoadMore,
              )),
            );
          } else if (showInfinityLoading) {
            // Infinity scroll loading indicator
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }
  }
}
