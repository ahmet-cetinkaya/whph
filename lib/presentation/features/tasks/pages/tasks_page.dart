import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/done_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';

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

  void _refreshAllTasks() {
    if (mounted) {
      setState(() {
        _isTasksListEmpty = false;
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
    _refreshAllTasks();
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

  void _onFilterTags(List<DropdownOption<String>> tagOptions) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagOptions.map((option) => option.value).toList();
        _refreshAllTasks();
      });
    }
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (mounted) {
      setState(() {
        _filterStartDate = start;
        _filterEndDate = end;
        _refreshAllTasks();
      });
    }
  }

  void _onSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _refreshAllTasks();
      });
    }
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tasks Overview Help',
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '📋 Tasks help you track and organize your work items and record time spent.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Features',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Task Organization:',
                  '  - Organize with tags',
                  '  - Set planned dates',
                  '  - Track deadlines',
                  '• Time Tracking:',
                  '  - Record time spent on tasks',
                  '  - Automatically updates tag times',
                  '  - Marathon mode for focused work',
                  '• Task Management:',
                  '  - Active and completed task views',
                  '  - Quick task creation',
                  '  - Flexible task filtering',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '🔍 Filters',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Filter by tags to focus on specific areas',
                  '• Use date filters for time-based views',
                  '• Search tasks by name or description',
                  '• View completed tasks separately',
                  '• Combine filters for precise results',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '💡 Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Use tags to group related tasks',
                  '• Set realistic planned dates',
                  '• Break down large tasks into smaller ones',
                  '• Review completed tasks regularly',
                  '• Use Marathon mode for focused work sessions',
                  '• Track time to understand work patterns',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: 'Tasks',
      appBarActions: [
        TaskAddButton(
          onTaskCreated: (_) => _refreshAllTasks(),
          buttonColor: AppTheme.primaryColor,
          initialTagIds: _selectedTagIds,
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpModal,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            TaskFilters(
              selectedTagIds: _selectedTagIds,
              selectedStartDate: _filterStartDate,
              selectedEndDate: _filterEndDate,
              onTagFilterChange: _onFilterTags,
              onDateFilterChange: _onDateFilterChange,
              onSearchChange: _onSearchChange,
            ),
            const SizedBox(height: 8),
            if (_isTasksListEmpty)
              const Center(child: DoneOverlay())
            else
              TaskList(
                key: _tasksListKey,
                mediator: _mediator,
                filterByCompleted: false,
                filterByTags: _selectedTagIds,
                filterByPlannedStartDate: _filterStartDate,
                filterByPlannedEndDate: _filterEndDate,
                search: _searchQuery,
                onClickTask: (task) => _openTaskDetails(task.id),
                onTaskCompleted: _refreshAllTasks,
                onList: _onTasksList,
                onScheduleTask: (_, __) => _refreshAllTasks(),
              ),
            const SizedBox(height: 8),
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
                      onTaskCompleted: _refreshAllTasks,
                      onScheduleTask: (_, __) => _refreshAllTasks(),
                    ),
                    backgroundColor: Colors.transparent,
                    canTapOnHeader: true),
              ],
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
