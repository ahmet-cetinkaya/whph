import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/core/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/utils/task_grouping_helper.dart';
import 'package:whph/core/application/shared/utils/group_key_result.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
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
import 'package:whph/presentation/ui/shared/mixins/list_group_collapse_mixin.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_board_view.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart' as core_shared;

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

  /// Current view mode; when [TaskViewMode.board] the widget renders a
  /// horizontal Kanban board instead of a vertical list.
  final TaskViewMode viewMode;

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
  final void Function(TaskListItem task, String fromGroupKey, String toGroupKey)? onCardMovedAcrossColumns;

  /// Callback when add button in a group/column header is clicked
  final void Function(String groupKey)? onAddToGroup;

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
    this.viewMode = TaskViewMode.list,
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
    this.onCardMovedAcrossColumns,
    this.onAddToGroup,
  });

  @override
  State<TaskList> createState() => TaskListState();
}

class TaskListState extends State<TaskList> with PaginationMixin<TaskList>, ListGroupCollapseMixin<TaskList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tasksService = container.resolve<TasksService>();
  final _recurrenceService = container.resolve<ITaskRecurrenceService>();
  GetListTasksQueryResponse? _tasks;
  final ScrollController _scrollController = ScrollController();
  double? _savedScrollPosition;
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;

  // Cache for performance optimization
  Map<String, List<TaskListItem>>? _cachedGroupedTasks;
  List<VisualItem>? _cachedVisualItems;

  // Ordered task statuses, loaded when grouping the board by status so empty
  // status columns still render.
  List<TaskStatusListItem> _statuses = const [];

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
    refresh().catchError((e, stackTrace) {
      Logger.error('Failed to refresh task list after update event', error: e, stackTrace: stackTrace);
    });
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
    final isViewModeChanged = oldWidget.viewMode != widget.viewMode;

    if (isViewModeChanged && mounted) {
      // Clear all caches unconditionally when view mode changes
      // The BoardView builds entirely differently from the List view
      // and needs empty state to be correctly reinitialized.
      setState(() {
        _tasks = null;
        _cachedGroupedTasks = null;
        _cachedVisualItems = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          refresh().catchError((e, stackTrace) {
            Logger.error('Failed to refresh task list after view mode change', error: e, stackTrace: stackTrace);
          });
        }
      });
      return;
    }

    if ((isLayoutChanged || isFilterChanged) && mounted) {
      _refreshDebounce?.cancel();
      _pendingRefresh = false;

      setState(() {
        if (_tasks != null) {
          _tasks = GetListTasksQueryResponse(
            items: _tasks!.items,
            totalItemCount: _tasks!.totalItemCount,
            pageIndex: _tasks!.pageIndex,
            pageSize: _tasks!.pageSize,
          );

          _cachedGroupedTasks = null;
          _cachedVisualItems = null;
        }
      });

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
      errorMessage: _translationService.translate(TaskTranslationKeys.getTasksError),
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
          customTagSortOrder: widget.sortConfig?.customTagSortOrder,
          ignoreArchivedTagVisibility: widget.ignoreArchivedTagVisibility,
        );

        if (_primaryGroupField == TaskSortFields.status) {
          await _loadStatusesForBoard();
        }

        return await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(query);
      },
      onSuccess: (result) {
        try {
          setState(() {
            if (_tasks == null || isRefresh) {
              _tasks = result;
              _cachedGroupedTasks = null;
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
              _cachedGroupedTasks = null;
              _cachedVisualItems = null;
            }
          });

          if (_tasks != null) {
            // Safely notify callbacks
            try {
              widget.onTasksLoaded?.call(_tasks!.items);
            } catch (e, stackTrace) {
              Logger.error('Failed to invoke onTasksLoaded callback', error: e, stackTrace: stackTrace);
            }

            try {
              final incompleteTasks = _tasks!.items.where((task) => !task.isCompleted).length;
              widget.onList?.call(incompleteTasks);
            } catch (e, stackTrace) {
              Logger.error('Failed to invoke onList callback', error: e, stackTrace: stackTrace);
            }

            // Check if we need to normalize very small orders
            if (widget.enableReordering && _shouldNormalizeOrders(_tasks!.items)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _normalizeTaskOrders().catchError((e, stackTrace) {
                    Logger.error('Failed to normalize task orders in post-frame callback',
                        error: e, stackTrace: stackTrace);
                  });
                }
              });
            }

            // For infinity scroll: check if viewport needs more content
            if (widget.paginationMode == PaginationMode.infinityScroll && _tasks!.hasNext) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  try {
                    checkAndFillViewport();
                  } catch (e, stackTrace) {
                    Logger.error('Failed to fill viewport in post-frame callback', error: e, stackTrace: stackTrace);
                  }
                }
              });
            }
          }
        } catch (e, stackTrace) {
          Logger.error('Failed to update task list state', error: e, stackTrace: stackTrace);
        }
      },
    );
  }

  /// Fetches statuses from the API. Built-in statuses are always included
  /// by the query handler, so the board always has Todo and Done columns.
  Future<void> _loadStatusesForBoard() async {
    final response = await _mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
      const GetListTaskStatusesQuery(pageIndex: 0, pageSize: 100),
    );
    _statuses = response.items;
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

    try {
      final items = _tasks!.items;
      final shouldNormalize = _shouldNormalizeOrders(items);

      if (!shouldNormalize) return;

      // Sort items by current order to maintain relative positioning
      final sortedItems = List<TaskListItem>.from(items)..sort((a, b) => a.order.compareTo(b.order));

      int successCount = 0;
      int failureCount = 0;

      // Normalize orders with proper spacing
      for (int i = 0; i < sortedItems.length; i++) {
        final newOrder = (i + 1) * OrderRank.initialStep;
        final item = sortedItems[i];

        if ((item.order - newOrder).abs() > 1e-10) {
          try {
            await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
              UpdateTaskOrderCommand(
                taskId: item.id,
                parentTaskId: widget.parentTaskId,
                beforeTaskOrder: item.order,
                afterTaskOrder: newOrder,
              ),
            );
            successCount++;
          } catch (e, stackTrace) {
            failureCount++;
            Logger.error(
              'Failed to normalize order for task ${item.id}',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      }

      if (failureCount > 0) {
        Logger.warning('Completed normalization with $failureCount failures and $successCount successes.');
      }

      // Refresh to get updated orders
      await refresh();
    } catch (e, stackTrace) {
      Logger.error('Critical error during task order normalization', error: e, stackTrace: stackTrace);
    }
  }

  String _getGroupDisplayLabel(String groupName, List<TaskListItem> tasks) {
    // Check if this is a status ID (for status grouping)
    final firstTask = tasks.firstOrNull;
    final isTranslatable = firstTask?.isGroupNameTranslatable ?? false;

    // For status grouping, groupName is the statusId
    // Look up the status to get the display label
    final status = _statuses.cast<TaskStatusListItem?>().firstWhere(
          (s) => s?.id == groupName,
          orElse: () => null,
        );

    if (status != null) {
      // Status found - use its name or translate
      if (status.name.isEmpty) {
        // Empty name = built-in status, use translation
        final translationKey =
            status.isDoneStatus ? TaskTranslationKeys.statusBuiltInDone : TaskTranslationKeys.statusBuiltInTodo;
        return _translationService.translate(translationKey);
      } else {
        // Custom status with user-defined name
        return status.name;
      }
    }

    // Not a status or status not found, use default logic
    return isTranslatable ? _translationService.translate(groupName) : groupName;
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

  /// The field tasks are currently grouped by (drives board columns).
  TaskSortFields? get _primaryGroupField =>
      widget.sortConfig?.groupOption?.field ?? widget.sortConfig?.orderOptions.firstOrNull?.field;

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

  /// Returns a map of group name to whether it should be translated
  Map<String, bool> _getGroupTranslatableMap() {
    if (_cachedGroupedTasks == null) return {};
    return {
      for (final entry in _cachedGroupedTasks!.entries)
        if (entry.key.isNotEmpty) entry.key: entry.value.isNotEmpty ? entry.value.first.isGroupNameTranslatable : false,
    };
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
        try {
          await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
            UpdateTaskOrderCommand(
              taskId: task.id,
              parentTaskId: widget.parentTaskId,
              beforeTaskOrder: originalOrder,
              afterTaskOrder: targetOrder,
            ),
          );
        } on RankGapTooSmallException {
          // Fallback for RankGapTooSmallException: Try to recover by placing the item at the end of the group
          // with a larger spacing. This helps to resolve the inconsistent order values.
          final retryTargetOrder = (groupTasks.isNotEmpty ? groupTasks.last.order : 0.0) + OrderRank.initialStep * 2;
          await _mediator.send<UpdateTaskOrderCommand, UpdateTaskOrderResponse>(
            UpdateTaskOrderCommand(
              taskId: task.id,
              parentTaskId: widget.parentTaskId,
              beforeTaskOrder: originalOrder,
              afterTaskOrder: retryTargetOrder,
            ),
          );
        }
      },
      onSuccess: () {
        _dragStateNotifier.stopDragging();
        try {
          widget.onReorderComplete?.call();
        } catch (e, stackTrace) {
          Logger.error('Failed to invoke onReorderComplete callback', error: e, stackTrace: stackTrace);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            refresh().catchError((e, stackTrace) {
              Logger.error('Failed to refresh task list after reorder success', error: e, stackTrace: stackTrace);
            });
          }
        });
      },
      onError: (_) {
        _dragStateNotifier.stopDragging();
        if (mounted) {
          refresh().catchError((e, stackTrace) {
            Logger.error('Failed to refresh task list after reorder error', error: e, stackTrace: stackTrace);
          });
        }
      },
    );
  }

  /// Persists a card moved to a different board column by mutating the
  /// group-defining field (priority or planned/deadline date).
  Future<void> _onCardMovedAcrossColumns(TaskListItem task, String fromGroupKey, String toGroupKey) async {
    if (!mounted || fromGroupKey == toGroupKey) return;

    final groupField = _primaryGroupField;
    if (!TaskGroupingHelper.isCrossColumnMovePersistable(groupField)) return;

    if (groupField == TaskSortFields.tag) {
      await _moveCardToTagColumn(task, fromGroupKey, toGroupKey);
      return;
    }

    if (groupField == TaskSortFields.status) {
      await _moveCardToStatusColumn(task, toGroupKey);
      return;
    }

    _dragStateNotifier.startDragging();

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
      operation: () async {
        final fullTask = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: task.id));

        EisenhowerPriority? priority = fullTask.priority;
        DateTime? plannedDate = fullTask.plannedDate;
        DateTime? deadlineDate = fullTask.deadlineDate;
        DateTime? completedAt = fullTask.completedAt;
        int? estimatedTime = fullTask.estimatedTime;

        switch (groupField) {
          case TaskSortFields.priority:
            priority = TaskGroupingHelper.priorityFromGroupKey(toGroupKey);
            break;
          case TaskSortFields.plannedDate:
            switch (TaskGroupingHelper.dateFromGroupKey(toGroupKey)) {
              case Recognized(:final value):
                plannedDate = value;
              case Unrecognized():
                return;
            }
            break;
          case TaskSortFields.deadlineDate:
            switch (TaskGroupingHelper.dateFromGroupKey(toGroupKey)) {
              case Recognized(:final value):
                deadlineDate = value;
              case Unrecognized():
                return;
            }
            break;
          case TaskSortFields.completedDate:
            switch (TaskGroupingHelper.dateFromGroupKey(toGroupKey)) {
              case Recognized(:final value):
                // The "no date" column means "not completed"; any date bucket
                // marks the task completed at that representative date.
                completedAt = value == null ? null : DateTimeHelper.toUtcDateTime(value);
              case Unrecognized():
                return;
            }
            break;
          case TaskSortFields.estimatedTime:
            switch (TaskGroupingHelper.durationFromGroupKey(toGroupKey)) {
              case Recognized(:final value):
                estimatedTime = value;
              case Unrecognized():
                return;
            }
            break;
          // The remaining TaskSortFields values are not persistable cross-
          // column moves (the early-return at the top of this method already
          // filtered them out, but listing them explicitly keeps the switch
          // exhaustive so a new enum value forces a compile error here).
          // tag is handled by an early-return above.
          case TaskSortFields.title:
          case TaskSortFields.tag:
          case TaskSortFields.status:
          case TaskSortFields.createdDate:
          case TaskSortFields.modifiedDate:
          case TaskSortFields.totalDuration:
          case null:
            return;
        }

        await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          SaveTaskCommand(
            id: fullTask.id,
            title: fullTask.title,
            description: fullTask.description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            completedAt: completedAt,
            parentTaskId: fullTask.parentTaskId,
            order: fullTask.order,
            plannedDateReminderTime: fullTask.plannedDateReminderTime,
            plannedDateReminderCustomOffset: fullTask.plannedDateReminderCustomOffset,
            deadlineDateReminderTime: fullTask.deadlineDateReminderTime,
            deadlineDateReminderCustomOffset: fullTask.deadlineDateReminderCustomOffset,
            recurrenceType: fullTask.recurrenceType,
            recurrenceInterval: fullTask.recurrenceInterval,
            recurrenceDays: _recurrenceService.getRecurrenceDays(fullTask),
            recurrenceStartDate: fullTask.recurrenceStartDate,
            recurrenceEndDate: fullTask.recurrenceEndDate,
            recurrenceCount: fullTask.recurrenceCount,
            recurrenceParentId: fullTask.recurrenceParentId,
            recurrenceConfiguration: fullTask.recurrenceConfiguration,
          ),
        );

        _tasksService.notifyTaskUpdated(task.id);
      },
      onSuccess: () {
        _dragStateNotifier.stopDragging();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            refresh().catchError((e, stackTrace) {
              Logger.error('Failed to refresh task list after cross-column move', error: e, stackTrace: stackTrace);
            });
          }
        });
      },
      onError: (_) {
        _dragStateNotifier.stopDragging();
        if (mounted) {
          refresh().catchError((e, stackTrace) {
            Logger.error('Failed to refresh task list after cross-column move error', error: e, stackTrace: stackTrace);
          });
        }
      },
    );
  }

  /// Persists a cross-column move when grouping by tag.
  ///
  /// Dropping into the "no tag" column ([SharedTranslationKeys.none]) detaches
  /// every tag, making the task untagged. Dropping into a tag column attaches
  /// that column's tag and detaches the source column's tag.
  Future<void> _moveCardToTagColumn(TaskListItem task, String fromGroupKey, String toGroupKey) async {
    final isTargetUntagged = toGroupKey == _translationService.translate(core_shared.SharedTranslationKeys.none) ||
        toGroupKey == core_shared.SharedTranslationKeys.none;

    _dragStateNotifier.startDragging();

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
      operation: () async {
        final taskTags = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          GetListTaskTagsQuery(taskId: task.id, pageIndex: 0, pageSize: 100),
        );

        if (isTargetUntagged) {
          for (final taskTag in taskTags.items) {
            await _mediator.send<RemoveTaskTagCommand, RemoveTaskTagCommandResponse>(
              RemoveTaskTagCommand(id: taskTag.id),
            );
          }
          _tasksService.notifyTaskUpdated(task.id);
          return;
        }

        final targetTagId = await _resolveTagIdByName(toGroupKey);
        if (targetTagId == null) {
          Logger.warning('Cross-column tag move skipped: no tag matches column "$toGroupKey"');
          return;
        }

        final alreadyHasTarget = taskTags.items.any((tt) => tt.tagId == targetTagId);
        if (!alreadyHasTarget) {
          await _mediator.send<AddTaskTagCommand, AddTaskTagCommandResponse>(
            AddTaskTagCommand(taskId: task.id, tagId: targetTagId),
          );
        }

        final sourceAssociation = taskTags.items.where((tt) => tt.tagName == fromGroupKey).firstOrNull;
        if (sourceAssociation != null && sourceAssociation.tagId != targetTagId) {
          await _mediator.send<RemoveTaskTagCommand, RemoveTaskTagCommandResponse>(
            RemoveTaskTagCommand(id: sourceAssociation.id),
          );
        }

        _tasksService.notifyTaskUpdated(task.id);
      },
      onSuccess: () {
        _dragStateNotifier.stopDragging();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            refresh().catchError((e, stackTrace) {
              Logger.error('Failed to refresh task list after tag move', error: e, stackTrace: stackTrace);
            });
          }
        });
      },
      onError: (_) {
        _dragStateNotifier.stopDragging();
        if (mounted) {
          refresh().catchError((e, stackTrace) {
            Logger.error('Failed to refresh task list after tag move error', error: e, stackTrace: stackTrace);
          });
        }
      },
    );
  }

  Future<void> _moveCardToStatusColumn(TaskListItem task, String toGroupKey) async {
    _dragStateNotifier.startDragging();

    // toGroupKey is now the statusId (matching TaskGroupingHelper)
    // Validate it exists in our status list
    final targetStatus = _statuses.cast<TaskStatusListItem?>().firstWhere(
      (s) => s?.id == toGroupKey,
      orElse: () => null,
    );

    if (targetStatus == null) {
      Logger.error('Status not found for group key: $toGroupKey');
      _dragStateNotifier.stopDragging();
      return;
    }

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
      operation: () async {
        final fullTask = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: task.id));

        await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
          SaveTaskCommand(
            id: fullTask.id,
            title: fullTask.title,
            description: fullTask.description,
            priority: fullTask.priority,
            plannedDate: fullTask.plannedDate,
            deadlineDate: fullTask.deadlineDate,
            estimatedTime: fullTask.estimatedTime,
            completedAt: fullTask.completedAt,
            statusId: targetStatus.id,
            parentTaskId: fullTask.parentTaskId,
            order: fullTask.order,
            plannedDateReminderTime: fullTask.plannedDateReminderTime,
            plannedDateReminderCustomOffset: fullTask.plannedDateReminderCustomOffset,
            deadlineDateReminderTime: fullTask.deadlineDateReminderTime,
            deadlineDateReminderCustomOffset: fullTask.deadlineDateReminderCustomOffset,
            recurrenceType: fullTask.recurrenceType,
            recurrenceInterval: fullTask.recurrenceInterval,
            recurrenceDays: _recurrenceService.getRecurrenceDays(fullTask),
            recurrenceStartDate: fullTask.recurrenceStartDate,
            recurrenceEndDate: fullTask.recurrenceEndDate,
            recurrenceCount: fullTask.recurrenceCount,
            recurrenceParentId: fullTask.recurrenceParentId,
            recurrenceConfiguration: fullTask.recurrenceConfiguration,
          ),
        );
        _tasksService.notifyTaskUpdated(task.id);
      },
      onSuccess: () {
        _dragStateNotifier.stopDragging();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            refresh().catchError((e, stackTrace) {
              Logger.error('Failed to refresh task list after status move', error: e, stackTrace: stackTrace);
            });
          }
        });
      },
      onError: (_) {
        _dragStateNotifier.stopDragging();
        if (mounted) {
          refresh().catchError((e, stackTrace) {
            Logger.error('Failed to refresh task list after status move error', error: e, stackTrace: stackTrace);
          });
        }
      },
    );
  }

  /// Resolves a tag id from its display name. Returns null when no exact
  /// (case-insensitive) match exists.
  ///
  /// The tags query's archive filter is exclusive (`is_archived = ?`), so a
  /// single call only sees active *or* archived tags. Active tags are checked
  /// first (the common case); archived tags are a fallback so a board column
  /// backed by an archived tag still resolves.
  Future<String?> _resolveTagIdByName(String tagName) async {
    final lower = tagName.toLowerCase();

    for (final showArchived in [false, true]) {
      final tags = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(
        GetListTagsQuery(pageIndex: 0, pageSize: 100, search: tagName, showArchived: showArchived),
      );
      final match = tags.items.where((t) => t.name.toLowerCase() == lower).firstOrNull;
      if (match != null) return match.id;
    }

    return null;
  }

  @override
  void onGroupCollapseChanged() {
    // Invalidate visual items cache as visibility changes affects the flattened list
    _cachedVisualItems = null;
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

    // Board view: render a Kanban board instead of a vertical list
    if (widget.viewMode == TaskViewMode.board) {
      final groupTranslatable = Map<String, bool>.from(_getGroupTranslatableMap());

      // Fixed-cardinality groupings (priority, date/duration buckets) show every
      // possible column in a stable order, even when empty. Data-driven
      // groupings (tag, status) keep their discovered columns but always expose the
      // empty column so a card can be dropped there to clear the property.
      final fixedKeys = TaskGroupingHelper.fixedColumnKeysFor(_primaryGroupField);
      Map<String, String>? groupLabels;
      late Map<String, List<TaskListItem>> boardGroups;
      if (fixedKeys != null) {
        boardGroups = {for (final key in fixedKeys) key: groupedTasks[key] ?? []};
        for (final key in fixedKeys) {
          groupTranslatable[key] = true;
        }
      } else if (_primaryGroupField == TaskSortFields.status) {
        // Sort statuses: todo first, then by order, then done last
        final sortedStatuses = List<TaskStatusListItem>.from(_statuses);
        sortedStatuses.sort((a, b) {
          // Built-in todo first
          if (a.id == TaskStatusConstants.todoId) return -1;
          if (b.id == TaskStatusConstants.todoId) return 1;
          // Built-in done last
          if (a.id == TaskStatusConstants.doneId) return 1;
          if (b.id == TaskStatusConstants.doneId) return -1;
          // Custom statuses by order
          return a.order.compareTo(b.order);
        });

        final statusBoardGroups = <String, List<TaskListItem>>{};
        final statusGroupLabels = <String, String>{};
        Logger.debug('Building board: groupedTasks keys = ${groupedTasks.keys.toList()}');
        for (final status in sortedStatuses) {
          // Use status.id as group key to match TaskGroupingHelper.getGroupName()
          // which returns statusId for status grouping
          final groupKey = status.id;
          final tasksInGroup = groupedTasks[groupKey] ?? [];
          Logger.debug('Status ${status.id} (${status.name}): ${tasksInGroup.length} tasks');

          statusBoardGroups[groupKey] = tasksInGroup;

          // For display labels:
          if (status.name.isEmpty) {
            // Empty name = use translation (built-in statuses)
            // Store the translation key in groupLabels so the view can translate
            groupTranslatable[groupKey] = true;
            statusGroupLabels[groupKey] =
                status.isDoneStatus ? TaskTranslationKeys.statusBuiltInDone : TaskTranslationKeys.statusBuiltInTodo;
          } else {
            // Custom status with user-defined name
            groupTranslatable[groupKey] = false;
            statusGroupLabels[groupKey] = status.name;
          }
        }
        boardGroups = statusBoardGroups;
        groupLabels = statusGroupLabels;
      } else {
        boardGroups = Map<String, List<TaskListItem>>.from(groupedTasks);
        final emptyGroupKey = TaskGroupingHelper.emptyGroupKeyFor(_primaryGroupField);
        if (emptyGroupKey != null && !boardGroups.containsKey(emptyGroupKey)) {
          boardGroups[emptyGroupKey] = [];
          groupTranslatable[emptyGroupKey] = true;
        }
      }

      return TaskBoardView(
        groupedTasks: boardGroups,
        groupTranslatable: groupTranslatable,
        groupLabels: groupLabels,
        canMoveAcrossColumns: TaskGroupingHelper.isCrossColumnMovePersistable(_primaryGroupField),
        onClickTask: widget.onClickTask,
        onTaskCompleted: widget.onTaskCompleted,
        onScheduleTask: widget.onScheduleTask,
        onCardMovedAcrossColumns: _onCardMovedAcrossColumns,
        trailingButtons: widget.trailingButtons,
        transparentCards: widget.transparentCards,
        onAddToGroup: widget.onAddToGroup,
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
                    title: _getGroupDisplayLabel(groupName, tasks),
                    isExpanded: !collapsedGroups.contains(groupName),
                    onTap: () => toggleGroupCollapse(groupName),
                    actions: widget.onAddToGroup != null
                        ? IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            iconSize: 18,
                            onPressed: () => widget.onAddToGroup!(groupName),
                            tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          )
                        : null,
                  ),

                // Nested Independent List
                if (!collapsedGroups.contains(groupName))
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
                        final isDense = AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);
                        final List<Widget> trailingButtons = [];
                        if (widget.trailingButtons != null) {
                          trailingButtons.addAll(widget.trailingButtons!(task));
                        }
                        if (widget.showSelectButton) {
                          trailingButtons.add(IconButton(
                            key: ValueKey('trailing_select_${task.id}'),
                            icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
                            onPressed: () => widget.onSelectTask?.call(task),
                          ));
                        }
                        trailingButtons.add(ReorderableDragStartListener(
                          key: ValueKey('trailing_drag_${task.id}'),
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall),
                            child: Icon(Icons.drag_handle, color: Colors.grey),
                          ),
                        ));

                        return Padding(
                            key: ValueKey('task_padding_reorderable_${task.id}'),
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
                              isDense: isDense,
                            ));
                      },
                    )
                  else if (!collapsedGroups.contains(groupName))
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
      // For status grouping, item.title is the statusId
      // Look up the status to get the display label
      final status = _statuses.cast<TaskStatusListItem?>().firstWhere(
            (s) => s?.id == item.title,
            orElse: () => null,
          );

      String displayTitle;
      if (status != null && status.name.isEmpty) {
        // Built-in status with empty name - use translation
        final translationKey =
            status.isDoneStatus ? TaskTranslationKeys.statusBuiltInDone : TaskTranslationKeys.statusBuiltInTodo;
        displayTitle = _translationService.translate(translationKey);
      } else if (status != null) {
        // Custom status with user-defined name
        displayTitle = status.name;
      } else {
        // Not a status or status not found - use default logic
        displayTitle = item.isTranslatable ? _translationService.translate(item.title) : item.title;
      }

      return ListGroupHeader(
        key: ValueKey('group_header_${item.title}_${!collapsedGroups.contains(item.title)}'),
        title: displayTitle,
        isExpanded: !collapsedGroups.contains(item.title),
        onTap: () => toggleGroupCollapse(item.title),
      );
    } else if (item is VisualItemSingle<TaskListItem>) {
      final task = item.data;
      final List<Widget> trailingButtons = [];
      if (widget.trailingButtons != null) {
        trailingButtons.addAll(widget.trailingButtons!(task));
      }
      if (widget.showSelectButton) {
        trailingButtons.add(IconButton(
          key: ValueKey('sliver_trailing_select_${task.id}'),
          icon: const Icon(Icons.push_pin_outlined, color: Colors.grey),
          onPressed: () => widget.onSelectTask?.call(task),
        ));
      }
      if (widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout) {
        trailingButtons.add(ReorderableDragStartListener(
          key: ValueKey('sliver_trailing_drag_${task.id}'),
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall),
            child: Icon(Icons.drag_handle, color: Colors.grey),
          ),
        ));
      }

      return Padding(
        key: ValueKey('sliver_task_padding_reorderable_${task.id}'),
        padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
        child: TaskCard(
          key: ValueKey('sliver_task_card_${task.id}'),
          taskItem: task,
          onOpenDetails: () => widget.onClickTask(task),
          onCompleted: widget.onTaskCompleted != null ? (taskId) => widget.onTaskCompleted!(taskId) : null,
          onScheduled: (task.isCompleted || widget.onScheduleTask == null)
              ? null
              : () => widget.onScheduleTask!(task, DateTime.now()),
          transparent: widget.transparentCards,
          trailingButtons: trailingButtons.isNotEmpty ? trailingButtons : null,
          isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
          isCustomOrder: widget.enableReordering && widget.filterByCompleted != true && !widget.forceOriginalLayout,
        ),
      );
    }
    return SizedBox.shrink(key: ValueKey('task_item_empty_$index'));
  }

  Widget _buildSliverList() {
    // Ensure grouping is cached
    _cachedGroupedTasks ??= _groupTasks();

    // Ensure visual items are cached
    _cachedVisualItems ??= VisualItemUtils.getVisualItems<TaskListItem>(
      groupedItems: _cachedGroupedTasks!,
      groupTranslatable: _getGroupTranslatableMap(),
    );

    final fullVisualItems = _cachedVisualItems!.cast<VisualItem<TaskListItem>>();

    // Filter items based on collapsed groups
    final visualItems = <VisualItem<TaskListItem>>[];
    bool isSkipping = false;

    for (var item in fullVisualItems) {
      if (item is VisualItemHeader<TaskListItem>) {
        isSkipping = collapsedGroups.contains(item.title);
        visualItems.add(item);
      } else if (!isSkipping) {
        visualItems.add(item);
      }
    }
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
