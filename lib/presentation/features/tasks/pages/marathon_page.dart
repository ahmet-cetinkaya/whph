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

class MarathonPage extends StatefulWidget {
  static const String route = '/marathon';

  const MarathonPage({super.key});

  @override
  State<MarathonPage> createState() => _MarathonPageState();
}

class _MarathonPageState extends State<MarathonPage> {
  final Mediator _mediator = container.resolve<Mediator>();
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

  void _onSelectTask(TaskListItem task) {
    setState(() {
      _selectedTask = task;
    });
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
                  const Text(
                    'Task Details',
                    style: AppTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
        var query = GetTaskQuery(id: taskId);
        var task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
        var taskTags = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
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
          ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to load task details.');
        }
      }
    }

    _refreshTasks();
  }

  void _handleTimerUpdate(Duration elapsed) async {
    if (_selectedTask == null) return;

    var command = SaveTaskTimeRecordCommand(
      taskId: _selectedTask!.id,
      duration: elapsed.inSeconds,
    );

    try {
      await _mediator.send(command);
      _refreshSelectedTask(); // Refresh to show updated duration
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Failed to save task time record.');
      }
    }
  }

  Future<void> _refreshSelectedTask() async {
    if (_selectedTask == null) return;

    try {
      var query = GetTaskQuery(id: _selectedTask!.id);
      var task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
      var taskTags = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          GetListTaskTagsQuery(taskId: _selectedTask!.id, pageIndex: 0, pageSize: 5));

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
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Failed to refresh selected task.');
      }
    }
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Marathon Mode Help',
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '🎯 Marathon Mode is designed to help you focus on your tasks using the Pomodoro Technique.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '⏰ The Pomodoro Technique',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'A time management method that uses a timer to break work into intervals. You can customize work and break durations to your preference:',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Common patterns:',
                  '  - 25 min work / 5 min break (Classic)',
                  '  - 50 min work / 10 min break (Extended)',
                  '• After 4 work sessions, take a longer 15-30 minute break',
                  '• Choose what works best for you',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '🎯 Benefits',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Increases focus and concentration',
                  '• Reduces mental fatigue',
                  '• Maintains motivation through small wins',
                  '• Creates a sense of urgency',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '💡 Pro Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Use tags to track time across related tasks',
                  '• Review tag time reports to understand your focus areas',
                  '• Organize tasks with relevant tags before starting',
                  '• Remove all distractions before starting',
                  '• Use breaks to stretch or move around',
                  '• Stay hydrated during breaks',
                  '• Don\'t skip breaks - they\'re important!',
                  '• Start with your most important task',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '❔ How to Use',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '1. Select a task from the list to work on',
                  '2. Start the Pomodoro timer',
                  '3. Focus on your task until the timer ends',
                  '4. Take a short break when the timer rings',
                  '5. Repeat the process',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Features',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Smart time tracking:',
                  '  - Automatically records time to tasks',
                  '  - Updates time spent on associated tags',
                  '  - Helps track project and category time investments',
                  '• Task filtering and search',
                  '• Task details and updates',
                  '• Progress tracking',
                  '• Tag-based organization',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
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
                    ),
                    Expanded(
                      child: Center(
                        child: PomodoroTimer(
                          onTimeUpdate: _handleTimerUpdate,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: _showHelpModal,
                    ),
                  ],
                ),
              ),

              // Selected Task
              if (_selectedTask != null)
                Column(
                  children: [
                    const Text(
                      'Currently Working On:',
                      style: AppTheme.headlineSmall,
                    ),
                    TaskCard(
                      task: _selectedTask!,
                      onOpenDetails: () => _showTaskDetails(_selectedTask!.id),
                      onCompleted: _refreshTasks,
                      trailingButtons: [
                        IconButton(
                          icon: const Icon(Icons.push_pin),
                          onPressed: _clearSelectedTask,
                        ),
                      ],
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
                        'Select a task to work on from the list below.',
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
