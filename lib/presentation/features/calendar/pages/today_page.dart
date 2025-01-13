import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/shared/components/done_overlay.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/utils/update_checker.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TodayPage extends StatefulWidget {
  static const String route = '/today';

  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final Mediator mediator = container.resolve<Mediator>();

  Key _habitKey = UniqueKey();
  bool _isHabitListEmpty = false;

  Key _taskKey = UniqueKey();
  bool _isTaskListEmpty = false;

  List<String>? _selectedTagFilter;

  @override
  void initState() {
    super.initState();
    UpdateChecker.checkForUpdates(context);
  }

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

  void _onHabitList(int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isHabitListEmpty = count == 0;
        });
      }
    });
  }

  void _onTaskList(int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isTaskListEmpty = count == 0;
        });
      }
    });
  }

  void _onTagFilterSelect(List<String> tags) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _habitKey = UniqueKey();
          _taskKey = UniqueKey();
          _selectedTagFilter = tags;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SecondaryAppBar(
          context: context,
          title: const Text('Today'),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TagSelectDropdown(
                  isMultiSelect: true, onTagsSelected: _onTagFilterSelect, buttonLabel: 'Filter by tags'),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _buildHabitSection(context),
              _buildTaskSection(context),
              _buildTimeSection(context),
            ],
          ),
        ));
  }

  Widget _buildHabitSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habits',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        _isHabitListEmpty
            ? DoneOverlay()
            : SizedBox(
                height: 80,
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: HabitsList(
                    key: _habitKey,
                    mediator: mediator,
                    size: 5,
                    mini: true,
                    filterByTags: _selectedTagFilter,
                    onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                    onList: _onHabitList,
                  ),
                )),
      ],
    );
  }

  Widget _buildTaskSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Tasks',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      _isTaskListEmpty
          ? DoneOverlay()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: TaskList(
                key: _taskKey,
                mediator: mediator,
                size: 5,
                filterByPlannedEndDate:
                    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999),
                filterByDueStartDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                filterDateOr: true,
                filterByTags: _selectedTagFilter,
                onClickTask: (task) => _openTaskDetails(context, task.id),
                onList: _onTaskList,
              ),
            ),
    ]);
  }

  Widget _buildTimeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: SizedBox(
              height: 300,
              width: 300,
              child: TagTimeChart(
                filterByTags: _selectedTagFilter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
