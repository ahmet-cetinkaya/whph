import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/features/habits/components/habit_card.dart';

class HabitsList extends StatefulWidget {
  final Mediator mediator;
  final void Function(HabitListItem habit) onClickHabit;
  final bool mini;

  const HabitsList({
    super.key,
    required this.mediator,
    required this.onClickHabit,
    this.mini = false,
  });

  @override
  State<HabitsList> createState() => _HabitsListState();
}

class _HabitsListState extends State<HabitsList> {
  List<HabitListItem> _habits = [];
  int _pageIndex = 0;
  bool _hasNext = false;
  final ScrollController _scrollController = ScrollController();
  int _loadingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchHabits();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        if (_hasNext && _loadingCount == 0) {
          _fetchHabits(pageIndex: _pageIndex + 1);
        }
      }
    });
  }

  Future<void> _fetchHabits({int pageIndex = 0}) async {
    setState(() {
      _loadingCount++;
    });

    var query = GetListHabitsQuery(pageIndex: pageIndex, pageSize: 10, excludeCompleted: widget.mini);
    var queryResponse = await widget.mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);

    setState(() {
      _habits = [..._habits, ...queryResponse.items];
      _pageIndex = pageIndex;
      _hasNext = queryResponse.hasNext;
      _loadingCount--;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mini) {
      return _buildMiniCardList();
    } else {
      return _buildListView();
    }
  }

  Wrap _buildMiniCardList() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: _habits.map((habit) {
        return HabitCard(
          habit: habit,
          onOpenDetails: () => widget.onClickHabit(habit),
          mini: widget.mini,
        );
      }).toList(),
    );
  }

  ListView _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _habits.length,
      itemBuilder: (context, index) {
        return Container(
          constraints: BoxConstraints(minHeight: 100),
          child: HabitCard(
            habit: _habits[index],
            onOpenDetails: () => widget.onClickHabit(_habits[index]),
            mini: widget.mini,
          ),
        );
      },
    );
  }
}
