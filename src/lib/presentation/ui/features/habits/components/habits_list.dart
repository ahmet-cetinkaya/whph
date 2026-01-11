import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
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
  final bool forceOriginalLayout;
  final bool useParentScroll;
  final bool useSliver;
  final bool isThreeStateEnabled;

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
    this.forceOriginalLayout = false,
    this.useParentScroll = true,
    this.useSliver = false,
    this.isThreeStateEnabled = false,
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

class HabitsListState extends State<HabitsList> with PaginationMixin<HabitsList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();
  final ScrollController _scrollController = ScrollController();
  GetListHabitsQueryResponse? _habitList;
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;
  late FilterContext _currentFilters;
  double? _savedScrollPosition;

  // Cache for performance optimization
  Map<String, List<HabitListItem>>? _cachedGroupedHabits;
  List<VisualItem>? _cachedVisualItems;

  // Drag state notifier for reorderable list
  late final DragStateNotifier _dragStateNotifier;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _habitList?.hasNext ?? false;

  bool get _isCustomOrderActive =>
      widget.enableReordering && widget.sortConfig?.useCustomOrder == true && !widget.forceOriginalLayout;

  HabitListStyle get _effectiveStyle => _isCustomOrderActive ? HabitListStyle.list : widget.style;

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

    // When 3-state tracking is enabled, delay the refresh (which hides completed items)
    // by 1 minute to allow the user to toggle through states (Undo/Not Done) without the item vanishing.
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

      // For ALL filter changes including style, force immediate rebuild to prevent visual corruption
      if (mounted) {
        // Cancel any pending refresh operations
        _refreshDebounce?.cancel();
        _pendingRefresh = false;

        // Force immediate state update to prevent visual corruption during filter changes
        setState(() {
          // Recreate the habit list to force complete rebuild
          if (_habitList != null) {
            _habitList = GetListHabitsQueryResponse(
              items: _habitList!.items,
              totalItemCount: _habitList!.totalItemCount,
              pageIndex: _habitList!.pageIndex,
              pageSize: _habitList!.pageSize,
            );

            // Invalidate cache
            _cachedGroupedHabits = null;
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
  }

  FilterContext _captureCurrentFilters() => FilterContext(
        style: widget.style,
        dateRange: widget.dateRange,
        filterByTags: widget.filterByTags,
        filterNoTags: widget.filterNoTags,
        filterByArchived: widget.filterByArchived, // Changed from showArchived
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
        refresh();
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
          groupBy: _currentFilters.sortConfig?.groupOption,
          sortByCustomSort: _currentFilters.sortConfig?.useCustomOrder ?? false,
          excludeCompletedForDate: _currentFilters.excludeCompletedForDate,
        );

        return await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_habitList == null || isRefresh) {
            _habitList = result;
            _cachedGroupedHabits = null; // Invalidate cache
            _cachedVisualItems = null;
          } else {
            _habitList = GetListHabitsQueryResponse(
              items: [..._habitList!.items, ...result.items],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
            _cachedGroupedHabits = null; // Invalidate cache
            _cachedVisualItems = null;
          }

          // Notify about listing count
          widget.onListing?.call(_habitList?.items.length ?? 0);
        });

        // For infinity scroll: check if viewport needs more content
        if (widget.paginationMode == PaginationMode.infinityScroll && _habitList!.hasNext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndFillViewport();
          });
        }
      },
    );
  }

  void _updateCacheIfNeeded() {
    if (_habitList == null) {
      _cachedGroupedHabits = null;
      _cachedVisualItems = null;
      return;
    }

    if (_cachedGroupedHabits == null) {
      _cachedGroupedHabits = _groupHabits();

      // Also update visual items when grouping changes
      // only if we are in grid mode (which uses sliver layout builder)
      // or if we want to support sliver list mode later
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

            // Calculate visual items if needed (dependent on gridColumns)
            // Note: Visual items depend on gridColumns, so we can't fully cache outside LayoutBuilder
            // unless we cache map<columns, items>, but simple check is enough here
            // since grouping is the expensive part which is already cached.

            final visualItems = VisualItemUtils.getVisualItems<HabitListItem>(
              groupedItems: _cachedGroupedHabits!,
              gridColumns: gridColumns > 0 ? gridColumns : 1,
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
    // Note: When custom order is active, _effectiveStyle becomes list mode, so grid mode
    // never has reordering. The GridView below is the only path for grid layout.
    // Calculate the total item count including load more button
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
        // Load more button at the end
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
            ),
          ),
        );
      },
    );
  }

  Map<String, List<HabitListItem>> _groupHabits() {
    if (_habitList == null) return {};

    final groupedHabits = <String, List<HabitListItem>>{};

    // Check grouping settings
    final bool showHeaders =
        ((widget.sortConfig?.orderOptions.isNotEmpty ?? false) || (widget.sortConfig?.groupOption != null)) &&
            (widget.sortConfig?.enableGrouping ?? false);

    if (!showHeaders) {
      groupedHabits[''] = _habitList!.items;
      return groupedHabits;
    }

    // Preserve order from GetListHabitsQuery
    for (var habit in _habitList!.items) {
      final groupName = habit.groupName ?? '';
      if (!groupedHabits.containsKey(groupName)) {
        groupedHabits[groupName] = [];
      }
      groupedHabits[groupName]!.add(habit);
    }
    return groupedHabits;
  }

  Future<void> _onReorderInGroup(int oldIndex, int targetIndex, List<HabitListItem> groupHabits) async {
    if (!mounted) return;
    if (oldIndex < 0 || oldIndex >= groupHabits.length) return;

    _dragStateNotifier.startDragging();

    final habit = groupHabits[oldIndex];
    final originalOrder = habit.order ?? 0.0;

    // Update local state visually
    setState(() {
      final reorderedAllItems = List<HabitListItem>.from(_habitList!.items);
      final globalIndex = reorderedAllItems.indexWhere((h) => h.id == habit.id);

      if (globalIndex != -1) {
        reorderedAllItems.removeAt(globalIndex);

        // Find the correct global insertion index based on local group targetIndex
        int globalNewIndex;
        final reducedGroup = List<HabitListItem>.from(groupHabits)..removeAt(oldIndex);

        if (targetIndex < reducedGroup.length) {
          // Inserting before an item in the group
          final anchorItem = reducedGroup[targetIndex];
          globalNewIndex = reorderedAllItems.indexWhere((h) => h.id == anchorItem.id);
        } else {
          // Inserting at the end of the group
          if (reducedGroup.isNotEmpty) {
            final lastItem = reducedGroup.last;
            globalNewIndex = reorderedAllItems.indexWhere((h) => h.id == lastItem.id) + 1;
          } else {
            // Group became empty (except this item), put it back at original relative position locally?
            // Actually if group is empty, logic implies globalNewIndex is tricky without group context.
            // But reducedGroup empty means groupHabits had 1 item.
            // So we just want to put it back where it was (globalIndex).
            globalNewIndex = globalIndex;
          }
        }

        if (globalNewIndex != -1) {
          // Clamp checks just in case
          if (globalNewIndex < 0) globalNewIndex = 0;
          if (globalNewIndex > reorderedAllItems.length) globalNewIndex = reorderedAllItems.length;

          reorderedAllItems.insert(globalNewIndex, habit);
        } else {
          // Fallback if anchor not found (should not happen in consistent state)
          reorderedAllItems.insert(globalIndex, habit);
        }

        _habitList = GetListHabitsQueryResponse(
          items: reorderedAllItems,
          totalItemCount: _habitList!.totalItemCount,
          pageIndex: _habitList!.pageIndex,
          pageSize: _habitList!.pageSize,
        );
      }
    });

    try {
      final existingOrders = groupHabits.map((item) => item.order ?? 0.0).toList()..removeAt(oldIndex);
      double targetOrder;

      // Calculate target order based on targetIndex
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

      await AsyncErrorHandler.execute<UpdateHabitOrderResponse>(
        context: context,
        errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
        operation: () async {
          return await _mediator.send<UpdateHabitOrderCommand, UpdateHabitOrderResponse>(
            UpdateHabitOrderCommand(
              habitId: habit.id,
              newOrder: targetOrder,
            ),
          );
        },
        onSuccess: (result) {
          _dragStateNotifier.stopDragging();
          if ((result.order - targetOrder).abs() > 1e-10) {
            refresh();
          }
        },
        onError: (error) {
          _dragStateNotifier.stopDragging();
          refresh();
        },
      );
    } catch (e) {
      if (e is RankGapTooSmallException && mounted) {
        // Normalize all habit orders to resolve ranking conflicts
        await AsyncErrorHandler.executeVoid(
          context: context,
          errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
          operation: () async {
            await _mediator.send<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse>(
              const NormalizeHabitOrdersCommand(),
            );
          },
          onSuccess: () {
            _dragStateNotifier.stopDragging();
            widget.onReorderComplete?.call(); // Refresh to show normalized order
          },
          onError: (_) {
            _dragStateNotifier.stopDragging();
            refresh();
          },
        );
      } else {
        _dragStateNotifier.stopDragging();
        refresh();
      }
    }
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
                    title: groupName,
                    shouldTranslate: groupName.length > 1,
                  ),
                if (widget.enableReordering && widget.sortConfig?.useCustomOrder == true && !widget.forceOriginalLayout)
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
                            showDragHandle: true,
                            dragIndex: !habit.isArchived ? i : null,
                            isThreeStateEnabled: widget.isThreeStateEnabled,
                          ),
                        ),
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

  void _onSliverReorder(int oldIndex, int newIndex, List<VisualItem<HabitListItem>> visualItems) {
    // Validate bounds before index manipulation
    if (oldIndex < 0 || oldIndex >= visualItems.length) return;
    if (newIndex < 0 || newIndex >= visualItems.length) return;

    // Adjust newIndex when moving item downward (as per SliverReorderableList behavior)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final oldItem = visualItems[oldIndex];
    if (oldItem is! VisualItemSingle<HabitListItem>) return;

    final habit = oldItem.data;
    final groupName = habit.groupName ?? '';

    final groupedHabits = _groupHabits();
    final groupHabits = groupedHabits[groupName] ?? [];
    if (groupHabits.isEmpty) return;

    final habitGroupIndex = groupHabits.indexWhere((h) => h.id == habit.id);
    if (habitGroupIndex == -1) return;

    // Calculate target index within the group by counting preceding items of the same group
    int targetGroupIndex = 0;
    for (int i = 0; i < newIndex; i++) {
      if (i == oldIndex) continue;

      final item = visualItems[i];
      if (item is VisualItemSingle<HabitListItem> && item.data.groupName == groupName) {
        targetGroupIndex++;
      }
    }

    _onReorderInGroup(habitGroupIndex, targetGroupIndex, groupHabits);
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
        title: item.title,
        shouldTranslate: item.title.length > 1,
      );
    } else if (item is VisualItemSingle<HabitListItem>) {
      final habit = item.data;
      return Padding(
        key: ValueKey('list_${habit.id}_$_effectiveStyle'),
        padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
        child: HabitCard(
          key: ValueKey('habit_card_${habit.id}'),
          habit: habit,
          onOpenDetails: () => widget.onClickHabit(habit),
          style: _effectiveStyle,
          dateRange: widget.dateRange,
          isDateLabelShowing: false,
          isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
          showDragHandle: _isCustomOrderActive,
          dragIndex: _isCustomOrderActive && !habit.isArchived ? index : null,
        ),
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
    return const SizedBox.shrink();
  }

  Widget _buildSliverList({List<VisualItem<HabitListItem>>? precalculatedItems, int gridColumns = 1}) {
    List<VisualItem<HabitListItem>> visualItems;

    if (precalculatedItems != null) {
      visualItems = precalculatedItems;
    } else {
      // Ensure grouping is cached
      _cachedGroupedHabits ??= _groupHabits();

      // Ensure visual items are cached
      _cachedVisualItems ??= VisualItemUtils.getVisualItems<HabitListItem>(
        groupedItems: _cachedGroupedHabits!,
        gridColumns: 1, // List mode is always 1 column
      );
      visualItems = _cachedVisualItems!.cast<VisualItem<HabitListItem>>();
    }

    final showLoadMore = _habitList!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _habitList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
    final totalCount = visualItems.length + (showLoadMore || showInfinityLoading ? 1 : 0);

    if (widget.enableReordering && widget.sortConfig?.useCustomOrder == true && !widget.forceOriginalLayout) {
      return SliverReorderableList(
        itemCount: totalCount,
        onReorder: (oldIndex, newIndex) => _onSliverReorder(oldIndex, newIndex, visualItems),
        proxyDecorator: (child, index, animation) => Material(
          elevation: 2,
          color: Colors.transparent, // Use transparent to match design
          child: child,
        ),
        itemBuilder: (context, index) => _buildListItem(
          context,
          index,
          visualItems,
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
          visualItems,
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
