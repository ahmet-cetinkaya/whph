import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/shared/components/done_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  // Using GlobalKey to access TaskList state directly
  final GlobalKey<TaskListState> _tasksListKey = GlobalKey<TaskListState>();

  List<String>? _selectedTagIds;
  bool _isTasksListEmpty = false;
  bool _showCompletedTasks = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _searchQuery;

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _isTasksListEmpty = false;
      });

      // Access the TaskList state directly using the GlobalKey
      _tasksListKey.currentState?.refresh(showLoading: false);
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

  void _onFilterTags(List<DropdownOption<String>> tagOptions) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagOptions.map((option) => option.value).toList();
      });
      _refreshTasks();
    }
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (mounted) {
      setState(() {
        _filterStartDate = start;
        _filterEndDate = end;
      });
      _refreshTasks();
    }
  }

  void _onSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
      _refreshTasks();
    }
  }

  void _onCompletedTasksToggle(bool showCompleted) {
    if (mounted) {
      setState(() {
        _showCompletedTasks = showCompleted;
      });

      // Refresh the task list with the new filter
      _tasksListKey.currentState?.refresh(showLoading: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TaskTranslationKeys.tasksPageTitle),
      appBarActions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskAddButton(
              onTaskCreated: (taskId, taskData) {
                // Add the task directly to the list without full refresh
                final taskListState = _tasksListKey.currentState;
                if (taskListState != null) {
                  // Create a TaskListItem from the task data
                  final newTask = TaskListItem(
                    id: taskId,
                    title: taskData.title,
                    isCompleted: taskData.isCompleted,
                    priority: taskData.priority,
                    estimatedTime: taskData.estimatedTime,
                    plannedDate: taskData.plannedDate,
                    deadlineDate: taskData.deadlineDate,
                    order: taskData.order,
                    tags:
                        taskData.tags.map((tag) => TagListItem(id: tag.id, name: tag.name, color: tag.color)).toList(),
                  );

                  // Add the task to the list
                  taskListState.addTask(newTask);
                } else {
                  // Fallback to regular refresh if state is not available
                  _refreshTasks();
                }
              },
              buttonColor: AppTheme.primaryColor,
              initialTagIds: _selectedTagIds,
            ),
            HelpMenu(
              titleKey: TaskTranslationKeys.tasksHelpTitle,
              markdownContentKey: TaskTranslationKeys.tasksHelpContent,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
      builder: (context) => ListView(
        children: [
          // Filters with Completed Tasks Toggle
          TaskFilters(
            selectedTagIds: _selectedTagIds,
            selectedStartDate: _filterStartDate,
            selectedEndDate: _filterEndDate,
            onTagFilterChange: _onFilterTags,
            onDateFilterChange: _onDateFilterChange,
            onSearchChange: _onSearchChange,
            showCompletedTasks: _showCompletedTasks,
            onCompletedTasksToggle: _onCompletedTasksToggle,
            hasItems: !_isTasksListEmpty,
            showTagFilter: true,
            showDateFilter: true,
            showSearchFilter: true,
            showCompletedTasksToggle: !_isTasksListEmpty,
          ),

          // Empty List Overlay or TaskList with conditional properties
          _isTasksListEmpty
              ? const Center(child: DoneOverlay())
              : TaskList(
                  // Use ValueKey that changes when filter changes to force widget rebuild
                  key: _tasksListKey,
                  mediator: _mediator,
                  translationService: _translationService,
                  filterByCompleted: _showCompletedTasks,
                  filterByTags: _selectedTagIds,
                  // Only apply date filters for active tasks
                  filterByPlannedStartDate: _showCompletedTasks ? null : _filterStartDate,
                  filterByPlannedEndDate: _showCompletedTasks ? null : _filterEndDate,
                  search: _searchQuery,
                  onClickTask: (task) => _openTaskDetails(task.id),
                  onTaskCompleted: _refreshTasks,
                  // Only use onList callback for active tasks to check if empty
                  onList: _showCompletedTasks ? null : _onTasksList,
                  onScheduleTask: (_, __) => _refreshTasks(),
                  // Only enable reordering for active tasks
                  enableReordering: !_showCompletedTasks,
                ),
        ],
      ),
    );
  }
}
