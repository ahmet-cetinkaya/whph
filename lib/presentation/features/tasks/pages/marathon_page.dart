import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/features/tasks/components/task_card.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';

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

  void _handleTagFilterChange(List<String> tagIds) {
    setState(() {
      _selectedTagIds = tagIds.isEmpty ? null : tagIds;
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
      var query = GetTaskQuery(
        id: taskId,
      );
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
    }

    _refreshTasks();
  }

  void _handleTimerUpdate(Duration elapsed) async {
    if (_selectedTask == null) return;

    var command = SaveTaskCommand(
      id: _selectedTask!.id,
      title: _selectedTask!.title,
      priority: _selectedTask!.priority,
      plannedDate: _selectedTask!.plannedDate,
      deadlineDate: _selectedTask!.deadlineDate,
      estimatedTime: _selectedTask!.estimatedTime,
      elapsedTime: elapsed.inSeconds,
      isCompleted: _selectedTask!.isCompleted,
    );

    _mediator.send(command);
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
        child: Column(
          children: [
            // Pomodoro Timer
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  PomodoroTimer(
                    onTimeUpdate: _handleTimerUpdate, // Update this line
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Selected Task
            if (_selectedTask != null)
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

            // Filters
            TaskFilters(
              selectedTagIds: _selectedTagIds,
              selectedStartDate: _selectedStartDate,
              selectedEndDate: _selectedEndDate,
              onTagFilterChange: _handleTagFilterChange,
              onDateFilterChange: _handleDateFilterChange,
              onSearchChange: _handleSearchChange,
              showDateFilter: false,
            ),

            // Update TaskList with today's date filter
            Expanded(
              child: TaskList(
                key: _tasksListKey,
                mediator: _mediator,
                filterByCompleted: false,
                filterByTags: _selectedTagIds,
                filterByPlannedStartDate: today, // Add today as start date
                filterByPlannedEndDate: tomorrow, // Add tomorrow as end date
                filterDateOr: false, // Use AND logic for date filtering
                search: _searchQuery,
                onTaskCompleted: _refreshTasks,
                onClickTask: (task) => _showTaskDetails(task.id),
                onSelectTask: _onSelectTask,
                selectedTask: _selectedTask,
                showSelectButton: true,
                transparentCards: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
