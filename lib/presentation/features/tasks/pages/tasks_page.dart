import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/app_logo.dart';
import 'package:whph/presentation/features/shared/components/done_overlay.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final Mediator _mediator = container.resolve<Mediator>();

  List<String>? _selectedTagIds;

  Key _tasksListKey = UniqueKey();
  bool _isTasksListEmpty = false;

  bool _isCompletedTasksExpanded = false;
  Key _completedTasksListKey = UniqueKey();

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  String? _searchQuery;

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _tasksListKey = UniqueKey();
        _completedTasksListKey = UniqueKey();
      });
    }
  }

  Future<void> _openTaskDetails(String taskId) async {
    await Navigator.of(context).pushNamed(
      TaskDetailsPage.route,
      arguments: {'id': taskId},
    );
    _refreshTasks();
  }

  void _onTasksList(count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isTasksListEmpty = count == 0;
        });
      }
    });
  }

  void _onFilterTags(List<String> tagIds) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagIds;
        _refreshTasks();
      });
    }
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (mounted) {
      setState(() {
        _filterStartDate = start;
        _filterEndDate = end;
        _refreshTasks();
      });
    }
  }

  void _onSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _refreshTasks();
      });
    }
  }

  Future<void> _handleScheduleTask(TaskListItem task, DateTime date) async {
    var command = SaveTaskCommand(
      id: task.id,
      title: task.title,
      priority: task.priority,
      plannedDate: date,
      deadlineDate: task.deadlineDate,
      estimatedTime: task.estimatedTime,
      isCompleted: task.isCompleted,
    );

    await _mediator.send(command);
    _refreshTasks();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: Row(
        children: [
          const AppLogo(width: 32, height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: const Text('Tasks'),
          )
        ],
      ),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TaskAddButton(
            onTaskCreated: (_) => _refreshTasks(),
            buttonColor: AppTheme.primaryColor,
            initialTagIds: _selectedTagIds,
          ),
        ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            // Filters
            TaskFilters(
              selectedTagIds: _selectedTagIds,
              selectedStartDate: _filterStartDate,
              selectedEndDate: _filterEndDate,
              onTagFilterChange: _onFilterTags,
              onDateFilterChange: _onDateFilterChange,
              onSearchChange: _onSearchChange,
            ),

            // Tasks list
            if (_isTasksListEmpty) DoneOverlay(),

            TaskList(
              key: _tasksListKey,
              mediator: _mediator,
              filterByCompleted: false,
              filterByTags: _selectedTagIds,
              filterByPlannedStartDate: _filterStartDate,
              filterByPlannedEndDate: _filterEndDate,
              search: _searchQuery,
              onClickTask: (task) => _openTaskDetails(task.id),
              onTaskCompleted: _refreshTasks,
              onList: _onTasksList,
              trailingButtons: (task) => [
                PopupMenuButton<DateTime>(
                  icon: Icon(Icons.schedule, color: Colors.grey),
                  tooltip: 'Schedule task',
                  itemBuilder: (context) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final tomorrow = today.add(const Duration(days: 1));

                    return [
                      PopupMenuItem(
                        value: today,
                        child: Text('Schedule for today'),
                      ),
                      PopupMenuItem(
                        value: tomorrow,
                        child: Text('Schedule for tomorrow'),
                      ),
                    ];
                  },
                  onSelected: (date) => _handleScheduleTask(task, date),
                ),
              ],
            ),

            // Expansion panel for completed tasks
            ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                if (!mounted) return;
                setState(() {
                  _isCompletedTasksExpanded = !_isCompletedTasksExpanded;
                });
              },
              children: [
                ExpansionPanel(
                    isExpanded: _isCompletedTasksExpanded,
                    headerBuilder: (context, isExpanded) {
                      return ListTile(
                        contentPadding: EdgeInsets.only(left: 8),
                        leading: const Icon(Icons.done_all),
                        title: const Text('Completed tasks'),
                      );
                    },
                    body: TaskList(
                      key: _completedTasksListKey,
                      mediator: _mediator,
                      filterByCompleted: true,
                      filterByTags: _selectedTagIds,
                      search: _searchQuery,
                      onClickTask: (task) => _openTaskDetails(task.id),
                      onTaskCompleted: _refreshTasks,
                    ),
                    backgroundColor: Colors.transparent,
                    canTapOnHeader: true),
              ],
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
            )
          ],
        ),
      ),
    );
  }
}
