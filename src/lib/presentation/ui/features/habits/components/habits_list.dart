import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/list_group_header.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';
import 'package:whph/presentation/ui/shared/models/visual_item.dart';
import 'package:whph/presentation/ui/shared/utils/visual_item_utils.dart';
import 'package:whph/presentation/ui/shared/mixins/list_group_collapse_mixin.dart';

class HabitsList extends StatefulWidget implements IPaginatedWidget {
  final int pageSize;
  final HabitListStyle style;
  final int dateRange;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final bool showDoneOverlayWhenEmpty;
  final bool filterByArchived;
  final String? search;
  final SortConfig<HabitSortFields>? sortConfig;
  final DateTime? excludeCompletedForDate;
  final bool enableReordering;
  final bool useParentScroll;
  final bool useSliver;
  final bool isThreeStateEnabled;
  final bool isReverseDayOrder;

  final void Function(HabitListItem habit) onClickHabit;
  final void Function(int count)? onList;
  final void Function()? onHabitCompleted;
  final void Function(int count)? onListing;
  final void Function()? onReorderComplete;
  @override
  final PaginationMode paginationMode;

  const HabitsList({
    super.key,
    this.pageSize = 10,
    this.style = HabitListStyle.grid,
    this.dateRange = 7,
    this.filterByTags,
    this.filterNoTags = false,
    this.showDoneOverlayWhenEmpty = false,
    this.filterByArchived = false,
    this.search,
    this.sortConfig,
    this.excludeCompletedForDate,
    this.enableReordering = false,
    this.useParentScroll = true,
    this.useSliver = false,
    this.isThreeStateEnabled = false,
    this.isReverseDayOrder = false,
    required this.onClickHabit,
    this.onList,
    this.onHabitCompleted,
    this.onListing,
    this.onReorderComplete,
    this.paginationMode = PaginationMode.loadMore,
  });

  @override
  State<HabitsList> createState() => HabitsListState();
}

class HabitsListState extends State<HabitsList> with PaginationMixin<HabitsList>, ListGroupCollapseMixin<HabitsList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();
  final ScrollController _scrollController = ScrollController();
  GetListHabitsQueryResponse? _habitList;
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;
  late FilterContext _currentFilters;
  double? _savedScrollPosition;

  Map<String, List<HabitListItem>>? _cachedGroupedHabits;
  List<VisualItem>? _cachedVisualItems;

  late final DragStateNotifier _dragStateNotifier;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _habitList?.hasNext ?? false;

  bool get _isCustomOrderActive => widget.enableReordering && widget.sortConfig?.useCustomOrder == true;

  HabitListStyle get _effectiveStyle =>
      _isCustomOrderActive && _showCustomSortIndicator && widget.style == HabitListStyle.grid
          ? HabitListStyle.list
          : widget.style;

  /// Whether the drag indicator is rendered. When hidden, reordering stays
  /// reachable through a whole-card long press.
  bool get _showCustomSortIndicator => widget.sortConfig?.showCustomSortIndicator ?? true;

  /// Whether the list renders group headers.
  bool get _showGroupHeaders =>
      ((widget.sortConfig?.orderOptions.isNotEmpty ?? false) || (widget.sortConfig?.groupOption != null)) &&
      (widget.sortConfig?.enableGrouping ?? false);

  /// The map key [_groupHabits] files [habit] under. When grouping is off the
  /// whole list lives in a single unnamed bucket, even though the query may
  /// still fill `groupName` from the saved sort field — keying off `groupName`
  /// there finds no bucket and silently drops the reorder.
  String _groupKeyOf(HabitListItem habit) => _showGroupHeaders ? (habit.groupName ?? '') : '';

  @override
  void initState() {
    super.initState();
    _dragStateNotifier = DragStateNotifier();
    _currentFilters = _captureCurrentFilters();
    _getHabits();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    _refreshDebounce?.cancel();
    _scrollController.dispose();
    _dragStateNotifier.dispose();
    super.dispose();
  }

  void _setupEventListeners() {
    _habitsService.onHabitCreated.addListener(_handleHabitChange);
    _habitsService.onHabitUpdated.addListener(_handleHabitChange);
    _habitsService.onHabitDeleted.addListener(_handleHabitChange);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChange);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChange);
  }

  void _removeEventListeners() {
    _habitsService.onHabitCreated.removeListener(_handleHabitChange);
    _habitsService.onHabitUpdated.removeListener(_handleHabitChange);
    _habitsService.onHabitDeleted.removeListener(_handleHabitChange);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChange);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChange);
  }

  void _handleHabitChange() {
    if (!mounted) return;
    refresh();
  }

  void _handleHabitRecordChange() {
    if (!mounted) return;

    // Delay refresh in 3-state mode to allow user to toggle states without item vanishing.
    if (widget.isThreeStateEnabled) {
      refresh(delay: const Duration(minutes: 1));
    } else {
      refresh();
    }

    widget.onHabitCompleted?.call();
  }

  @override
  void didUpdateWidget(HabitsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFilters = _captureCurrentFilters();
    if (_isFilterChanged(oldFilters: _currentFilters, newFilters: newFilters)) {
      _currentFilters = newFilters;

      if (mounted) {
        _refreshDebounce?.cancel();
        _pendingRefresh = false;

        setState(() {
          if (_habitList != null) {
            _habitList = GetListHabitsQueryResponse(
              items: _habitList!.items,
              totalItemCount: _habitList!.totalItemCount,
              pageIndex: _habitList!.pageIndex,
              pageSize: _habitList!.pageSize,
            );

            _cachedGroupedHabits = null;
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
  }

  FilterContext _captureCurrentFilters() => FilterContext(
        style: widget.style,
        dateRange: widget.dateRange,
        filterByTags: widget.filterByTags,
        filterNoTags: widget.filterNoTags,
        filterByArchived: widget.filterByArchived,
        search: widget.search,
        sortConfig: widget.sortConfig,
        excludeCompletedForDate: widget.excludeCompletedForDate,
      );

  bool _isFilterChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'style': oldFilters.style,
      'dateRange': oldFilters.dateRange,
      'filterNoTags': oldFilters.filterNoTags,
      'filterByTags': oldFilters.filterByTags,
      'filterByArchived': oldFilters.filterByArchived,
      'search': oldFilters.search,
      'sortConfig': oldFilters.sortConfig,
    };

    final newMap = {
      'style': newFilters.style,
      'dateRange': newFilters.dateRange,
      'filterNoTags': newFilters.filterNoTags,
      'filterByTags': newFilters.filterByTags,
      'filterByArchived': newFilters.filterByArchived,
      'search': newFilters.search,
      'sortConfig': newFilters.sortConfig,
    };

    return CollectionUtils.hasAnyMapValueChanged(oldMap, newMap);
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

  Future<void> refresh({Duration? delay}) async {
    if (!mounted) return;

    _saveScrollPosition();
    _refreshDebounce?.cancel();

    if (_pendingRefresh && delay == null) {
      // If immediate refresh requested while pending, allow it
      return;
    }

    _refreshDebounce = Timer(delay ?? const Duration(milliseconds: 100), () async {
      await _getHabits(isRefresh: true);
      _backLastScrollPosition();

      if (_pendingRefresh) {
        _pendingRefresh = false;
        refresh(); // Refresh again if refresh was requested during the debounce
      }
    });
  }

  Future<void> _getHabits({
    int pageIndex = 0,
    bool isRefresh = false,
  }) async {
    await AsyncErrorHandler.execute<GetListHabitsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingHabitsError),
      operation: () async {
        final query = GetListHabitsQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh && (_habitList?.items.length ?? 0) > widget.pageSize
              ? _habitList?.items.length ?? widget.pageSize
              : widget.pageSize,
          excludeCompleted: _currentFilters.style != HabitListStyle.calendar,
          filterByTags: _currentFilters.filterNoTags ? [] : _currentFilters.filterByTags,
          filterNoTags: _currentFilters.filterNoTags,
          filterByArchived: _currentFilters.filterByArchived,
          search: _currentFilters.search,
          sortBy: _currentFilters.sortConfig?.orderOptions,
          // A saved groupOption stays in settings while grouping is toggled
          // off, so it must not reach the query — under custom sort it would
          // partition the manual ranks by a group the user disabled.
          groupBy:
              (_currentFilters.sortConfig?.enableGrouping ?? false) ? _currentFilters.sortConfig?.groupOption : null,
          sortByCustomSort: _currentFilters.sortConfig?.useCustomOrder ?? false,
          customTagSortOrder: _currentFilters.sortConfig?.customTagSortOrder,
          excludeCompletedForDate: _currentFilters.excludeCompletedForDate,
        );

        return await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_habitList == null || isRefresh) {
            _habitList = result;
            _cachedGroupedHabits = null;
            _cachedVisualItems = null;
          } else {
            _habitList = GetListHabitsQueryResponse(
              items: [..._habitList!.items, ...result.items],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
            _cachedGroupedHabits = null;
            _cachedVisualItems = null;
          }

          widget.onListing?.call(_habitList?.items.length ?? 0);
        });

        // Repair collapsed/duplicate/near-zero order values so the next drag
        // lands reliably. Only relevant when custom ordering is active.
        if (_isCustomOrderActive && _shouldNormalizeOrders(_habitList!.items)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _normalizeHabitOrders();
            }
          });
        }

        if (widget.paginationMode == PaginationMode.infinityScroll && _habitList!.hasNext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndFillViewport();
          });
        }
      },
    );
  }

  /// Detects duplicate or non-canonical ranks that require normalization.
  bool _shouldNormalizeOrders(List<HabitListItem> items) {
    final orders = items.map((item) => item.order).toList();
    return OrderRank.needsNormalization(orders);
  }

  Future<void> _normalizeHabitOrders() async {
    if (_habitList == null) return;
    try {
      if (!_shouldNormalizeOrders(_habitList!.items)) return;

      await _mediator.send<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse>(
        const NormalizeHabitOrdersCommand(),
      );
      await refresh();
    } catch (e, stackTrace) {
      // Best-effort repair; a failed normalization simply leaves orders as-is.
      Logger.error('Failed to normalize habit orders', error: e, stackTrace: stackTrace);
    }
  }

  void _updateCacheIfNeeded() {
    if (_habitList == null) {
      _cachedGroupedHabits = null;
      _cachedVisualItems = null;
      return;
    }

    if (_cachedGroupedHabits == null) {
      _cachedGroupedHabits = _groupHabits();
      _cachedVisualItems = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateCacheIfNeeded();
    if (widget.useSliver) {
      if (_habitList == null) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      if (_habitList!.items.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: SizedBox(
              width: double.infinity,
              child: widget.showDoneOverlayWhenEmpty
                  ? IconOverlay(
                      icon: Icons.done_all_rounded,
                      iconSize: AppTheme.iconSize2XLarge,
                      message: _translationService.translate(HabitTranslationKeys.allHabitsDone),
                    )
                  : IconOverlay(
                      icon: Icons.check_circle_outline,
                      message: _translationService.translate(HabitTranslationKeys.noHabitsFound),
                    ),
            ),
          ),
        );
      }

      if (_effectiveStyle == HabitListStyle.grid) {
        return SliverLayoutBuilder(
          builder: (context, constraints) {
            final crossAxisExtent = constraints.crossAxisExtent;
            const maxCrossAxisExtent = 300.0;
            final gridColumns = (crossAxisExtent / maxCrossAxisExtent).ceil();

            final visualItems = VisualItemUtils.getVisualItems<HabitListItem>(
              groupedItems: _cachedGroupedHabits!,
              gridColumns: gridColumns > 0 ? gridColumns : 1,
              groupTranslatable: _getGroupTranslatableMap(),
            );
            return _buildSliverList(precalculatedItems: visualItems, gridColumns: gridColumns > 0 ? gridColumns : 1);
          },
        );
      } else {
        return _buildSliverList();
      }
    }

    if (_habitList == null) {
      return const SizedBox.shrink();
    }

    if (_habitList!.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: SizedBox(
          width: double.infinity,
          child: widget.showDoneOverlayWhenEmpty
              ? IconOverlay(
                  icon: Icons.done_all_rounded,
                  iconSize: AppTheme.iconSize2XLarge,
                  message: _translationService.translate(HabitTranslationKeys.allHabitsDone),
                )
              : IconOverlay(
                  icon: Icons.check_circle_outline,
                  message: _translationService.translate(HabitTranslationKeys.noHabitsFound),
                ),
        ),
      );
    }

    final child = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: _effectiveStyle == HabitListStyle.grid ? _buildGridList() : _buildColumnList(),
    );

    if (widget.useParentScroll) {
      return child;
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: child,
    );
  }

  Widget _buildGridList() {
    final totalItemCount = _habitList!.items.length + (_habitList!.hasNext ? 1 : 0);

    return GridView.builder(
      key: ValueKey('grid_view_$_effectiveStyle'),
      controller: _scrollController,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300.0,
        crossAxisSpacing: AppTheme.sizeSmall,
        mainAxisSpacing: AppTheme.sizeSmall,
        mainAxisExtent: 42,
      ),
      itemCount: totalItemCount,
      itemBuilder: (context, index) {
        if (index == _habitList!.items.length && widget.paginationMode == PaginationMode.loadMore) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.sizeXSmall),
              child: LoadMoreButton(onPressed: onLoadMore),
            ),
          );
        } else if (index == _habitList!.items.length &&
            widget.paginationMode == PaginationMode.infinityScroll &&
            isLoadingMore) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.sizeXSmall),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (index >= _habitList!.items.length) {
          return const SizedBox.shrink();
        }

        final habit = _habitList!.items[index];
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.size4XSmall),
            child: HabitCard(
              key: ValueKey(
                  'habit_card_grid_${habit.id}_${_effectiveStyle}_${widget.enableReordering}_${widget.sortConfig?.useCustomOrder}'),
              habit: habit,
              style: _effectiveStyle,
              dateRange: widget.dateRange,
              onOpenDetails: () => widget.onClickHabit(habit),
              isDense: true,
              isThreeStateEnabled: widget.isThreeStateEnabled,
              isReverseDayOrder: widget.isReverseDayOrder,
            ),
          ),
        );
      },
    );
  }

  Map<String, List<HabitListItem>> _groupHabits() {
    if (_habitList == null) return {};

    final groupedHabits = <String, List<HabitListItem>>{};

    if (!_showGroupHeaders) {
      groupedHabits[''] = _habitList!.items;
      return groupedHabits;
    }

    for (var habit in _habitList!.items) {
      final groupName = habit.groupName ?? '';
      if (!groupedHabits.containsKey(groupName)) {
        groupedHabits[groupName] = [];
      }
      groupedHabits[groupName]!.add(habit);
    }

    final sortedGroups = groupedHabits.entries.toList()
      ..sort((a, b) {
        final aLabel = a.value.first.isGroupNameTranslatable ? _translationService.translate(a.key) : a.key;
        final bLabel = b.value.first.isGroupNameTranslatable ? _translationService.translate(b.key) : b.key;
        final labelComparison = aLabel.toLowerCase().compareTo(bLabel.toLowerCase());
        return labelComparison != 0 ? labelComparison : a.key.compareTo(b.key);
      });
    return Map.fromEntries(sortedGroups);
  }

  /// Returns a map of group name to whether it should be translated
  Map<String, bool> _getGroupTranslatableMap() {
    if (_cachedGroupedHabits == null) return {};
    return {
      for (final entry in _cachedGroupedHabits!.entries)
        if (entry.key.isNotEmpty) entry.key: entry.value.isNotEmpty ? entry.value.first.isGroupNameTranslatable : false,
    };
  }

  /// Optimistically moves [habit] to [clampedTargetIndex] within its group in
  /// the local list, so the drop looks instant before the command round-trips.
  /// [reducedGroup] is the group with the moved item already removed.
  /// Must be called inside `setState`.
  void _applyOptimisticReorder(HabitListItem habit, List<HabitListItem> reducedGroup, int clampedTargetIndex) {
    final reorderedAllItems = List<HabitListItem>.from(_habitList!.items);
    final globalIndex = reorderedAllItems.indexWhere((h) => h.id == habit.id);
    if (globalIndex == -1) return;

    reorderedAllItems.removeAt(globalIndex);

    int globalNewIndex;
    if (clampedTargetIndex < reducedGroup.length) {
      // Insert before the anchor item at the target slot.
      final anchorItem = reducedGroup[clampedTargetIndex];
      globalNewIndex = reorderedAllItems.indexWhere((h) => h.id == anchorItem.id);
    } else if (reducedGroup.isNotEmpty) {
      // Insert after the last item of the group.
      final lastItem = reducedGroup.last;
      globalNewIndex = reorderedAllItems.indexWhere((h) => h.id == lastItem.id) + 1;
    } else {
      // Sole member of its group: keep its current global position.
      globalNewIndex = globalIndex;
    }

    if (globalNewIndex != -1) {
      globalNewIndex = globalNewIndex.clamp(0, reorderedAllItems.length);
      reorderedAllItems.insert(globalNewIndex, habit);
    } else {
      reorderedAllItems.insert(globalIndex, habit);
    }

    _habitList = GetListHabitsQueryResponse(
      items: reorderedAllItems,
      totalItemCount: _habitList!.totalItemCount,
      pageIndex: _habitList!.pageIndex,
      pageSize: _habitList!.pageSize,
    );

    // The grouped/visual caches are derived from _habitList.items, and the
    // build path only rebuilds them when they are null. Without this
    // invalidation the optimistic reorder would be invisible: the list would
    // keep rendering the pre-drag order until the post-command refresh
    // landed, making the item appear to snap back and then jump into place.
    _cachedGroupedHabits = null;
    _cachedVisualItems = null;
  }

  Future<void> _onReorderInGroup(int oldIndex, int targetIndex, List<HabitListItem> groupHabits) async {
    if (!mounted) return;
    if (oldIndex < 0 || oldIndex >= groupHabits.length) return;

    _dragStateNotifier.startDragging();

    final habit = groupHabits[oldIndex];

    // The group with the moved item removed — computed once and reused for both
    // the optimistic UI reorder and the neighbor-id resolution, so the two can
    // never disagree.
    final reducedGroup = List<HabitListItem>.from(groupHabits)..removeAt(oldIndex);
    final clampedTargetIndex = targetIndex.clamp(0, reducedGroup.length);

    // Apply visual update immediately for a flicker-free drop.
    setState(() => _applyOptimisticReorder(habit, reducedGroup, clampedTargetIndex));

    // Resolve the neighbor ids at the drop position. The command handler is the
    // single source of truth for rank computation; the UI only reports where
    // the item was dropped.
    final beforeHabitId = clampedTargetIndex > 0 ? reducedGroup[clampedTargetIndex - 1].id : null;
    final afterHabitId = clampedTargetIndex < reducedGroup.length ? reducedGroup[clampedTargetIndex].id : null;

    // No-op if the item is already at the target slot within the group.
    if (oldIndex == clampedTargetIndex) {
      _dragStateNotifier.stopDragging();
      return;
    }

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
      operation: () async {
        await _mediator.send<UpdateHabitOrderCommand, UpdateHabitOrderResponse>(
          UpdateHabitOrderCommand(
            habitId: habit.id,
            targetIndex: clampedTargetIndex,
            beforeHabitId: beforeHabitId,
            afterHabitId: afterHabitId,
          ),
        );
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
              Logger.error('Failed to refresh habit list after reorder success', error: e, stackTrace: stackTrace);
            });
          }
        });
      },
      onError: (_) {
        _dragStateNotifier.stopDragging();
        if (mounted) {
          refresh().catchError((e, stackTrace) {
            Logger.error('Failed to refresh habit list after reorder error', error: e, stackTrace: stackTrace);
          });
        }
      },
    );
  }

  @override
  void onGroupCollapseChanged() {
    _cachedVisualItems = null;
  }

  Widget _buildColumnList() {
    final groupedHabits = _groupHabits();
    if (groupedHabits.isEmpty) return const SizedBox.shrink();

    final showLoadMore = _habitList!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _habitList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;

    final groupEntries = groupedHabits.entries.toList();

    return ListView.builder(
        key: ValueKey('habit_list_content_$_effectiveStyle'),
        controller: widget.useParentScroll ? null : _scrollController,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        itemCount: groupEntries.length + (showLoadMore || showInfinityLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < groupEntries.length) {
            final entry = groupEntries[index];
            final groupName = entry.key;
            final habits = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (groupName.isNotEmpty)
                  ListGroupHeader(
                    key: ValueKey('header_$groupName'),
                    title: habits.isNotEmpty && habits.first.isGroupNameTranslatable
                        ? _translationService.translate(groupName)
                        : groupName,
                    isExpanded: !collapsedGroups.contains(groupName),
                    onTap: () => toggleGroupCollapse(groupName),
                  ),
                if (!collapsedGroups.contains(groupName))
                  if (_isCustomOrderActive)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: habits.length,
                      proxyDecorator: (child, index, animation) => Material(
                        elevation: 2,
                        child: child,
                      ),
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        _onReorderInGroup(oldIndex, newIndex, habits);
                      },
                      itemBuilder: (context, i) {
                        final habit = habits[i];
                        final card = AnimatedSwitcher(
                          duration: const Duration(milliseconds: 100),
                          child: HabitCard(
                            key: ValueKey('habit_card_${habit.id}'),
                            habit: habit,
                            onOpenDetails: () => widget.onClickHabit(habit),
                            style: _effectiveStyle,
                            dateRange: widget.dateRange,
                            isDateLabelShowing: false,
                            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                            showDragHandle: _showCustomSortIndicator,
                            dragIndex: !habit.isArchived ? i : null,
                            isThreeStateEnabled: widget.isThreeStateEnabled,
                            isReverseDayOrder: widget.isReverseDayOrder,
                          ),
                        );

                        return Padding(
                          key: ValueKey('list_reorderable_${habit.id}_$_effectiveStyle'),
                          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                          // Without the handle the card itself is the only
                          // affordance left, so it must start the drag.
                          child: (_showCustomSortIndicator || habit.isArchived)
                              ? card
                              : ReorderableDelayedDragStartListener(index: i, child: card),
                        );
                      },
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: habits.length,
                      itemBuilder: (context, i) {
                        final habit = habits[i];
                        return Padding(
                          key: ValueKey('list_${habit.id}_$_effectiveStyle'),
                          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 100),
                            child: HabitCard(
                              key: ValueKey('habit_card_${habit.id}'),
                              habit: habit,
                              onOpenDetails: () => widget.onClickHabit(habit),
                              style: _effectiveStyle,
                              dateRange: widget.dateRange,
                              isDateLabelShowing: false,
                              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                              showDragHandle: false,
                              isThreeStateEnabled: widget.isThreeStateEnabled,
                              isReverseDayOrder: widget.isReverseDayOrder,
                            ),
                          ),
                        );
                      },
                    )
              ],
            );
          } else if (showLoadMore) {
            return Padding(
              key: ValueKey('load_more_button_list_$_effectiveStyle'),
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(
                  child: LoadMoreButton(
                onPressed: onLoadMore,
              )),
            );
          } else if (showInfinityLoading) {
            return Padding(
              key: ValueKey('loading_indicator_list_$_effectiveStyle'),
              padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox.shrink();
        });
  }

  /// The exact visual-item list most recently handed to the reorder callback.
  /// Recorded so tests replay against what the widget really built, including
  /// grid rows, rather than a separately reconstructed list.
  List<VisualItem<HabitListItem>>? _lastReorderableItems;

  /// Drives the sliver reorder path against the list's current visual items.
  /// Exposed so tests can exercise the real drop handling without simulating
  /// a full pointer drag, which cannot reliably express pre-removal indices.
  @visibleForTesting
  void onSliverReorderForTest(int oldIndex, int newIndex) {
    final items = _lastReorderableItems;
    if (items == null) return;
    _onSliverReorder(oldIndex, newIndex, items);
  }

  void _onSliverReorder(int oldIndex, int newIndex, List<VisualItem<HabitListItem>> visualItems) {
    if (oldIndex < 0 || oldIndex >= visualItems.length) return;
    if (newIndex < 0 || newIndex > visualItems.length) return;

    final oldItem = visualItems[oldIndex];
    if (oldItem is! VisualItemSingle<HabitListItem>) return;

    final habit = oldItem.data;
    final groupName = _groupKeyOf(habit);

    final groupedHabits = _groupHabits();
    final groupHabits = groupedHabits[groupName] ?? [];
    if (groupHabits.isEmpty) return;

    final habitGroupIndex = groupHabits.indexWhere((h) => h.id == habit.id);
    if (habitGroupIndex == -1) return;

    if (!_isWithinGroupSpan(newIndex, groupName, visualItems)) return;

    // SliverReorderableList reports newIndex in *pre-removal* coordinates, so
    // counting the moved item's own group-mates below must skip it exactly
    // once. Skipping it here AND separately decrementing newIndex for
    // downward moves would subtract twice, landing the item one slot short.
    int targetGroupIndex = 0;
    for (int i = 0; i < newIndex; i++) {
      if (i == oldIndex) continue;

      final item = visualItems[i];
      // Key the candidate the same way the moved item was keyed, so the two
      // always agree on which bucket they belong to.
      if (item is VisualItemSingle<HabitListItem> && _groupKeyOf(item.data) == groupName) {
        targetGroupIndex++;
      }
    }

    _onReorderInGroup(habitGroupIndex, targetGroupIndex, groupHabits);
  }

  /// Whether a pre-removal destination index still lands inside the group the
  /// moved item came from. A drop past the group's visible span is a
  /// cross-group move, which reorder must ignore rather than silently clamp to
  /// the boundary — clamping would reorder a group the user never dragged in.
  bool _isWithinGroupSpan(int newIndex, String groupName, List<VisualItem<HabitListItem>> visualItems) {
    int? firstInGroup;
    int? lastInGroup;
    for (int i = 0; i < visualItems.length; i++) {
      final item = visualItems[i];
      if (item is VisualItemSingle<HabitListItem> && _groupKeyOf(item.data) == groupName) {
        firstInGroup ??= i;
        lastInGroup = i;
      }
    }
    if (firstInGroup == null) return false;
    return newIndex >= firstInGroup && newIndex <= lastInGroup! + 1;
  }

  @override
  Future<void> onLoadMore() async {
    if (_habitList == null || !_habitList!.hasNext) return;

    _saveScrollPosition();
    await _getHabits(pageIndex: _habitList!.pageIndex + 1);
    _backLastScrollPosition();
  }

  Widget _buildListItem(
    BuildContext context,
    int index,
    List<VisualItem<HabitListItem>> visualItems,
    bool showLoadMore,
    bool showInfinityLoading,
    int gridColumns,
  ) {
    if (index >= visualItems.length) {
      if (showLoadMore) {
        return Padding(
          key: ValueKey('load_more_button_sliver_list_$_effectiveStyle'),
          padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
          child: Center(
            child: LoadMoreButton(onPressed: onLoadMore),
          ),
        );
      } else if (showInfinityLoading) {
        return Padding(
          key: ValueKey('loading_indicator_sliver_list_$_effectiveStyle'),
          padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return const SizedBox.shrink();
    }

    final item = visualItems[index];
    if (item is VisualItemHeader<HabitListItem>) {
      return ListGroupHeader(
        key: ValueKey('header_${item.title}'),
        title: item.isTranslatable ? _translationService.translate(item.title) : item.title,
        isExpanded: !collapsedGroups.contains(item.title),
        onTap: () => toggleGroupCollapse(item.title),
      );
    } else if (item is VisualItemSingle<HabitListItem>) {
      final habit = item.data;
      final isDraggable = _isCustomOrderActive && !habit.isArchived;
      final card = HabitCard(
        key: ValueKey('sliver_habit_card_${habit.id}'),
        habit: habit,
        onOpenDetails: () => widget.onClickHabit(habit),
        style: _effectiveStyle,
        dateRange: widget.dateRange,
        isDateLabelShowing: false,
        isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
        showDragHandle: _isCustomOrderActive && _showCustomSortIndicator,
        dragIndex: isDraggable ? index : null,
        isReverseDayOrder: widget.isReverseDayOrder,
      );

      return Padding(
        key: ValueKey('sliver_list_${habit.id}_$_effectiveStyle'),
        padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
        // Without the handle the card itself is the only affordance left, so
        // it must start the drag.
        child: (isDraggable && !_showCustomSortIndicator)
            ? ReorderableDelayedDragStartListener(index: index, child: card)
            : card,
      );
    } else if (item is VisualItemRow<HabitListItem>) {
      return Padding(
        key: ValueKey('grid_row_$index'),
        padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...item.items.map((habit) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall / 2),
                    child: HabitCard(
                      key: ValueKey('habit_card_sliver_grid_${habit.id}'),
                      habit: habit,
                      style: _effectiveStyle,
                      dateRange: widget.dateRange,
                      onOpenDetails: () => widget.onClickHabit(habit),
                      isDense: true,
                      isReverseDayOrder: widget.isReverseDayOrder,
                    ),
                  ),
                )),
            ...List.generate(
              gridColumns - item.items.length,
              (index) => const Spacer(),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink(key: ValueKey('habit_item_empty_$index'));
  }

  Widget _buildSliverList({List<VisualItem<HabitListItem>>? precalculatedItems, int gridColumns = 1}) {
    List<VisualItem<HabitListItem>> visualItems;

    if (precalculatedItems != null) {
      visualItems = precalculatedItems;
    } else {
      _cachedGroupedHabits ??= _groupHabits();
      _cachedVisualItems ??= VisualItemUtils.getVisualItems<HabitListItem>(
        groupedItems: _cachedGroupedHabits!,
        gridColumns: 1,
        groupTranslatable: _getGroupTranslatableMap(),
      );
      visualItems = _cachedVisualItems!.cast<VisualItem<HabitListItem>>();
    }

    // Filter items based on collapsed groups
    final filteredVisualItems = <VisualItem<HabitListItem>>[];
    bool isSkipping = false;

    for (var item in visualItems) {
      if (item is VisualItemHeader<HabitListItem>) {
        isSkipping = collapsedGroups.contains(item.title);
        filteredVisualItems.add(item);
      } else if (!isSkipping) {
        filteredVisualItems.add(item);
      }
    }

    final showLoadMore = _habitList!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _habitList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
    // Must be derived from the *filtered* list, since that is what both the
    // item builder and the reorder callback index into. Counting the
    // unfiltered list would over-report the item count whenever a group is
    // collapsed, misaligning every index passed to onReorder.
    final totalCount = filteredVisualItems.length + (showLoadMore || showInfinityLoading ? 1 : 0);

    if (_isCustomOrderActive) {
      _lastReorderableItems = filteredVisualItems;
      return SliverReorderableList(
        itemCount: totalCount,
        onReorder: (oldIndex, newIndex) => _onSliverReorder(oldIndex, newIndex, filteredVisualItems),
        proxyDecorator: (child, index, animation) => Material(
          elevation: 2,
          color: Colors.transparent, // Use transparent to match design
          child: child,
        ),
        itemBuilder: (context, index) => _buildListItem(
          context,
          index,
          filteredVisualItems,
          showLoadMore,
          showInfinityLoading,
          gridColumns,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildListItem(
          context,
          index,
          filteredVisualItems,
          showLoadMore,
          showInfinityLoading,
          gridColumns,
        ),
        childCount: totalCount,
      ),
    );
  }
}

class FilterContext {
  final HabitListStyle style;
  final int dateRange;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final bool filterByArchived;
  final String? search;
  final SortConfig<HabitSortFields>? sortConfig;
  final DateTime? excludeCompletedForDate;

  FilterContext({
    required this.style,
    required this.dateRange,
    required this.filterByTags,
    required this.filterNoTags,
    required this.filterByArchived,
    this.search,
    this.sortConfig,
    this.excludeCompletedForDate,
  });
}
