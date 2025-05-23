import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/application/features/tasks/commands/save_task_time_record_command.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';

class MarathonPage extends StatefulWidget {
  static const String route = '/marathon';

  const MarathonPage({super.key});

  @override
  State<MarathonPage> createState() => _MarathonPageState();
}

class _MarathonPageState extends State<MarathonPage> with AutomaticKeepAliveClientMixin {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  TaskListItem? _selectedTask;
  SortConfig<TaskSortFields> _sortConfig = TaskDefaults.sorting;

  List<String>? _selectedTagIds;
  String? _searchQuery;
  bool _showCompletedTasks = false;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide all system bars
    );
    _setupEventListeners();
  }

  void _setupEventListeners() {
    final tasksService = container.resolve<TasksService>();
    tasksService.addListener(_onTasksChanged);
  }

  @override
  void dispose() {
    final tasksService = container.resolve<TasksService>();
    tasksService.removeListener(_onTasksChanged);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onTasksChanged() {
    if (mounted) {
      setState(() {});
      _refreshSelectedTaskIfNeeded();
    }
  }

  void _refreshSelectedTaskIfNeeded() {
    if (_selectedTask != null) {
      _refreshSelectedTask();
    }
  }

  void _onSelectTask(TaskListItem task) async {
    setState(() {
      _selectedTask = task;
    });
    await _refreshSelectedTask(); // Refresh task to get sub-tasks
  }

  void _clearSelectedTask() {
    setState(() {
      _selectedTask = null;
    });
  }

  Future<void> _showTaskDetails(String taskId) async {
    final wasDeleted = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
        onTaskDeleted: () {
          // Only close the dialog here, don't pop twice
          Navigator.of(context).pop(true);
        },
      ),
    );

    // If task was deleted, clear selection and refresh
    if (wasDeleted == true && _selectedTask?.id == taskId) {
      setState(() {
        _selectedTask = null;
      });
      _onTasksChanged();
      return;
    }

    // Update selected task after dialog closes (only if not deleted)
    if (_selectedTask?.id == taskId) {
      if (mounted) {
        await AsyncErrorHandler.execute<void>(
          context: context,
          errorMessage: _translationService.translate(TaskTranslationKeys.getTaskError),
          operation: () async {
            final query = GetTaskQuery(id: taskId);
            final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
            final taskTags = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
                GetListTaskTagsQuery(taskId: taskId, pageIndex: 0, pageSize: 5));

            if (mounted) {
              setState(() {
                _selectedTask = TaskListItem(
                    id: task.id,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    deadlineDate: task.deadlineDate,
                    estimatedTime: task.estimatedTime,
                    plannedDate: task.plannedDate,
                    priority: task.priority,
                    tags: taskTags.items.map((e) => TagListItem(id: e.id, name: e.tagName)).toList());
              });
            }
            return;
          },
          onError: (error) {
            // Task might have been deleted or other error occurred
            if (mounted) {
              setState(() {
                _selectedTask = null; // Clear selected task on error
              });

              // Only show error if it's not a "not found" error
              if (error.toString().toLowerCase().contains('not found')) {
                // Task was deleted, silently clear selection
                return false; // Don't show error message
              }

              return true; // Show error message
            }
            return false;
          },
        );
      }
    }

    _onTasksChanged();
  }

  void _handleTimerUpdate(Duration _) async {
    if (_selectedTask == null) return;

    final nextDuration = _selectedTask!.totalElapsedTime + 1;

    final command = SaveTaskTimeRecordCommand(
      taskId: _selectedTask!.id,
      duration: nextDuration,
    );

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () async {
        await _mediator.send(command);
        _selectedTask!.totalElapsedTime = nextDuration;
      },
    );
  }

  Future<void> _refreshSelectedTask() async {
    if (_selectedTask == null) return;

    await AsyncErrorHandler.execute<void>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.getTaskError),
      operation: () async {
        final query = GetTaskQuery(id: _selectedTask!.id);
        final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
        final taskTags = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
            GetListTaskTagsQuery(taskId: _selectedTask!.id, pageIndex: 0, pageSize: 5));
        final subTasks = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
            GetListTasksQuery(pageIndex: 0, pageSize: 10, filterByParentTaskId: _selectedTask!.id));

        if (mounted) {
          setState(() {
            _selectedTask = TaskListItem(
              id: task.id,
              title: task.title,
              isCompleted: task.isCompleted,
              deadlineDate: task.deadlineDate,
              estimatedTime: task.estimatedTime,
              plannedDate: task.plannedDate,
              priority: task.priority,
              tags: taskTags.items.map((e) => TagListItem(id: e.id, name: e.tagName)).toList(),
              subTasks: subTasks.items,
            );
          });
        }
        return;
      },
    );
  }

  void _onSortConfigChange(SortConfig<TaskSortFields> newConfig) {
    if (mounted) {
      setState(() {
        _sortConfig = newConfig;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Add today's date for filtering
    final now = DateTime.now();
    final todayForFilter = DateTime(now.year, now.month, now.day);
    final tomorrowForFilter = todayForFilter.add(const Duration(days: 1));

    const String taskFilterOptionsSettingKeySuffix = 'MARATHON_PAGE';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, result) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
      },
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              // Pomodoro Timer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: _translationService.translate(SharedTranslationKeys.closeButton),
                    ),
                    Expanded(
                      child: Center(
                        child: PomodoroTimer(
                          onTimeUpdate: _handleTimerUpdate,
                        ),
                      ),
                    ),
                    HelpMenu(
                      titleKey: TaskTranslationKeys.marathonHelpTitle,
                      markdownContentKey: TaskTranslationKeys.marathonHelpContent,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // Selected Task
              if (_selectedTask != null)
                Column(
                  children: [
                    Text(
                      _translationService.translate(TaskTranslationKeys.marathonCurrentTask),
                      style: AppTheme.headlineSmall,
                    ),
                    TaskCard(
                      taskItem: _selectedTask!,
                      onOpenDetails: () => _showTaskDetails(_selectedTask!.id),
                      onCompleted: () {
                        Future.delayed(const Duration(seconds: 2), () => {_clearSelectedTask(), _onTasksChanged()});
                      },
                      trailingButtons: [
                        IconButton(
                          icon: const Icon(Icons.push_pin),
                          onPressed: _clearSelectedTask,
                          tooltip: _translationService.translate(TaskTranslationKeys.marathonUnpinTaskTooltip),
                        ),
                      ],
                    ),
                  ],
                ),

              // Filters
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TaskListOptions(
                        selectedTagIds: _selectedTagIds,
                        showNoTagsFilter: false,
                        onSearchChange: (query) {
                          setState(() {
                            _searchQuery = query;
                          });
                        },
                        showCompletedTasks: _showCompletedTasks,
                        onCompletedTasksToggle: (showCompleted) {
                          setState(() {
                            _showCompletedTasks = showCompleted;
                          });
                        },
                        hasItems: true,
                        showDateFilter: false,
                        showTagFilter: false,
                        showSortButton: true,
                        showSearchFilter: true,
                        sortConfig: _sortConfig,
                        onSortChange: _onSortConfigChange,
                        settingKeyVariantSuffix: taskFilterOptionsSettingKeySuffix,
                      ),
                    ),
                  ],
                ),
              ),

              // Hint Text
              if (_selectedTask == null)
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translationService.translate(TaskTranslationKeys.marathonSelectTaskHint),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

              // Update TaskList with today's date filter
              Expanded(
                child: TaskList(
                  filterByCompleted: _showCompletedTasks,
                  filterByTags: _selectedTagIds,
                  filterByPlannedEndDate: tomorrowForFilter,
                  filterByDeadlineEndDate: tomorrowForFilter,
                  filterDateOr: true,
                  search: _searchQuery,
                  onTaskCompleted: _onTasksChanged,
                  onClickTask: (task) => _showTaskDetails(task.id),
                  onSelectTask: _onSelectTask,
                  onScheduleTask: (_, __) => _onTasksChanged(),
                  selectedTask: _selectedTask,
                  showSelectButton: true,
                  transparentCards: true,
                  enableReordering: _sortConfig.useCustomOrder,
                  sortConfig: _sortConfig,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
