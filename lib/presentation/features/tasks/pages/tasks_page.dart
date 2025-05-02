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
import 'package:whph/core/acore/repository/models/sort_direction.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with AutomaticKeepAliveClientMixin {
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
  bool _showNoTagsFilter = false; // Added to track when "None" option is selected

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _isTasksListEmpty = false;
      });
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

  void _onFilterTags(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();
        _showNoTagsFilter = isNoneSelected;
        _isTasksListEmpty = false;
      });
      _refreshTasks(); // Refresh the task list when filter changes
    }
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (mounted) {
      setState(() {
        _filterStartDate = start;
        _filterEndDate = end;
      });
    }
  }

  void _onSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
    }
  }

  void _onCompletedTasksToggle(bool showCompleted) {
    if (mounted) {
      setState(() {
        _showCompletedTasks = showCompleted;
      });
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
            showNoTagsFilter: _showNoTagsFilter, // Pass the None filter state
            selectedStartDate: _filterStartDate,
            selectedEndDate: _filterEndDate,
            onTagFilterChange: _onFilterTags, // Fix parameter mismatch by using the properly defined function
            onDateFilterChange: _onDateFilterChange,
            onSearchChange: _onSearchChange,
            showCompletedTasks: _showCompletedTasks,
            onCompletedTasksToggle: _onCompletedTasksToggle,
            showTagFilter: true,
            showDateFilter: true,
            showSearchFilter: true,
            showCompletedTasksToggle: true,
            hasItems: true, // keep filters visible even if list is empty
          ),

          // Empty List Overlay or TaskList with conditional properties
          _isTasksListEmpty
              ? const Center(child: DoneOverlay())
              : TaskList(
                  key: _tasksListKey,
                  mediator: _mediator,
                  translationService: _translationService,
                  filterByCompleted: _showCompletedTasks,
                  filterByTags: _showNoTagsFilter ? [] : _selectedTagIds,
                  filterNoTags: _showNoTagsFilter,
                  filterByPlannedStartDate: _filterStartDate,
                  filterByPlannedEndDate: _filterEndDate,
                  filterByDeadlineStartDate: _filterStartDate,
                  filterByDeadlineEndDate: _filterEndDate,
                  filterDateOr: true,
                  sortByPlannedDate: SortDirection.asc,
                  search: _searchQuery,
                  onClickTask: (task) => _openTaskDetails(task.id),
                  onTaskCompleted: _refreshTasks,
                  onList: _showCompletedTasks ? null : _onTasksList,
                  onScheduleTask: (_, __) => _refreshTasks(),
                  enableReordering: !_showCompletedTasks,
                ),
        ],
      ),
    );
  }
}
