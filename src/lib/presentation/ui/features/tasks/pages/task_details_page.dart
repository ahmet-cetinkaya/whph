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
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/task_details_content.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/components/section_header.dart';

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
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _tasksService = container.resolve<TasksService>();

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
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      _isRefreshInProgress = true;

      // Load task details including completion percentage (no list refresh needed)
      _loadTaskDetails().then((_) {
        // Mark refresh as complete
        _isRefreshInProgress = false;
      });
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
    });
  }

  void _onSearchChange(String? query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onSortChange(SortConfig<TaskSortFields> newConfig) {
    setState(() {
      _taskSortConfig = newConfig;
    });
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    setState(() {
      _selectedTagIds = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();
      _showNoTagsFilter = isNoneSelected;
    });
  }

  void _onTaskCreated(String taskId, dynamic taskData) {
    // TasksList will automatically refresh via its event listeners
    // Only refresh task details for completion percentage update
    _loadTaskDetails();
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
      size: DialogSize.xLarge,
    );
    // TasksList will auto-refresh, just update completion percentage
    _loadTaskDetails();
  }

  void _onSubTaskDeleted() {
    // TasksList will auto-refresh, just update completion percentage
    _loadTaskDetails();
    Navigator.of(context).pop();
  }

  void _onSubTaskCompleted() {
    _hideCompletedTasks();
    // TasksList will auto-refresh, just update completion percentage
    _loadTaskDetails();
  }

  void _onScheduleTask(TaskListItem task, DateTime date) {
    // TasksList will auto-refresh, just update completion percentage
    _loadTaskDetails();
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
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Listen to task events that affect this task's subtasks
    _tasksService.onTaskCreated.addListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.addListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.addListener(_handleTaskDeleted);
    _tasksService.onTaskCompleted.addListener(_handleTaskCompleted);
  }

  void _removeEventListeners() {
    _tasksService.onTaskCreated.removeListener(_handleTaskCreated);
    _tasksService.onTaskUpdated.removeListener(_handleTaskUpdated);
    _tasksService.onTaskDeleted.removeListener(_handleTaskDeleted);
    _tasksService.onTaskCompleted.removeListener(_handleTaskCompleted);
  }

  void _handleTaskCreated() {
    if (mounted) {
      _loadTaskDetails(); // Update completion percentage
    }
  }

  void _handleTaskUpdated() {
    if (mounted) {
      _loadTaskDetails(); // Update completion percentage
    }
  }

  void _handleTaskDeleted() {
    // If the deleted task is the current one, don't reload details as it will fail
    // The page navigation back is handled by the delete button's onSuccess callback
    if (_tasksService.onTaskDeleted.value == widget.taskId) {
      return;
    }

    if (mounted) {
      _loadTaskDetails(); // Update completion percentage
    }
  }

  void _handleTaskCompleted() {
    if (mounted) {
      _loadTaskDetails(); // Update completion percentage
    }
  }

  @override
  void dispose() {
    _removeEventListeners();
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
        elevation: 0,
        leading: widget.hideSidebar
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: [
          TaskDeleteButton(
            taskId: widget.taskId,
            onDeleteSuccess: _onTaskDeleteSuccess,
            buttonColor: _themeService.primaryColor,
          ),
        ],
      ),
      body: Padding(
        padding: context.pageBodyPadding,
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
              SectionHeader(
                title: _translationService.translate(TaskTranslationKeys.subTasksLabel),
                trailing: (_subTasksCompletionPercentage != null && _subTasksCompletionPercentage! > 0)
                    ? Text(
                        '${_subTasksCompletionPercentage!.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : null,
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
