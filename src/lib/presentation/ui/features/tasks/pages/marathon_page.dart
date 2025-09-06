import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';

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
  List<TaskListItem> _availableTasks = [];
  SortConfig<TaskSortFields> _sortConfig = TaskDefaults.sorting;

  // Dimming overlay state
  bool _isTimerRunning = false;
  bool _isDimmed = false;
  Timer? _dimmingTimer;
  static const Duration _dimmingDelay = Duration(seconds: 5); // Time before dimming starts
  static const double _dimmingOpacity = 0.15; // Opacity value when dimmed

  void _closeDialog() {
    Navigator.pop(context);
  }

  // Task filter options
  static const String _taskFilterOptionsSettingKeySuffix = 'MARATHON_PAGE';
  List<String>? _selectedTaskTagIds;
  String? _taskSearchQuery;
  bool _showCompletedTasks = false;
  bool _showSubTasks = false;

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
    _dimmingTimer?.cancel();
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

  void _onTasksLoaded(List<TaskListItem> tasks) {
    _availableTasks = tasks;
  }

  void _onTimerStart() {
    // Auto-select first uncompleted task if no task is currently selected
    if (_selectedTask == null && _availableTasks.isNotEmpty) {
      final firstUncompletedTask = _availableTasks.firstWhere(
        (task) => !task.isCompleted,
        orElse: () => _availableTasks.first,
      );
      _onSelectTask(firstUncompletedTask);
    }

    // Track timer state and start dimming countdown
    setState(() {
      _isTimerRunning = true;
    });
    _startDimmingTimer();
  }

  void _onTimerStop() {
    _stopDimmingTimer();
  }

  void _onSelectTask(TaskListItem task) async {
    setState(() {
      _selectedTask = task;
    });
    await _refreshSelectedTask();
  }

  void _clearSelectedTask() {
    setState(() {
      _selectedTask = null;
    });
  }

  void _selectNextTask() {
    // Refresh available tasks to ensure we have the latest data
    if (_availableTasks.isEmpty) {
      _clearSelectedTask();
      return;
    }

    // Filter out completed tasks and the current selected task
    final availableUncompletedTasks = _availableTasks
        .where(
          (task) => !task.isCompleted && task.id != _selectedTask?.id,
        )
        .toList();

    if (availableUncompletedTasks.isNotEmpty) {
      // Select the first uncompleted task
      _onSelectTask(availableUncompletedTasks.first);
    } else {
      // If no uncompleted tasks available, try to find any other task (completed ones)
      final otherTasks = _availableTasks
          .where(
            (task) => task.id != _selectedTask?.id,
          )
          .toList();

      if (otherTasks.isNotEmpty) {
        _onSelectTask(otherTasks.first);
      } else {
        // No other tasks available, clear selection
        _clearSelectedTask();
      }
    }
  }

  Future<void> _showTaskDetails(String taskId) async {
    final wasDeleted = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.large,
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
        onTaskDeleted: () {
          // Only close the dialog here, don't pop twice
          Navigator.of(context).pop(true);
        },
        onTaskCompleted: () {
          // Select next task when current task is completed
          _selectNextTask();
          _onTasksChanged();
        },
      ),
    );

    // If task was deleted, select next task and refresh
    if (wasDeleted == true && _selectedTask?.id == taskId) {
      setState(() {
        _selectedTask = null;
      });
      _onTasksChanged();
      _selectNextTask();
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
                    tags: taskTags.items
                        .map((e) => TagListItem(
                            id: e.id,
                            name: e.tagName.isNotEmpty
                                ? e.tagName
                                : _translationService.translate(SharedTranslationKeys.untitled)))
                        .toList());
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

  void _handleTimerUpdate(Duration elapsedIncrement) async {
    if (_selectedTask == null) return;

    // Add the actual elapsed time increment to the task's time record
    final command = AddTaskTimeRecordCommand(
      taskId: _selectedTask!.id,
      duration: elapsedIncrement.inSeconds, // Use the actual elapsed time increment
    );

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () async {
        await _mediator.send(command);
        // Update local state for UI display
        _selectedTask!.totalElapsedTime += elapsedIncrement.inSeconds;
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
              tags: taskTags.items
                  .map((e) => TagListItem(
                      id: e.id,
                      name: e.tagName.isNotEmpty
                          ? e.tagName
                          : _translationService.translate(SharedTranslationKeys.untitled)))
                  .toList(),
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

  // Dimming overlay methods
  void _startDimmingTimer() {
    _dimmingTimer?.cancel();
    _dimmingTimer = Timer(_dimmingDelay, () {
      if (_isTimerRunning && mounted) {
        setState(() {
          _isDimmed = true;
        });
      }
    });
  }

  void _resetDimmingTimer() {
    if (_isDimmed) {
      setState(() {
        _isDimmed = false;
      });
    }
    if (_isTimerRunning) {
      _startDimmingTimer();
    }
  }

  void _stopDimmingTimer() {
    _dimmingTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _isDimmed = false;
    });
  }

  void _onUserInteraction() {
    _resetDimmingTimer();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final now = DateTime.now();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, result) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
      },
      child: Material(
        color: AppTheme.surface0,
        child: GestureDetector(
          onTap: _onUserInteraction,
          onPanUpdate: (_) => _onUserInteraction(),
          child: MouseRegion(
            onHover: (_) => _onUserInteraction(),
            child: Stack(
              children: [
                // Main Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Pomodoro Timer Section (always visible)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AnimatedOpacity(
                              opacity: _isDimmed ? _dimmingOpacity : 1.0,
                              duration: const Duration(milliseconds: 500),
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _closeDialog,
                                tooltip: _translationService.translate(SharedTranslationKeys.closeButton),
                              ),
                            ),
                            // Removed Expanded widget here
                            Center(
                              child: PomodoroTimer(
                                onTimeUpdate: _handleTimerUpdate,
                                onTimerStart: _onTimerStart,
                                onTimerStop: _onTimerStop,
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: _isDimmed ? _dimmingOpacity : 1.0,
                              duration: const Duration(milliseconds: 500),
                              child: HelpMenu(
                                titleKey: TaskTranslationKeys.marathonHelpTitle,
                                markdownContentKey: TaskTranslationKeys.marathonHelpContent,
                              ),
                            ),
                          ],
                        ),

                        // Selected Task Section (always visible when task is selected)
                        if (_selectedTask != null) ...[
                          const SizedBox(height: AppTheme.sizeSmall),
                          TaskCard(
                            key: ValueKey(_selectedTask!.id),
                            taskItem: _selectedTask!,
                            onOpenDetails: () => _showTaskDetails(_selectedTask!.id),
                            onCompleted: () {
                              Future.delayed(const Duration(milliseconds: 500), () {
                                _selectNextTask();
                                _onTasksChanged();
                              });
                            },
                            showScheduleButton: false,
                          ),
                        ],

                        // Filters Section (dimmed when timer is running)
                        AnimatedOpacity(
                          opacity: _isDimmed ? _dimmingOpacity : 1.0,
                          duration: const Duration(milliseconds: 500),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TaskListOptions(
                                    selectedTagIds: _selectedTaskTagIds,
                                    showNoTagsFilter: false,
                                    onSearchChange: (query) {
                                      setState(() {
                                        _taskSearchQuery = query;
                                      });
                                    },
                                    showCompletedTasks: _showCompletedTasks,
                                    onCompletedTasksToggle: (showCompleted) {
                                      setState(() {
                                        _showCompletedTasks = showCompleted;
                                      });
                                    },
                                    showSubTasks: _showSubTasks,
                                    onSubTasksToggle: (showSubTasks) {
                                      setState(() {
                                        _showSubTasks = showSubTasks;
                                      });
                                    },
                                    hasItems: true,
                                    showDateFilter: false,
                                    showTagFilter: false,
                                    showSortButton: true,
                                    showSearchFilter: true,
                                    showSubTasksToggle: true,
                                    sortConfig: _sortConfig,
                                    onSortChange: _onSortConfigChange,
                                    settingKeyVariantSuffix: _taskFilterOptionsSettingKeySuffix,
                                  ),
                                ),
                                // Add task button
                                if (!_showCompletedTasks)
                                  TaskAddButton(
                                    initialTagIds: _selectedTaskTagIds,
                                    initialPlannedDate: DateTime.now(),
                                    initialTitle: _taskSearchQuery,
                                    initialCompleted: _showCompletedTasks,
                                    onTaskCreated: (_, __) => _onTasksChanged(),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Task List Section (dimmed when timer is running)
                        AnimatedOpacity(
                          opacity: _isDimmed ? _dimmingOpacity : 1.0,
                          duration: const Duration(milliseconds: 500),
                          child: TaskList(
                            filterByCompleted: _showCompletedTasks,
                            filterByTags: _selectedTaskTagIds,
                            filterByPlannedStartDate: DateTime(0),
                            filterByPlannedEndDate: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
                            filterByDeadlineStartDate: DateTime(0),
                            filterByDeadlineEndDate: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
                            filterDateOr: true,
                            search: _taskSearchQuery,
                            includeSubTasks: _showSubTasks,
                            onTaskCompleted: _onTasksChanged,
                            onClickTask: (task) => _showTaskDetails(task.id),
                            onSelectTask: _onSelectTask,
                            onScheduleTask: (_, __) => _onTasksChanged(),
                            onTasksLoaded: _onTasksLoaded,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
