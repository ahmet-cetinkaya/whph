import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/features/habits/components/habit_card.dart';
import 'package:whph/presentation/features/shared/components/load_more_button.dart';

class HabitsList extends StatefulWidget {
  final Mediator mediator;

  final int size;
  final bool mini;
  final List<String>? filterByTags;

  final void Function(HabitListItem habit) onClickHabit;
  final void Function(int count)? onList;

  const HabitsList(
      {super.key,
      required this.mediator,
      this.size = 10,
      this.mini = false,
      this.filterByTags,
      required this.onClickHabit,
      this.onList});

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
    var query = GetListHabitsQuery(
        pageIndex: pageIndex, pageSize: widget.size, excludeCompleted: widget.mini, filterByTags: widget.filterByTags);
    var result = await widget.mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);
    setState(() {
      if (_habits == null) {
        _habits = result;
        return;
      }

      _habits!.items.addAll(result.items);
      _habits!.pageIndex = result.pageIndex;
    });
  }

  void _refreshHabits() {
    _habits = null;
    _getHabits();
  }

  @override
  Widget build(BuildContext context) {
    if (_habits == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (widget.onList != null) {
      widget.onList!(_habits!.items.length);
    }

    if (widget.mini) {
      return _buildMiniCardList();
    } else {
      return _buildListView();
    }
  }

  Widget _buildMiniCardList() {
    return Row(
      children: [
        // List
        ..._habits!.items.map((habit) {
          return HabitCard(
            habit: habit,
            onOpenDetails: () => widget.onClickHabit(habit),
            onRecordCreated: (_) async {
              await Future.delayed(Duration(seconds: 3));
              _refreshHabits();
            },
            onRecordDeleted: (_) async {
              await Future.delayed(Duration(seconds: 3));
              _refreshHabits();
            },
            mini: widget.mini,
          );
        }),
        if (_habits!.hasNext)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: LoadMoreButton(onPressed: () => _getHabits(pageIndex: _habits!.pageIndex + 1)),
          ),
      ],
    );
  }

  Widget _buildListView() {
    return Column(children: [
      ..._habits!.items.map((habit) {
        return Container(
          constraints: BoxConstraints(minHeight: 100),
          child: HabitCard(
            habit: habit,
            onOpenDetails: () => widget.onClickHabit(habit),
            mini: widget.mini,
          ),
        );
      }),
      if (_habits!.hasNext) LoadMoreButton(onPressed: () => _getHabits(pageIndex: _habits!.pageIndex + 1)),
    ]);
  }
}
