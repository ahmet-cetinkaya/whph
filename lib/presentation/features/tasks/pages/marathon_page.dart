import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/application/features/tasks/commands/save_task_time_record_command.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';

class MarathonPage extends StatefulWidget {
  static const String route = '/marathon';

  const MarathonPage({super.key});

  @override
  State<MarathonPage> createState() => _MarathonPageState();
}

class _MarathonPageState extends State<MarathonPage> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  Key _tasksListKey = UniqueKey();
  TaskListItem? _selectedTask;

  // Add new state variables for filters
  List<String>? _selectedTagIds;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    // Enable fullscreen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide all system bars
    );
  }

  @override
  void dispose() {
    // Return to normal mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _tasksListKey = UniqueKey();
      });
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

  void _handleTagFilterChange(List<DropdownOption<String>> tagOptions) {
    setState(() {
      _selectedTagIds = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();
      _tasksListKey = UniqueKey();
    });
  }

  void _handleDateFilterChange(DateTime? start, DateTime? end) {
    setState(() {
      _selectedStartDate = start;
      _selectedEndDate = end;
      _tasksListKey = UniqueKey();
    });
  }

  void _handleSearchChange(String? query) {
    setState(() {
      _searchQuery = query;
      _tasksListKey = UniqueKey();
    });
  }

  Future<void> _showTaskDetails(String taskId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _translationService.translate(TaskTranslationKeys.marathonDetailsTitle),
                    style: AppTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: _translationService.translate(SharedTranslationKeys.closeButton),
                  ),
                ],
              ),
              Expanded(
                child: TaskDetailsContent(taskId: taskId),
              ),
            ],
          ),
        ),
      ),
    );

    // Update selected task after dialog closes
    if (_selectedTask?.id == taskId) {
      try {
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
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: _translationService.translate(TaskTranslationKeys.getTaskError),
          );
        }
      }
    }

    _refreshTasks();
  }

  void _handleTimerUpdate(Duration elapsed) async {
    if (_selectedTask == null) return;

    final command = SaveTaskTimeRecordCommand(
      taskId: _selectedTask!.id,
      duration: elapsed.inSeconds,
    );

    try {
      await _mediator.send(command);
      _refreshSelectedTask(); // Refresh to show updated duration
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(TaskTranslationKeys.saveTaskError),
        );
      }
    }
  }

  Future<void> _refreshSelectedTask() async {
    if (_selectedTask == null) return;

    try {
      final query = GetTaskQuery(id: _selectedTask!.id);
      final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
      final taskTags = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          GetListTaskTagsQuery(taskId: _selectedTask!.id, pageIndex: 0, pageSize: 5));
      final subTasks = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
          GetListTasksQuery(pageIndex: 0, pageSize: 10, parentTaskId: _selectedTask!.id));

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
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(TaskTranslationKeys.getTaskError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add today's date for filtering
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

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
                      onCompleted: _refreshTasks,
                      trailingButtons: [
                        IconButton(
                          icon: const Icon(Icons.push_pin),
                          onPressed: _clearSelectedTask,
                          tooltip: _translationService.translate(TaskTranslationKeys.marathonUnpinTaskTooltip),
                        ),
                      ],
                      showSubTasks: true, // Enable sub-tasks display
                    ),
                  ],
                ),

              // Filters
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 8),
                child: TaskFilters(
                  selectedTagIds: _selectedTagIds,
                  selectedStartDate: _selectedStartDate,
                  selectedEndDate: _selectedEndDate,
                  onTagFilterChange: _handleTagFilterChange,
                  onDateFilterChange: _handleDateFilterChange,
                  onSearchChange: _handleSearchChange,
                  showDateFilter: false,
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
                  key: _tasksListKey,
                  mediator: _mediator,
                  translationService: _translationService,
                  filterByCompleted: false,
                  filterByTags: _selectedTagIds,
                  filterByPlannedStartDate: today,
                  filterByPlannedEndDate: tomorrow,
                  filterDateOr: false,
                  search: _searchQuery,
                  onTaskCompleted: _refreshTasks,
                  onClickTask: (task) => _showTaskDetails(task.id),
                  onSelectTask: _onSelectTask,
                  onScheduleTask: (_, __) => _refreshTasks(),
                  selectedTask: _selectedTask,
                  showSelectButton: true,
                  transparentCards: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
