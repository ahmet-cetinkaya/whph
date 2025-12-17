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
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';

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

  // Drag state notifier for reorderable list
  late final DragStateNotifier _dragStateNotifier;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _habitList?.hasNext ?? false;

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
    refresh();
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
    _refreshDebounce?.cancel();

    if (_pendingRefresh) {
      return;
    }

    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
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
          sortByCustomSort: _currentFilters.sortConfig?.useCustomOrder ?? false,
          excludeCompletedForDate: _currentFilters.excludeCompletedForDate,
        );

        return await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_habitList == null || isRefresh) {
            _habitList = result;
          } else {
            _habitList = GetListHabitsQueryResponse(
              items: [..._habitList!.items, ...result.items],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
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

  @override
  Widget build(BuildContext context) {
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
      child: widget.style == HabitListStyle.grid ? _buildGridList() : _buildColumnList(),
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
    if (widget.enableReordering && widget.sortConfig?.useCustomOrder == true && !widget.forceOriginalLayout) {
      // Use ReorderableListView for drag-and-drop in mini layout
      return ReorderableListView(
        key: ValueKey('reorderable_grid_${widget.style}_${_habitList?.items.length ?? 0}'),
        buildDefaultDragHandles: false,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        proxyDecorator: (child, index, animation) => Material(
          elevation: 2,
          child: child,
        ),
        scrollController: widget.useParentScroll ? null : _scrollController,
        onReorder: _onReorder,
        children: [
          ..._habitList!.items.asMap().entries.map((entry) {
            final index = entry.key;
            final habit = entry.value;
            return Padding(
              key: ValueKey('reorderable_grid_${habit.id}_${widget.style}'),
              padding: const EdgeInsets.all(AppTheme.size4XSmall),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: HabitCard(
                  key: ValueKey('habit_card_reorderable_${habit.id}_${widget.style}'),
                  habit: habit,
                  style: widget.style,
                  dateRange: widget.dateRange,
                  onOpenDetails: () => widget.onClickHabit(habit),
                  isDense: true,
                  showDragHandle: widget.enableReordering &&
                      widget.sortConfig?.useCustomOrder == true &&
                      !widget.forceOriginalLayout,
                  dragIndex: !habit.isArchived() ? index : null, // Only draggable if not archived
                ),
              ),
            );
          }),
          if (_habitList!.hasNext && widget.paginationMode == PaginationMode.loadMore)
            Padding(
              key: ValueKey('load_more_button_grid_${widget.style}'),
              padding: const EdgeInsets.all(AppTheme.sizeXSmall),
              child: Center(
                child: LoadMoreButton(onPressed: onLoadMore),
              ),
            ),
          if (_habitList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore)
            Padding(
              key: ValueKey('loading_indicator_grid_${widget.style}'),
              padding: const EdgeInsets.all(AppTheme.sizeXSmall),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    } else {
      // Calculate the total item count including load more button
      final totalItemCount = _habitList!.items.length + (_habitList!.hasNext ? 1 : 0);

      return GridView.builder(
        key: ValueKey('grid_view_${widget.style}_${_habitList?.items.length ?? 0}'),
        controller: _scrollController,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300.0,
          crossAxisSpacing: AppTheme.size3XSmall,
          mainAxisSpacing: AppTheme.size3XSmall,
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
                    'habit_card_grid_${habit.id}_${widget.style}_${widget.enableReordering}_${widget.sortConfig?.useCustomOrder}'),
                habit: habit,
                style: widget.style,
                dateRange: widget.dateRange,
                onOpenDetails: () => widget.onClickHabit(habit),
                isDense: true,
              ),
            ),
          );
        },
      );
    }
  }

  List<Widget> _buildHabitCards() {
    return _habitList!.items.asMap().entries.map((entry) {
      final index = entry.key;
      final habit = entry.value;
      return Padding(
        key: ValueKey('list_${habit.id}_${widget.style}'),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.size3XSmall),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          child: HabitCard(
            key: ValueKey(
                'habit_card_${habit.id}_${widget.style}_${widget.enableReordering}_${widget.sortConfig?.useCustomOrder}'),
            habit: habit,
            onOpenDetails: () => widget.onClickHabit(habit),
            style: widget.style,
            dateRange: widget.dateRange,
            isDateLabelShowing: false,
            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            showDragHandle:
                widget.enableReordering && widget.sortConfig?.useCustomOrder == true && !widget.forceOriginalLayout,
            dragIndex: !habit.isArchived() ? index : null, // Only draggable if not archived
          ),
        ),
      );
    }).toList();
  }

  Widget _buildColumnList() {
    if (widget.enableReordering && widget.sortConfig?.useCustomOrder == true && !widget.forceOriginalLayout) {
      return ReorderableListView(
        key: ValueKey('reorderable_list_${widget.style}_${_habitList?.items.length ?? 0}'),
        buildDefaultDragHandles: false,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        proxyDecorator: (child, index, animation) => Material(
          elevation: 2,
          child: child,
        ),
        scrollController: widget.useParentScroll ? null : _scrollController,
        onReorder: _onReorder,
        children: [
          ..._buildHabitCards(),
          if (_habitList!.hasNext && widget.paginationMode == PaginationMode.loadMore)
            Padding(
              key: ValueKey('load_more_button_list_${widget.style}'),
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(
                  child: LoadMoreButton(
                onPressed: onLoadMore,
              )),
            ),
          if (_habitList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore)
            Padding(
              key: ValueKey('loading_indicator_list_${widget.style}'),
              padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    } else {
      final habitCards = _buildHabitCards();
      final showLoadMore = _habitList!.hasNext && widget.paginationMode == PaginationMode.loadMore;
      final showInfinityLoading =
          _habitList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
      final extraItemCount = (showLoadMore || showInfinityLoading) ? 1 : 0;

      return ListView.builder(
        key: ValueKey('list_view_${widget.style}_${_habitList?.items.length ?? 0}'),
        controller: widget.useParentScroll ? null : _scrollController,
        shrinkWrap: widget.useParentScroll,
        physics: widget.useParentScroll ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        itemCount: habitCards.length + extraItemCount,
        itemBuilder: (context, index) {
          if (index < habitCards.length) {
            return habitCards[index];
          } else if (showLoadMore) {
            return Padding(
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(
                  child: LoadMoreButton(
                onPressed: onLoadMore,
              )),
            );
          } else if (showInfinityLoading) {
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!mounted) return;

    // Start dragging state
    _dragStateNotifier.startDragging();

    final items = _habitList!.items;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final habit = items[oldIndex];
    final originalOrder = habit.order ?? 0.0;

    try {
      // Prepare data for server update
      final existingOrders = items.map((item) => item.order ?? 0.0).toList()..removeAt(oldIndex);

      // Calculate target order - use manual calculation for position 0 until core package changes take effect
      double targetOrder;
      if (newIndex == 0 && existingOrders.isNotEmpty) {
        // Manual fix for position 0: subtract initialStep from first order
        final firstOrder = existingOrders.first;
        targetOrder = firstOrder - OrderRank.initialStep;
      } else {
        // Use OrderRank utility for other positions
        targetOrder = OrderRank.getTargetOrder(existingOrders, newIndex);
      }

      if ((targetOrder - originalOrder).abs() < 1e-10) {
        _dragStateNotifier.stopDragging();
        return; // No real change in order
      }

      // Apply visual reordering with correct target order
      setState(() {
        final reorderedItems = List<HabitListItem>.from(_habitList!.items);
        final habitToMove = reorderedItems.removeAt(oldIndex);

        // Update the moved habit's order to the target order for correct visual display
        final updatedHabit = HabitListItem(
          id: habitToMove.id,
          name: habitToMove.name,
          tags: habitToMove.tags,
          estimatedTime: habitToMove.estimatedTime,
          hasReminder: habitToMove.hasReminder,
          reminderTime: habitToMove.reminderTime,
          reminderDays: habitToMove.reminderDays,
          archivedDate: habitToMove.archivedDate,
          order: targetOrder, // Use the calculated target order
        );

        reorderedItems.insert(newIndex, updatedHabit);

        // Sort the items by order to ensure correct visual display
        reorderedItems.sort((a, b) => (a.order ?? 0.0).compareTo(b.order ?? 0.0));

        _habitList = GetListHabitsQueryResponse(
          items: reorderedItems,
          totalItemCount: _habitList!.totalItemCount,
          pageIndex: _habitList!.pageIndex,
          pageSize: _habitList!.pageSize,
        );
      });

      // Update backend
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
          // Check if the backend returned a different order (due to re-normalization)
          if ((result.order - targetOrder).abs() > 1e-10) {
            // Backend order is different, update local state to match
            setState(() {
              final updatedItems = List<HabitListItem>.from(_habitList!.items);
              final habitIndex = updatedItems.indexWhere((item) => item.id == habit.id);
              if (habitIndex != -1) {
                updatedItems[habitIndex] = HabitListItem(
                  id: habit.id,
                  name: habit.name,
                  tags: habit.tags,
                  estimatedTime: habit.estimatedTime,
                  hasReminder: habit.hasReminder,
                  reminderTime: habit.reminderTime,
                  reminderDays: habit.reminderDays,
                  archivedDate: habit.archivedDate,
                  order: result.order, // Use the final order from backend
                );

                // Re-sort with the updated order
                updatedItems.sort((a, b) => (a.order ?? 0.0).compareTo(b.order ?? 0.0));

                _habitList = GetListHabitsQueryResponse(
                  items: updatedItems,
                  totalItemCount: _habitList!.totalItemCount,
                  pageIndex: _habitList!.pageIndex,
                  pageSize: _habitList!.pageSize,
                );
              }
            });
          }
          _dragStateNotifier.stopDragging();
        },
        onError: (error) {
          _dragStateNotifier.stopDragging();
          refresh(); // Refresh to restore correct order on error
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

  @override
  Future<void> onLoadMore() async {
    if (_habitList == null || !_habitList!.hasNext) return;

    _saveScrollPosition();
    await _getHabits(pageIndex: _habitList!.pageIndex + 1);
    _backLastScrollPosition();
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
