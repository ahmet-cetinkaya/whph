import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_card.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:flutter/foundation.dart';

class HabitsList extends StatefulWidget {
  final Mediator mediator;

  final int size;
  final bool mini;
  final int dateRange;
  final List<String>? filterByTags;

  final void Function(HabitListItem habit) onClickHabit;
  final void Function(int count)? onList;
  final void Function()? onHabitCompleted;

  const HabitsList(
      {super.key,
      required this.mediator,
      this.size = 10,
      this.mini = false,
      this.dateRange = 7,
      this.filterByTags,
      required this.onClickHabit,
      this.onList,
      this.onHabitCompleted});

  @override
  State<HabitsList> createState() => HabitsListState();
}

class HabitsListState extends State<HabitsList> {
  GetListHabitsQueryResponse? _habits;
  final _translationService = container.resolve<ITranslationService>();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant HabitsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isFilterChanged(oldWidget)) {
      _getHabits(isRefresh: true, forceRefresh: true);
    }
  }

  bool _isFilterChanged(HabitsList oldWidget) {
    if (oldWidget.filterByTags == null && widget.filterByTags == null) return false;
    if (oldWidget.filterByTags == null || widget.filterByTags == null) return true;
    if (oldWidget.filterByTags!.length != widget.filterByTags!.length) return true;
    return !listEquals(oldWidget.filterByTags, widget.filterByTags);
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    await _getHabits(isRefresh: true);
  }

  Future<void> _getHabits({
    int pageIndex = 0,
    bool isRefresh = false,
    bool forceRefresh = false,
  }) async {
    if (_isRefreshing && !forceRefresh) return;
    _isRefreshing = true;

    if (isRefresh && mounted) {
      setState(() {
        _habits = null;
      });
    }

    try {
      final query = GetListHabitsQuery(
        pageIndex: pageIndex,
        pageSize:
            isRefresh && _habits != null && _habits!.items.length > widget.size ? _habits!.items.length : widget.size,
        excludeCompleted: widget.mini,
        filterByTags: widget.filterByTags,
      );

      final result = await widget.mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);

      if (!mounted) return;

      setState(() {
        if (_habits == null || isRefresh) {
          _habits = result;
        } else {
          _habits!.items.addAll(result.items);
          _habits!.pageIndex = result.pageIndex;
          _habits!.totalItemCount = result.totalItemCount;
          _habits!.totalPageCount = result.totalPageCount;
          _habits!.pageSize = result.pageSize;
        }
      });

      widget.onList?.call(_habits!.items.length);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(HabitTranslationKeys.loadingHabitsError),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    await _getHabits(isRefresh: true, forceRefresh: true);
  }

  /// Clear and fetch fresh habits list (used internally, e.g., after record operations).
  void _refreshHabits() {
    setState(() {
      _habits = null;
    });
    _getHabits(pageIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_habits == null) {
      return const SizedBox.shrink();
    }

    if (_habits!.items.isEmpty) {
      return Center(
        child: Text(_translationService.translate(HabitTranslationKeys.noHabitsFound)),
      );
    }

    return widget.mini ? _buildMiniCardList() : _buildColumnList();
  }

  Widget _buildMiniCardList() {
    return Wrap(
      children: [
        ..._habits!.items.map((habit) {
          return SizedBox(
            width: 200,
            child: HabitCard(
              habit: habit,
              isMiniLayout: widget.mini,
              dateRange: widget.dateRange,
              onOpenDetails: () => widget.onClickHabit(habit),
              onRecordCreated: (_) async {
                await Future.delayed(Duration(seconds: 3));
                _refreshHabits();
                widget.onHabitCompleted?.call();
              },
              onRecordDeleted: (_) async {
                await Future.delayed(Duration(seconds: 3));
                _refreshHabits();
                widget.onHabitCompleted?.call();
              },
            ),
          );
        }),
        if (_habits!.hasNext) LoadMoreButton(onPressed: () => _getHabits(pageIndex: _habits!.pageIndex + 1)),
      ],
    );
  }

  Widget _buildColumnList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._habits!.items.map((habit) {
            return SizedBox(
              height: 64,
              child: HabitCard(
                habit: habit,
                onOpenDetails: () => widget.onClickHabit(habit),
                isMiniLayout: widget.mini,
                dateRange: widget.dateRange,
                isDateLabelShowing: false,
                onRecordCreated: (_) {
                  widget.onHabitCompleted?.call();
                },
                onRecordDeleted: (_) {
                  widget.onHabitCompleted?.call();
                },
              ),
            );
          }),
          if (_habits!.hasNext) LoadMoreButton(onPressed: () => _getHabits(pageIndex: _habits!.pageIndex + 1)),
        ],
      ),
    );
  }
}
