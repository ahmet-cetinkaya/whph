import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TodayPage extends StatelessWidget {
  static const String route = '/today';

  final Mediator mediator = container.resolve<Mediator>();

  TodayPage({super.key});

  Future<void> _openTaskDetails(BuildContext context, String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(taskId: taskId),
      ),
    );
  }

  Future<void> _openHabitDetails(BuildContext context, String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailsPage(habitId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SecondaryAppBar(
          context: context,
          title: const Text('Today'),
        ),
        body: ListView(
          children: [
            _buildHabitSection(context),
            _buildTaskSection(context),
            _buildTimeSection(context),
          ],
        ));
  }

  Widget _buildHabitSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habits',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(
            width: double.infinity,
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                HabitsList(
                  mediator: mediator,
                  size: 5,
                  onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                  mini: true,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTaskSection(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(left: 16, top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Tasks',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          TasksList(
            mediator: mediator,
            size: 5,
            onClickTask: (task) => _openTaskDetails(context, task.id),
            filterByPlannedDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            filterByDueDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
          ),
        ]));
  }

  Widget _buildTimeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Center(
            child: SizedBox(
              height: 300,
              width: 300,
              child: TagTimeChart(),
            ),
          ),
        ],
      ),
    );
  }
}
