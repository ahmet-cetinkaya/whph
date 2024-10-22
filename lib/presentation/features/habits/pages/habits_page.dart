import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_add_button.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';

class HabitsPage extends StatefulWidget {
  static const String route = '/habits';

  final Mediator mediator = container.resolve<Mediator>();

  HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  Key _habitsListKey = UniqueKey();

  _openDetails(String habitId, BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailsPage(habitId: habitId),
      ),
    );
    setState(() {
      _habitsListKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SecondaryAppBar(
          context: context,
          title: const Text('Habits'),
          actions: [
            HabitAddButton(
              onHabitCreated: (String habitId) {
                setState(() {
                  _openDetails(habitId, context);
                });
              },
            )
          ],
        ),
        body: Column(children: [
          Expanded(
              key: _habitsListKey,
              child: HabitsList(
                  mediator: widget.mediator,
                  onClickHabit: (item) {
                    _openDetails(item.id, context);
                  }))
        ]));
  }
}
