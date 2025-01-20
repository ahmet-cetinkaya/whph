import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/features/habits/components/habit_card.dart';
import 'package:whph/presentation/features/shared/components/load_more_button.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

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
  State<HabitsList> createState() => _HabitsListState();
}

class _HabitsListState extends State<HabitsList> {
  GetListHabitsQueryResponse? _habits;

  @override
  void initState() {
    super.initState();
    _getHabits();
  }

  Future<void> _getHabits({int pageIndex = 0}) async {
    try {
      var query = GetListHabitsQuery(
          pageIndex: pageIndex,
          pageSize: widget.size,
          excludeCompleted: widget.mini,
          filterByTags: widget.filterByTags);
      var result = await widget.mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);

      if (!mounted) return;

      setState(() {
        if (_habits == null) {
          _habits = result;
          return;
        }

        _habits!.items.addAll(result.items);
        _habits!.pageIndex = result.pageIndex;
      });

      if (widget.onList != null) {
        widget.onList!(_habits!.items.length);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to load habits.');
      }
    }
  }

  void _refreshHabits() {
    _habits = null;
    _getHabits();
  }

  @override
  Widget build(BuildContext context) {
    if (_habits == null) {
      return const SizedBox.shrink();
    }

    if (_habits!.items.isEmpty) {
      return const Center(child: Text('No habits found'));
    }

    return widget.mini ? _buildMiniCardList() : _buildColumnList();
  }

  Widget _buildMiniCardList() {
    return Wrap(
      children: [
        // List
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
                }),
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
