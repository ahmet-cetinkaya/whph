import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_card.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/filter_change_analyzer.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';

class HabitsList extends StatefulWidget {
  final int size;
  final bool mini;
  final int dateRange;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final bool showDoneOverlayWhenEmpty;
  final bool filterByArchived; // Changed to non-nullable

  final void Function(HabitListItem habit) onClickHabit;
  final void Function(int count)? onList;
  final void Function()? onHabitCompleted;
  final void Function(int count)? onListing;

  const HabitsList({
    super.key,
    this.size = 10,
    this.mini = false,
    this.dateRange = 7,
    this.filterByTags,
    this.filterNoTags = false,
    this.showDoneOverlayWhenEmpty = false,
    this.filterByArchived = false, // Default to showing unarchived
    required this.onClickHabit,
    this.onList,
    this.onHabitCompleted,
    this.onListing,
  });

  @override
  State<HabitsList> createState() => HabitsListState();
}

class HabitsListState extends State<HabitsList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();
  GetListHabitsQueryResponse? _habits;
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;
  late FilterContext _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = _captureCurrentFilters(); // Initialize first to avoid LateError
    _getHabits();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  void _setupEventListeners() {
    _habitsService.onHabitCreated.addListener(_handleHabitChange);
    _habitsService.onHabitUpdated.addListener(_handleHabitChange);
    _habitsService.onHabitDeleted.addListener(_handleHabitChange);
  }

  void _removeEventListeners() {
    _habitsService.onHabitCreated.removeListener(_handleHabitChange);
    _habitsService.onHabitUpdated.removeListener(_handleHabitChange);
    _habitsService.onHabitDeleted.removeListener(_handleHabitChange);
  }

  void _handleHabitChange() {
    if (!mounted) return;
    refresh();
  }

  @override
  void didUpdateWidget(HabitsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFilters = _captureCurrentFilters();
    if (_isFilterChanged(oldFilters: _currentFilters, newFilters: newFilters)) {
      _currentFilters = newFilters;
      refresh();
    }
  }

  FilterContext _captureCurrentFilters() => FilterContext(
        mini: widget.mini,
        dateRange: widget.dateRange,
        filterByTags: widget.filterByTags,
        filterNoTags: widget.filterNoTags,
        filterByArchived: widget.filterByArchived, // Changed from showArchived
      );

  bool _isFilterChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'mini': oldFilters.mini,
      'dateRange': oldFilters.dateRange,
      'filterNoTags': oldFilters.filterNoTags,
      'filterByTags': oldFilters.filterByTags,
      'filterByArchived': oldFilters.filterByArchived, // Changed from showArchived
    };

    final newMap = {
      'mini': newFilters.mini,
      'dateRange': newFilters.dateRange,
      'filterNoTags': newFilters.filterNoTags,
      'filterByTags': newFilters.filterByTags,
      'filterByArchived': newFilters.filterByArchived, // Changed from showArchived
    };

    return FilterChangeAnalyzer.hasAnyFilterChanged(oldMap, newMap);
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _refreshDebounce?.cancel();

    if (_pendingRefresh) {
      return;
    }

    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _getHabits(isRefresh: true);

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
    List<HabitListItem>? existingItems;
    if (isRefresh && _habits != null) {
      existingItems = List<HabitListItem>.from(_habits!.items);
    }

    final result = await AsyncErrorHandler.execute<GetListHabitsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingHabitsError),
      operation: () async {
        final query = GetListHabitsQuery(
          pageIndex: pageIndex,
          pageSize:
              isRefresh && _habits != null && _habits!.items.length > widget.size ? _habits!.items.length : widget.size,
          excludeCompleted: _currentFilters.mini,
          filterByTags: _currentFilters.filterNoTags ? [] : _currentFilters.filterByTags,
          filterNoTags: _currentFilters.filterNoTags,
          filterByArchived: _currentFilters.filterByArchived, // Changed from showArchived
        );

        return await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_habits == null || !isRefresh) {
            _habits = result;
          } else {
            _habits = GetListHabitsQueryResponse(
              items: [...result.items],
              totalItemCount: result.totalItemCount,
              totalPageCount: result.totalPageCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }

          // Notify about listing count
          widget.onListing?.call(_habits?.items.length ?? 0);
        });
      },
    );

    // If error occurred (result is null) and we have existing items, restore them
    if (result == null && existingItems != null && _habits != null) {
      setState(() {
        _habits = GetListHabitsQueryResponse(
          // Use non-nullable cast since we've already verified existingItems is not null
          items: existingItems!.toList(),
          totalItemCount: _habits!.totalItemCount,
          totalPageCount: _habits!.totalPageCount,
          pageIndex: _habits!.pageIndex,
          pageSize: _habits!.pageSize,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_habits == null) {
      return const SizedBox.shrink();
    }

    if (_habits!.items.isEmpty) {
      return SizedBox(
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
      );
    }

    return widget.mini ? _buildMiniCardList() : _buildColumnList();
  }

  Widget _buildMiniCardList() {
    return Wrap(
      children: [
        ..._habits!.items.map((habit) => SizedBox(
              key: ValueKey(habit.id), // Add this key
              width: 200,
              child: IgnorePointer(
                ignoring: false,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: HabitCard(
                    habit: habit,
                    isMiniLayout: true,
                    dateRange: widget.dateRange,
                    onOpenDetails: () => widget.onClickHabit(habit),
                    onRecordCreated: (_) => _onHabitRecordChanged(),
                    onRecordDeleted: (_) => _onHabitRecordChanged(),
                  ),
                ),
              ),
            )),
        if (_habits!.hasNext) LoadMoreButton(onPressed: () => _getHabits(pageIndex: _habits!.pageIndex + 1)),
      ],
    );
  }

  Widget _buildColumnList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._habits!.items.map((habit) => SizedBox(
                key: ValueKey(habit.id), // Add this key
                height: 64,
                child: HabitCard(
                  habit: habit,
                  onOpenDetails: () => widget.onClickHabit(habit),
                  isMiniLayout: false,
                  dateRange: widget.dateRange,
                  isDateLabelShowing: false,
                  onRecordCreated: (_) => widget.onHabitCompleted?.call(),
                  onRecordDeleted: (_) => widget.onHabitCompleted?.call(),
                ),
              )),
          if (_habits!.hasNext) LoadMoreButton(onPressed: () => _getHabits(pageIndex: _habits!.pageIndex + 1)),
        ],
      ),
    );
  }

  void _onHabitRecordChanged() {
    Future.delayed(const Duration(seconds: 3), () {
      refresh();
      widget.onHabitCompleted?.call();
    });
  }
}

class FilterContext {
  final bool mini;
  final int dateRange;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final bool filterByArchived; // Changed to non-nullable

  const FilterContext({
    required this.mini,
    required this.dateRange,
    this.filterByTags,
    this.filterNoTags = false,
    this.filterByArchived = false, // Default to showing unarchived
  });
}
