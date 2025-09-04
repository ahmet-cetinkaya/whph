import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_delete_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/core/shared/utils/logger.dart';

class TaskDetailsPage extends StatefulWidget {
  static const String route = '/tasks/details';
  final String taskId;
  final bool hideSidebar;
  final VoidCallback? onTaskDeleted;
  final VoidCallback? onTaskCompleted;
  final bool showCompletedTasksToggle;

  const TaskDetailsPage({
    super.key,
    required this.taskId,
    this.hideSidebar = false,
    this.onTaskDeleted,
    this.onTaskCompleted,
    this.showCompletedTasksToggle = true,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> with AutomaticKeepAliveClientMixin {
  bool _showCompletedTasks = false;
  double? _subTasksCompletionPercentage;
  Timer? _completedTasksHideTimer;
  Key _listRebuildKey = UniqueKey();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Task filter options
  String? _searchQuery;
  List<String>? _selectedTagIds;
  bool _showNoTagsFilter = false;
  SortConfig<TaskSortFields> _taskSortConfig = TaskDefaults.sorting;
  bool _isRefreshInProgress = false;
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  /// Refreshes the content with debounce to avoid excessive refreshes
  void _refreshEverything() {
    // If a refresh is already in progress, don't start another one
    if (_isRefreshInProgress) return;

    // Cancel any pending refresh
    _debounceTimer?.cancel();

    // Start a new debounced refresh
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      _isRefreshInProgress = true;

      // Update the rebuild key to force TaskList to rebuild
      setState(() {
        _listRebuildKey = UniqueKey();
      });

      // Refresh task list
      _refreshTasksList();

      // Load task details including completion percentage
      _loadTaskDetails().then((_) {
        // Mark refresh as complete
        _isRefreshInProgress = false;
      });
    });
  }

  void _refreshTasksList() {
    setState(() {
      _listRebuildKey = UniqueKey(); // Force rebuild with new key
    });
  }

  Future<void> _loadTaskDetails() async {
    try {
      final response = await container.resolve<Mediator>().send<GetTaskQuery, GetTaskQueryResponse>(
            GetTaskQuery(id: widget.taskId),
          );
      if (mounted) {
        setState(() {
          _subTasksCompletionPercentage = response.subTasksCompletionPercentage;
        });
      }
    } catch (e) {
      Logger.error('Error loading task details: $e');
    }
  }

  // Called when a task is completed to hide completed tasks immediately
  void _hideCompletedTasks() {
    if (_showCompletedTasks && mounted) {
      setState(() {
        _showCompletedTasks = false;
      });
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  // Event handler methods
  void _onTaskDeleteSuccess() {
    if (widget.onTaskDeleted != null) {
      widget.onTaskDeleted!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onTaskUpdated() {
    _refreshEverything();
  }

  void _onTaskCompletedChanged(bool isCompleted) {
    _refreshEverything();
    if (isCompleted && widget.onTaskCompleted != null) {
      widget.onTaskCompleted!();
    }
  }

  void _onCompletedTasksToggle(bool showCompleted) {
    setState(() {
      _showCompletedTasks = showCompleted;
      _listRebuildKey = UniqueKey();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshTasksList();
        });
      }
    });
  }

  void _onSearchChange(String? query) {
    setState(() {
      _searchQuery = query;
    });
    _refreshTasksList();
  }

  void _onSortChange(SortConfig<TaskSortFields> newConfig) {
    setState(() {
      _taskSortConfig = newConfig;
    });
    _refreshTasksList();
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    setState(() {
      _selectedTagIds = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();
      _showNoTagsFilter = isNoneSelected;
    });
    _refreshTasksList();
  }

  void _onTaskCreated(String taskId, dynamic taskData) {
    _refreshEverything();
  }

  Future<void> _onClickSubTask(TaskListItem task) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TaskDetailsPage(
        taskId: task.id,
        hideSidebar: true,
        showCompletedTasksToggle: widget.showCompletedTasksToggle,
        onTaskDeleted: _onSubTaskDeleted,
      ),
      size: DialogSize.large,
    );
    _refreshEverything();
  }

  void _onSubTaskDeleted() {
    _refreshEverything();
    Navigator.of(context).pop();
  }

  void _onSubTaskCompleted() {
    _hideCompletedTasks();
    _refreshEverything();
  }

  void _onScheduleTask(TaskListItem task, DateTime date) {
    _refreshEverything();
  }

  @override
  void didUpdateWidget(TaskDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _loadTaskDetails();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();

    // Add post-frame callback to ensure widget is mounted before refreshing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTasksList();
    });
  }

  @override
  void dispose() {
    _completedTasksHideTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const String subTaskFilterOptionsSettingKeySuffix = 'TASK_DETAILS_PAGE_SUBTASKS';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: widget.hideSidebar
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TaskDeleteButton(
              taskId: widget.taskId,
              onDeleteSuccess: _onTaskDeleteSuccess,
              buttonColor: _themeService.primaryColor,
            ),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Task Details Section
              TaskDetailsContent(
                taskId: widget.taskId,
                onTaskUpdated: _onTaskUpdated,
                onCompletedChanged: _onTaskCompletedChanged,
              ),
              const SizedBox(height: AppTheme.sizeMedium),

              // Sub Tasks Header Section
              Row(
                children: [
                  const Icon(Icons.list),
                  const SizedBox(width: AppTheme.sizeSmall),
                  Flexible(
                    child: Text(
                      _translationService.translate(TaskTranslationKeys.subTasksLabel),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.sizeSmall),
                  if (_subTasksCompletionPercentage != null && _subTasksCompletionPercentage! > 0)
                    Text(
                      '${_subTasksCompletionPercentage!.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),

              // Sub Tasks Filter and Add Button Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // FILTERS - wrapped with Expanded for proper space allocation
                  Expanded(
                    child: TaskListOptions(
                      selectedTagIds: _selectedTagIds,
                      showNoTagsFilter: _showNoTagsFilter,
                      showCompletedTasks: _showCompletedTasks,
                      onTagFilterChange: _onFilterTags,
                      onCompletedTasksToggle: _onCompletedTasksToggle,
                      onSearchChange: _onSearchChange,
                      onSortChange: _onSortChange,
                      hasItems: true,
                      showDateFilter: false,
                      showTagFilter: true,
                      showSortButton: true,
                      sortConfig: _taskSortConfig,
                      settingKeyVariantSuffix: subTaskFilterOptionsSettingKeySuffix,
                    ),
                  ),

                  // ADD BUTTON
                  if (!_showCompletedTasks) ...[
                    const SizedBox(width: AppTheme.sizeSmall),
                    TaskAddButton(
                      onTaskCreated: _onTaskCreated,
                      initialParentTaskId: widget.taskId,
                      initialCompleted: _showCompletedTasks,
                    ),
                  ],
                ],
              ),

              // Sub Tasks List Section
              TaskList(
                key: _listRebuildKey,
                onClickTask: _onClickSubTask,
                parentTaskId: widget.taskId,
                filterByCompleted: _showCompletedTasks,
                filterByTags: _showNoTagsFilter ? [] : _selectedTagIds,
                filterNoTags: _showNoTagsFilter,
                search: _searchQuery,
                onTaskCompleted: _onSubTaskCompleted,
                onScheduleTask: _onScheduleTask,
                enableReordering: !_showCompletedTasks && _taskSortConfig.useCustomOrder,
                sortConfig: _taskSortConfig,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
