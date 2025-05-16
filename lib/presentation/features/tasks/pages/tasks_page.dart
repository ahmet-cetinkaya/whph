import 'package:flutter/material.dart';
import 'package:whph/main.dart';
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
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();

  List<String>? _selectedTagIds;
  bool _showCompletedTasks = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _searchQuery;
  bool _showNoTagsFilter = false; // Added to track when "None" option is selected
  String? _handledTaskId; // Track the task ID that we've already handled

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  Future<void> _openTaskDetails(String taskId) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      title: _translationService.translate(TaskTranslationKeys.detailsHelpTitle),
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
      ),
    );
    // The task list will refresh automatically through event listeners
  }

  void _onTasksList(count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();
        _showNoTagsFilter = isNoneSelected;
      });
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
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments to show task details
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && (args.containsKey('taskId'))) {
      final taskId = args['taskId'] as String;
      debugPrint('TasksPage: Received taskId argument with taskId: $taskId');

      // Only handle the task if we haven't already handled it or if it's a new navigation
      if (_handledTaskId != taskId) {
        _handledTaskId = taskId;
        debugPrint('TasksPage: Handling task details for taskId: $taskId');

        // Schedule the dialog to open after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint('TasksPage: Opening task details for taskId: $taskId');
            _openTaskDetails(taskId);
          }
        });
      } else {
        // If we're already handling this task, don't do anything
        debugPrint('TasksPage: Task already handled: $taskId');
      }
    } else {
      debugPrint('TasksPage: No taskId argument found in route settings');
      // Check if we have a route name that includes a task ID
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null && routeName.startsWith('/tasks/') && routeName != '/tasks/details') {
        final taskId = routeName.substring('/tasks/'.length);
        debugPrint('TasksPage: Extracted taskId from route name: $taskId');

        // Only handle the task if we haven't already handled it
        if (_handledTaskId != taskId) {
          _handledTaskId = taskId;

          // Schedule the dialog to open after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              debugPrint('TasksPage: Opening task details for taskId from route: $taskId');
              _openTaskDetails(taskId);
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TaskTranslationKeys.tasksPageTitle),
      appBarActions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskAddButton(
              onTaskCreated: (taskId, taskData) {
                // The task will be added through the event system
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

          const SizedBox(height: AppTheme.sizeMedium),

          // Task List
          TaskList(
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
            onList: _showCompletedTasks ? null : _onTasksList,
            enableReordering: !_showCompletedTasks,
          ),
        ],
      ),
    );
  }
}
