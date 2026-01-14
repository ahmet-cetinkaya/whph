import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';

import 'package:whph/presentation/ui/shared/models/visual_item.dart';
import 'package:whph/presentation/ui/shared/utils/visual_item_utils.dart';
import 'package:whph/presentation/ui/shared/components/list_group_header.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';

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
  final bool includeNullDates;
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
  final bool useSliver;

  final void Function(TaskListItem task) onClickTask;
  final void Function(int count)? onList;
  final void Function(String taskId)? onTaskCompleted;
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
    this.includeNullDates = false,
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
    this.useSliver = false,
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
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;

  // Cache for performance optimization
  Map<String, List<TaskListItem>>? _cachedGroupedTasks;
  List<VisualItem>? _cachedVisualItems;

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
    _refreshDebounce?.cancel();
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
      if (mounted && _scrollController.hasClients && _scrollController.position.hasViewportDimension) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (_savedScrollPosition! <= maxScroll) {
          _scrollController.jumpTo(_savedScrollPosition!);
        } else {
          _scrollController.jumpTo(maxScroll);
        }
      }
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _saveScrollPosition();
    _refreshDebounce?.cancel();

    if (_pendingRefresh) {
      return;
    }

    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _getTasksList(isRefresh: true);
      _backLastScrollPosition();

      if (_pendingRefresh) {
        _pendingRefresh = false;
        refresh();
      }
    });
  }

  void _onSliverReorder(int oldIndex, int newIndex, List<VisualItem<TaskListItem>> visualItems) {
    // Validate bounds before index manipulation
    if (oldIndex < 0 || oldIndex >= visualItems.length) return;
    if (newIndex < 0 || newIndex >= visualItems.length) return;

    // Adjust newIndex when moving item downward (as per SliverReorderableList behavior)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final oldItem = visualItems[oldIndex];
    if (oldItem is! VisualItemSingle<TaskListItem>) return;

    final task = oldItem.data;
    final groupName = task.groupName ?? '';

    final groupedTasks = _groupTasks();
    final groupTasks = groupedTasks[groupName] ?? [];
    if (groupTasks.isEmpty) return;

    final taskGroupIndex = groupTasks.indexWhere((t) => t.id == task.id);
    if (taskGroupIndex == -1) return;

    // Calculate target index within the group by counting preceding items of the same group
    int targetGroupIndex = 0;
    for (int i = 0; i < newIndex; i++) {
      if (i == oldIndex) continue;

      final item = visualItems[i];
      if (item is VisualItemSingle<TaskListItem> && item.data.groupName == groupName) {
        targetGroupIndex++;
      }
    }

    _onReorderInGroup(taskGroupIndex, targetGroupIndex, groupTasks);
  }

  @override
  void didUpdateWidget(TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isLayoutChanged = oldWidget.forceOriginalLayout != widget.forceOriginalLayout;
    final isFilterChanged = _isFilterChanged(oldWidget);

    if ((isLayoutChanged || isFilterChanged) && mounted) {
      // Cancel any pending refresh operations
      _refreshDebounce?.cancel();
      _pendingRefresh = false;

      // For ALL changes including layout and filters, force immediate rebuild to prevent visual corruption
      setState(() {
        // Recreate the tasks list to force complete rebuild
        if (_tasks != null) {
          _tasks = GetListTasksQueryResponse(
            items: _tasks!.items,
            totalItemCount: _tasks!.totalItemCount,
            pageIndex: _tasks!.pageIndex,
            pageSize: _tasks!.pageSize,
          );

          // Invalidate cache
          _cachedGroupedTasks = null;
          _cachedVisualItems = null;
        }
      });

      // Also trigger a data refresh to get updated filtered results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          refresh();
        }
      });
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
      'filterDateOr': oldWidget.filterDateOr,
      'includeNullDates': oldWidget.includeNullDates,
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
      'filterDateOr': widget.filterDateOr,
      'includeNullDates': widget.includeNullDates,
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
          includeNullDates: widget.includeNullDates,
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
          groupBy: widget.sortConfig?.groupOption,
          sortByCustomSort: widget.sortConfig?.useCustomOrder ?? false,
          enableGrouping: widget.sortConfig?.enableGrouping ?? true,
          ignoreArchivedTagVisibility: widget.ignoreArchivedTagVisibility,
        );

        return await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_tasks == null || isRefresh) {
            _tasks = result;
            _cachedGroupedTasks = null; // Invalidate cache
            _cachedVisualItems = null;
          } else {
            // Deduplicate items to ensure uniqueness
            final existingIds = _tasks!.items.map((e) => e.id).toSet();
            final newItems = result.items.where((e) => !existingIds.contains(e.id)).toList();

            _tasks = GetListTasksQueryResponse(
              items: [..._tasks!.items, ...newItems],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
            _cachedGroupedTasks = null; // Invalidate cache
            _cachedVisualItems = null;
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

  @override
  Future<void> onLoadMore() async {
    // Prevent concurrent loads if triggered directly (e.g. via Load More button)
    if (_tasks == null || !_tasks!.hasNext) return;

    _saveScrollPosition();
    await _getTasksList(pageIndex: _tasks!.pageIndex + 1);
    _backLastScrollPosition();
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

  void _updateCacheIfNeeded() {
    if (_tasks == null) {
      _cachedGroupedTasks = null;
      _cachedVisualItems = null;
      return;
    }

    if (_cachedGroupedTasks == null) {
      _cachedGroupedTasks = _groupTasks();
      _cachedVisualItems = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateCacheIfNeeded();
    if (widget.useSliver) {
      if (_tasks == null) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      if (_tasks!.items.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
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
          ),
        );
      }

      return DragStateProvider(
        notifier: _dragStateNotifier,
        child: _buildSliverList(),
      );
    }

    return DragStateProvider(
      notifier: _dragStateNotifier,
      child: _buildContent(context),
    );
  }

  Map<String, List<TaskListItem>> _groupTasks() {
    if (_tasks == null) return {};

    final groupedTasks = <String, List<TaskListItem>>{};
    final filteredTasks = _tasks!.items.where((task) => task.id != widget.selectedTask?.id).toList();

    // Check grouping settings
    final primarySortField =
        widget.sortConfig?.groupOption?.field ?? widget.sortConfig?.orderOptions.firstOrNull?.field;
    final isGroupedByDate = primarySortField == TaskSortFields.createdDate ||
        primarySortField == TaskSortFields.deadlineDate ||
        primarySortField == TaskSortFields.plannedDate ||
        primarySortField == TaskSortFields.modifiedDate;

    // Logic to determine if headers are shown
    bool showHeaders = true;
    if (isGroupedByDate && filteredTasks.isNotEmpty) {
      final firstGroup = filteredTasks.first.groupName;
      bool multipleGroups = filteredTasks.any((t) => t.groupName != firstGroup);
      if (!multipleGroups && firstGroup == SharedTranslationKeys.today) {
        showHeaders = false;
      }
    }

    if (!showHeaders) {
      // Everything in one default group
      groupedTasks[''] = filteredTasks;
      return groupedTasks;
    }

    for (var task in filteredTasks) {
      final groupName = task.groupName ?? '';
      if (!groupedTasks.containsKey(groupName)) {
        groupedTasks[groupName] = [];
      }
      groupedTasks[groupName]!.add(task);
    }
    return groupedTasks;
  }

  Future<void> _onReorderInGroup(int oldIndex, int targetIndex, List<TaskListItem> groupTasks) async {
    if (!mounted) return;
    if (oldIndex < 0 || oldIndex >= groupTasks.length) return;

    _dragStateNotifier.startDragging();

    final task = groupTasks[oldIndex];
    final originalOrder = task.order;

    // Apply visual update immediately
    setState(() {
      final reorderedAllItems = List<TaskListItem>.from(_tasks!.items);
      final globalIndex = reorderedAllItems.indexWhere((t) => t.id == task.id);

      if (globalIndex != -1) {
        reorderedAllItems.removeAt(globalIndex);

        int globalNewIndex;
        final reducedGroup = List<TaskListItem>.from(groupTasks)..removeAt(oldIndex);

        if (targetIndex < reducedGroup.length) {
          // Inserting before an item in the group
          final anchorItem = reducedGroup[targetIndex];
          globalNewIndex = reorderedAllItems.indexWhere((t) => t.id == anchorItem.id);
        } else {
          // Inserting at the end of the group
          if (reducedGroup.isNotEmpty) {
            final lastItem = reducedGroup.last;
            globalNewIndex = reorderedAllItems.indexWhere((t) => t.id == lastItem.id) + 1;
          } else {
            // Group became empty (except this item), put it back at original relative position locally?
            globalNewIndex = globalIndex;
          }
        }

        if (globalNewIndex != -1) {
          if (globalNewIndex < 0) globalNewIndex = 0;
          if (globalNewIndex > reorderedAllItems.length) globalNewIndex = reorderedAllItems.length;

          reorderedAllItems.insert(globalNewIndex, task);
        } else {
          reorderedAllItems.insert(globalIndex, task);
        }

        _tasks = GetListTasksQueryResponse(
          items: reorderedAllItems,
          totalItemCount: _tasks!.totalItemCount,
          pageIndex: _tasks!.pageIndex,
          pageSize: _tasks!.pageSize,
        );
      }
    });

    try {
      final existingOrders = groupTasks.map((item) => item.order).toList()..removeAt(oldIndex);
      double targetOrder;

      if (targetIndex == 0) {
        final firstOrder = existingOrders.isNotEmpty ? existingOrders.first : OrderRank.initialStep;
        targetOrder = firstOrder - OrderRank.initialStep;
      } else if (targetIndex >= existingOrders.length) {
        final lastOrder = existingOrders.isNotEmpty ? existingOrders.last : 0.0;
        targetOrder = lastOrder + OrderRank.initialStep;
      } else {
        targetOrder = OrderRank.getTargetOrder(existingOrders, targetIndex);
      }

      if ((targetOrder - originalOrder).abs() < 1e-10) {
        _dragStateNotifier.stopDragging();
        return;
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) refresh();
          });
        },
        onError: (_) {
          _dragStateNotifier.stopDragging();
          if (mounted) refresh();
        },
      );
    } catch (e) {
      if (e is RankGapTooSmallException && mounted) {
        // Fallback for RankGapTooSmallException: Try to recover by placing the item at the end of the group
        // with a larger spacing. This helps to resolve the inconsistent order values.
        final retryTargetOrder = (groupTasks.isNotEmpty ? groupTasks.last.order : 0.0) + OrderRank.initialStep * 2;

        await AsyncErrorHandler.executeVoid(
          context: context,
          errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
          operation: () async {
            await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
              UpdateTaskOrderCommand(
                taskId: task.id,
                parentTaskId: widget.parentTaskId,
                beforeTaskOrder: originalOrder,
                afterTaskOrder: retryTargetOrder,
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
            if (mounted) refresh();
          },
        );
      } else {
        _dragStateNotifier.stopDragging();
        if (mounted) refresh();
      }
    }
  }

  // Building the scroll view directly with independent groups
  Widget _buildContent(BuildContext context) {
    final groupedTasks = _groupTasks();
    if (groupedTasks.isEmpty) {
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

    final showLoadMore = _tasks!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _tasks!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;

    final groupEntries = groupedTasks.entries.toList();

    return ListView.builder(
        key: ValueKey('list_content_${widget.forceOriginalLayout}'),
        controller: widget.useParentScroll ? null : _scrollController,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        // Count: groups + load more
        itemCount: groupEntries.length + (showLoadMore || showInfinityLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < groupEntries.length) {
            final entry = groupEntries[index];
            final groupName = entry.key;
            final tasks = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (groupName.isNotEmpty)
                  ListGroupHeader(
                    key: ValueKey('group_header_$groupName'),
                    title: groupName,
                    shouldTranslate: groupName.length > 1,
                  ),

                // Nested Independent List
                if (widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: tasks.length,
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 2,
                      child: child,
                    ),
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      _onReorderInGroup(oldIndex, newIndex, tasks);
                    },
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      final List<Widget> trailingButtons = [];
                      if (widget.trailingButtons != null) {
                        trailingButtons.addAll(widget.trailingButtons!(task));
                      }
                      if (widget.showSelectButton) {
                        trailingButtons.add(IconButton(
                          icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
                          onPressed: () => widget.onSelectTask?.call(task),
                        ));
                      }
                      trailingButtons.add(ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle, color: Colors.grey),
                      ));

                      return Padding(
                          key: ValueKey('task_padding_${task.id}'),
                          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                          child: TaskCard(
                            key: ValueKey('task_card_${task.id}'),
                            taskItem: task,
                            onOpenDetails: () => widget.onClickTask(task),
                            onCompleted:
                                widget.onTaskCompleted != null ? (taskId) => widget.onTaskCompleted!(taskId) : null,
                            onScheduled: (task.isCompleted || widget.onScheduleTask == null)
                                ? null
                                : () => widget.onScheduleTask!(task, DateTime.now()),
                            transparent: widget.transparentCards,
                            trailingButtons: trailingButtons.isNotEmpty ? trailingButtons : null,
                            showSubTasks: widget.includeSubTasks,
                            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                          ));
                    },
                  )
                else
                  // Non-reorderable simple list for this group
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      final List<Widget> trailingButtons = [];
                      if (widget.trailingButtons != null) {
                        trailingButtons.addAll(widget.trailingButtons!(task));
                      }
                      if (widget.showSelectButton) {
                        trailingButtons.add(IconButton(
                          icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
                          onPressed: () => widget.onSelectTask?.call(task),
                        ));
                      }

                      return Padding(
                          key: ValueKey('task_padding_${task.id}'),
                          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                          child: TaskCard(
                            key: ValueKey('task_card_${task.id}'),
                            taskItem: task,
                            onOpenDetails: () => widget.onClickTask(task),
                            onCompleted: widget.onTaskCompleted,
                            onScheduled: (task.isCompleted || widget.onScheduleTask == null)
                                ? null
                                : () => widget.onScheduleTask!(task, DateTime.now()),
                            transparent: widget.transparentCards,
                            trailingButtons: trailingButtons.isNotEmpty ? trailingButtons : null,
                            showSubTasks: widget.includeSubTasks,
                            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                          ));
                    },
                  )
              ],
            );
          } else if (showLoadMore) {
            return Padding(
              key: ValueKey('load_more_button_list_${widget.forceOriginalLayout}'),
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(
                  child: LoadMoreButton(
                onPressed: onLoadMore,
              )),
            );
          } else if (showInfinityLoading) {
            return Padding(
              key: ValueKey('loading_indicator_list_${widget.forceOriginalLayout}'),
              padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox.shrink();
        });
  }

  Widget _buildTaskItem(
    BuildContext context,
    int index,
    List<VisualItem<TaskListItem>> visualItems,
    bool showLoadMore,
    bool showInfinityLoading,
  ) {
    if (index >= visualItems.length) {
      if (showLoadMore) {
        return Padding(
          key: ValueKey('load_more_button_sliver_list_${widget.forceOriginalLayout}'),
          padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
          child: Center(
            child: LoadMoreButton(onPressed: onLoadMore),
          ),
        );
      } else if (showInfinityLoading) {
        return Padding(
          key: ValueKey('loading_indicator_sliver_list_${widget.forceOriginalLayout}'),
          padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return const SizedBox.shrink();
    }

    final item = visualItems[index];

    if (item is VisualItemHeader<TaskListItem>) {
      return ListGroupHeader(
        key: ValueKey('group_header_${item.title}'),
        title: item.title,
        shouldTranslate: item.title.length > 1,
      );
    } else if (item is VisualItemSingle<TaskListItem>) {
      final task = item.data;
      final List<Widget> trailingButtons = [];
      if (widget.trailingButtons != null) {
        trailingButtons.addAll(widget.trailingButtons!(task));
      }
      if (widget.showSelectButton) {
        trailingButtons.add(IconButton(
          icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
          onPressed: () => widget.onSelectTask?.call(task),
        ));
      }
      if (widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout) {
        trailingButtons.add(ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: Colors.grey),
        ));
      }

      return Padding(
        key: ValueKey('task_padding_${task.id}'),
        padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
        child: TaskCard(
          key: ValueKey('task_card_${task.id}'),
          taskItem: task,
          onOpenDetails: () => widget.onClickTask(task),
          onCompleted: widget.onTaskCompleted != null ? (taskId) => widget.onTaskCompleted!(taskId) : null,
          onScheduled: (task.isCompleted || widget.onScheduleTask == null)
              ? null
              : () => widget.onScheduleTask!(task, DateTime.now()),
          transparent: widget.transparentCards,
          trailingButtons: trailingButtons.isNotEmpty ? trailingButtons : null,
          showSubTasks: widget.includeSubTasks,
          isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
          isCustomOrder: widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSliverList() {
    // Ensure grouping is cached
    _cachedGroupedTasks ??= _groupTasks();

    // Ensure visual items are cached
    _cachedVisualItems ??= VisualItemUtils.getVisualItems<TaskListItem>(
      groupedItems: _cachedGroupedTasks!,
    );

    final visualItems = _cachedVisualItems!.cast<VisualItem<TaskListItem>>();
    final showLoadMore = _tasks!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _tasks!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
    final totalCount = visualItems.length + (showLoadMore || showInfinityLoading ? 1 : 0);

    if (widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout) {
      return SliverReorderableList(
        itemCount: totalCount,
        onReorder: (oldIndex, newIndex) => _onSliverReorder(oldIndex, newIndex, visualItems),
        proxyDecorator: (child, index, animation) => Material(
          elevation: 2,
          color: Colors.transparent,
          child: child,
        ),
        itemBuilder: (context, index) => _buildTaskItem(
          context,
          index,
          visualItems,
          showLoadMore,
          showInfinityLoading,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildTaskItem(
          context,
          index,
          visualItems,
          showLoadMore,
          showInfinityLoading,
        ),
        childCount: totalCount,
      ),
    );
  }
}
