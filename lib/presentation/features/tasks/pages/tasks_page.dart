import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/task_add_floating_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();

  bool _isTaskListVisible = false;

  // Filter state
  List<String>? _selectedTagIds;
  bool _showCompletedTasks = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _searchQuery;
  bool _showNoTagsFilter = false;
  SortConfig<TaskSortFields> _sortConfig = TaskDefaults.sorting;

  String? _handledTaskId;

  @override
  bool get wantKeepAlive => true;

  Future<void> _openDetails(String taskId) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
      ),
      size: DialogSize.large,
    );
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

  void _onSortConfigChange(SortConfig<TaskSortFields> newConfig) {
    if (!mounted) return;
    setState(() {
      _sortConfig = newConfig;
    });
  }

  void _onSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isTaskListVisible = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments to show task details
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && (args.containsKey('taskId'))) {
      final taskId = args['taskId'] as String;

      // Only handle the task if we haven't already handled it or if it's a new navigation
      if (_handledTaskId != taskId) {
        _handledTaskId = taskId;

        // Schedule the dialog to open after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openDetails(taskId);
          }
        });
      }
    } else {
      // Check if we have a route name that includes a task ID
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null && routeName.startsWith('/tasks/') && routeName != '/tasks/details') {
        final taskId = routeName.substring('/tasks/'.length);

        // Only handle the task if we haven't already handled it
        if (_handledTaskId != taskId) {
          _handledTaskId = taskId;

          // Schedule the dialog to open after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDetails(taskId);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const String tasksListOptionsSettingsKeySuffix = "TASKS_PAGE";

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
              initialTagIds: _showNoTagsFilter ? [] : _selectedTagIds,
              initialTitle: _searchQuery,
              initialPlannedDate: _filterStartDate,
              initialDeadlineDate: _filterEndDate,
              initialCompleted: _showCompletedTasks,
            ),
            HelpMenu(
              titleKey: TaskTranslationKeys.tasksHelpTitle,
              markdownContentKey: TaskTranslationKeys.tasksHelpContent,
            ),
            const SizedBox(width: AppTheme.sizeSmall),
          ],
        ),
      ],
      // Add floating action button for mobile devices
      floatingActionButton: TaskAddFloatingButton(
        initialTagIds: _showNoTagsFilter ? [] : _selectedTagIds,
        initialTitle: _searchQuery,
        initialPlannedDate: _filterStartDate,
        initialDeadlineDate: _filterEndDate,
        initialCompleted: _showCompletedTasks,
      ),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters with Completed Tasks Toggle
          TaskListOptions(
            selectedTagIds: _selectedTagIds,
            showNoTagsFilter: _showNoTagsFilter,
            selectedStartDate: _filterStartDate,
            selectedEndDate: _filterEndDate,
            onTagFilterChange: _onFilterTags,
            onDateFilterChange: _onDateFilterChange,
            onSearchChange: _onSearchChange,
            showCompletedTasks: _showCompletedTasks,
            onCompletedTasksToggle: _onCompletedTasksToggle,
            showTagFilter: true,
            showDateFilter: true,
            showSearchFilter: true,
            showCompletedTasksToggle: true,
            hasItems: true,
            sortConfig: _sortConfig,
            onSortChange: _onSortConfigChange,
            settingKeyVariantSuffix: tasksListOptionsSettingsKeySuffix,
            onSettingsLoaded: _onSettingsLoaded,
          ),

          const SizedBox(height: AppTheme.sizeMedium),

          // Task List
          if (_isTaskListVisible)
            Expanded(
              child: TaskList(
                filterByCompleted: _showCompletedTasks,
                filterByTags: _showNoTagsFilter ? [] : _selectedTagIds,
                filterNoTags: _showNoTagsFilter,
                filterByPlannedStartDate: _filterStartDate,
                filterByPlannedEndDate: _filterEndDate,
                filterByDeadlineStartDate: _filterStartDate,
                filterByDeadlineEndDate: _filterEndDate,
                filterDateOr: true,
                search: _searchQuery,
                onClickTask: (task) => _openDetails(task.id),
                enableReordering: !_showCompletedTasks && _sortConfig.useCustomOrder,
                sortConfig: _sortConfig,
              ),
            ),
        ],
      ),
    );
  }
}
