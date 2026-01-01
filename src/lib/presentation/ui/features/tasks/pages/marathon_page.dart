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
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay/tour_overlay.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';

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

  final GlobalKey _timerKey = GlobalKey();
  final GlobalKey _selectedTaskKey = GlobalKey();
  final GlobalKey _filtersKey = GlobalKey();
  final GlobalKey _taskListKey = GlobalKey();
  final GlobalKey _mainContentKey = GlobalKey();

  bool _isTimerRunning = false;
  bool _isDimmed = false;
  Timer? _dimmingTimer;
  Duration _timeSinceLastSave = Duration.zero;
  static const Duration _dimmingDelay = Duration(seconds: 5);
  static const double _dimmingOpacity = 0;

  final ScrollController _scrollController = ScrollController();

  void _closeDialog() {
    Navigator.pop(context);
  }

  static const String _taskFilterOptionsSettingKeySuffix = 'MARATHON_PAGE';
  List<String>? _selectedTaskTagIds;
  String? _taskSearchQuery;
  bool _showCompletedTasks = false;
  bool _showSubTasks = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
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
    _scrollController.dispose();
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

    setState(() {
      _isTimerRunning = true;
      _timeSinceLastSave = Duration.zero;
    });
    _startDimmingTimer();
  }

  void _handleTimerTick(Duration elapsedIncrement) {
    // Use the elapsed increment provided by the timer
    _timeSinceLastSave += elapsedIncrement;
    if (_timeSinceLastSave.inSeconds >= TaskUiConstants.kPeriodicSaveIntervalSeconds) {
      _saveElapsedTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }
  }

  Future<void> _saveElapsedTime(Duration elapsed) async {
    if (_selectedTask == null) return;
    if (elapsed.inSeconds <= 0) return;

    final command = AddTaskTimeRecordCommand(
      taskId: _selectedTask!.id,
      duration: elapsed.inSeconds,
    );

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () => _mediator.send<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse>(command),
    );
  }

  /// Called when a work session completes (e.g., Pomodoro work → break transition).
  /// Flushes any accumulated elapsed time but intentionally does NOT stop dimming,
  /// so the dimming persists into the break segment.
  Future<void> _handleWorkSessionComplete(Duration totalElapsed) async {
    if (_timeSinceLastSave > Duration.zero) {
      await _saveElapsedTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }
  }

  /// Called when the timer actually stops (user stops / session ends).
  /// Flushes accumulated elapsed time and stops the dimming timer.
  Future<void> _handleTimerStop(Duration totalElapsed) async {
    _stopDimmingTimer();

    if (_timeSinceLastSave > Duration.zero) {
      await _saveElapsedTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }
  }

  void _onSelectTask(TaskListItem task) async {
    // Flush any pending elapsed time before switching tasks to ensure
    // accumulated time is attributed to the correct task
    if (_timeSinceLastSave > Duration.zero) {
      await _saveElapsedTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }

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
        _clearSelectedTask();
      }
    }
  }

  Future<void> _showTaskDetails(String taskId) async {
    final wasDeleted = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.xLarge,
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
        onTaskDeleted: () {
          Navigator.of(context).pop(true);
        },
        onTaskCompleted: () {
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
            if (mounted) {
              setState(() {
                _selectedTask = null;
              });

              if (error.toString().toLowerCase().contains('not found')) {
                return false;
              }

              return true;
            }
            return false;
          },
        );
      }
    }

    _onTasksChanged();
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

  void _onScrollInteraction() {
    _onUserInteraction();
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
          behavior: HitTestBehavior.opaque,
          onTap: _onUserInteraction,
          onScaleStart: (_) => _onUserInteraction(),
          onScaleUpdate: (_) => _onUserInteraction(),
          onScaleEnd: (_) => _onUserInteraction(),
          onLongPressStart: (_) => _onUserInteraction(),
          child: MouseRegion(
            onHover: (_) => _onUserInteraction(),
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    _onScrollInteraction();
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: context.pageBodyPadding,
                      child: Column(
                        key: _mainContentKey,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedOpacity(
                                opacity: _isDimmed ? _dimmingOpacity : 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: _closeDialog,
                                      tooltip: _translationService.translate(SharedTranslationKeys.closeButton),
                                    ),
                                  ],
                                ),
                              ),
                              Center(
                                child: AppTimer(
                                  key: _timerKey,
                                  onTick: _handleTimerTick,
                                  onTimerStart: _onTimerStart,
                                  onTimerStop: _handleTimerStop,
                                  onWorkSessionComplete: _handleWorkSessionComplete,
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: _isDimmed ? _dimmingOpacity : 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: KebabMenu(
                                  helpTitleKey: TaskTranslationKeys.marathonHelpTitle,
                                  helpMarkdownContentKey: TaskTranslationKeys.marathonHelpContent,
                                  onStartTour: _startTour,
                                  iconColor: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          if (_selectedTask != null) ...[
                            const SizedBox(height: AppTheme.sizeSmall),
                            Container(
                              key: _selectedTaskKey,
                              child: TaskCard(
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
                            ),
                          ],
                          AnimatedOpacity(
                            opacity: _isDimmed ? _dimmingOpacity : 1.0,
                            duration: const Duration(milliseconds: 500),
                            child: Padding(
                              key: _filtersKey,
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
                          AnimatedOpacity(
                            opacity: _isDimmed ? _dimmingOpacity : 1.0,
                            duration: const Duration(milliseconds: 500),
                            child: TaskList(
                              key: _taskListKey,
                              filterByCompleted: _showCompletedTasks,
                              filterByTags: _selectedTaskTagIds,
                              filterByPlannedStartDate: _showCompletedTasks ? null : DateTime(0),
                              filterByPlannedEndDate:
                                  _showCompletedTasks ? null : DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
                              filterByDeadlineStartDate: _showCompletedTasks ? null : DateTime(0),
                              filterByDeadlineEndDate:
                                  _showCompletedTasks ? null : DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
                              filterDateOr: true,
                              filterByCompletedStartDate:
                                  _showCompletedTasks ? DateTime(now.year, now.month, now.day) : null,
                              filterByCompletedEndDate:
                                  _showCompletedTasks ? DateTime(now.year, now.month, now.day, 23, 59, 59, 999) : null,
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
                ),
                // Dimming overlay - appears when dimmed and captures all touches
                if (_isDimmed)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onUserInteraction,
                      onScaleStart: (_) => _onUserInteraction(),
                      onScaleUpdate: (_) => _onUserInteraction(),
                      onScaleEnd: (_) => _onUserInteraction(),
                      onLongPressStart: (_) => _onUserInteraction(),
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _isDimmed ? 0.3 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _translationService.translate(SharedTranslationKeys.tapToResume).toUpperCase(),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  void _startTour() {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourMarathonAppUsageTitle),
        description: _translationService.translate(TaskTranslationKeys.tourMarathonAppUsageDescription),
        icon: Icons.bar_chart,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. App usage graph list introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourMarathonUsageStatisticsTitle),
        description: _translationService.translate(TaskTranslationKeys.tourMarathonUsageStatisticsDescription),
        targetKey: _timerKey,
        position: TourPosition.bottom,
      ),
      // 3. List options introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourMarathonFilterSortTitle),
        description: _translationService.translate(TaskTranslationKeys.tourMarathonFilterSortDescription),
        targetKey: _filtersKey,
        position: TourPosition.bottom,
      ),
      // 4. App tracking settings button introduce
      TourStep(
        title: _translationService.translate(TaskTranslationKeys.tourMarathonTrackingSettingsTitle),
        description: _translationService.translate(TaskTranslationKeys.tourMarathonTrackingSettingsDescription),
        targetKey: _taskListKey,
        position: TourPosition.top,
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(context).pop();
        },
        onSkip: () async {
          Navigator.of(context).pop();
        },
        translationService: _translationService,
      ),
    );
  }
}
