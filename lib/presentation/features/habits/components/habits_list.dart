import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/features/habits/components/habit_card.dart';

class HabitsList extends StatefulWidget {
  final Mediator mediator;
  final void Function(HabitListItem habit) onClickHabit;

  const HabitsList({
    super.key,
    required this.mediator,
    required this.onClickHabit,
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

  Future<void> _fetchHabits({int pageIndex = 0}) async {
    setState(() {
      _loadingCount++;
    });

    var query = GetListHabitsQuery(pageIndex: pageIndex, pageSize: 100); //TODO: Add lazy loading
    var queryResponse = await widget.mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(query);

    setState(() {
      _habits = [..._habits, ...queryResponse.items];
      _pageIndex = pageIndex;
      _hasNext = queryResponse.hasNext;
      _loadingCount--;
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasNext) {
        await _fetchHabits(pageIndex: _pageIndex + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _habits.clear();
          _pageIndex = 0;
        });
        await _fetchHabits();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _habits.length + (_loadingCount > 0 ? 1 : 0),
        itemBuilder: (context, index) {
          if (_loadingCount > 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final habit = _habits[index];
          return HabitCard(
            habit: habit,
            onOpenDetails: () {
              widget.onClickHabit(habit); // Use the passed callback here
            },
          );
        },
      ),
    );
  }
}
