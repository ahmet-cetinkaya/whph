import 'package:flutter/material.dart';
import 'dart:async'; // Added for Timer
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_delete_button.dart';
import 'package:whph/presentation/features/tasks/components/task_details_content.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskDetailsPage extends StatefulWidget {
  static const String route = '/tasks/details';
  final String taskId;
  final bool hideSidebar;
  final VoidCallback? onTaskDeleted;
  final bool showCompletedTasksToggle;

  const TaskDetailsPage({
    super.key,
    required this.taskId,
    this.hideSidebar = false,
    this.onTaskDeleted,
    this.showCompletedTasksToggle = true,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  String? _title;
  final _contentKey = GlobalKey<TaskDetailsContentState>();
  final _tasksListKey = GlobalKey<TaskListState>();
  final _translationService = container.resolve<ITranslationService>();

  bool _isCompleted = false;
  bool _showCompletedTasks = false;
  double? _subTasksCompletionPercentage;
  Timer? _completedTasksHideTimer;
  // Add refresh key to force list rebuilding when needed
  Key _listRebuildKey = UniqueKey();

  // Flag to track if a refresh is in progress to prevent refresh loops
  bool _isRefreshInProgress = false;
  // Timer to debounce multiple refresh calls
  Timer? _debounceTimer;

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

      // Refresh task content
      _refreshContent();

      // Refresh task list
      _refreshTasksList();

      // Load task details including completion percentage
      _loadTaskDetails().then((_) {
        // Mark refresh as complete
        _isRefreshInProgress = false;
      });
    });
  }

  void _refreshContent() {
    _contentKey.currentState?.refresh();
  }

  void _refreshTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title.replaceAll('\n', ' ');
      });
    }
  }

  void _refreshTasksList() {
    if (_tasksListKey.currentState != null) {
      _tasksListKey.currentState?.refresh();
    } else {
      // If the list state isn't available, force a UI rebuild
      setState(() {});
    }
  }

  Future<void> _loadTaskDetails() async {
    try {
      final response =
          await container.resolve<Mediator>().send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: widget.taskId));
      if (mounted) {
        setState(() {
          _subTasksCompletionPercentage = response.subTasksCompletionPercentage;
        });
      }
    } catch (e) {
      debugPrint('Error loading task details: $e');
    }
  }

  void _onCompletedTasksToggle() {
    if (!mounted) return;

    setState(() {
      _showCompletedTasks = !_showCompletedTasks;
      _listRebuildKey = UniqueKey(); // Force rebuild with new key
    });

    // Force immediate refresh of the task list with the new filter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tasksListKey.currentState != null) {
        _tasksListKey.currentState!.refresh();
      } else {
        _refreshEverything(); // Fall back to full refresh if list state isn't available
      }
    });
  }

  // Called when a task is completed to hide completed tasks immediately
  void _hideCompletedTasks() {
    if (_showCompletedTasks && mounted) {
      setState(() {
        _showCompletedTasks = false;
      });
    }
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
    return ResponsiveScaffoldLayout(
      // Enable back button when this is a subtask (when hideSidebar is true)
      showBackButton: widget.hideSidebar,
      appBarTitle: Row(
        children: [
          TaskCompleteButton(
            taskId: widget.taskId,
            isCompleted: _isCompleted,
            onToggleCompleted: () {
              _refreshContent();
              _refreshEverything();
            },
          ),
          const SizedBox(width: 8),
          if (_title != null) Expanded(child: Text(_title!)),
        ],
      ),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TaskDeleteButton(
            taskId: widget.taskId,
            onDeleteSuccess: () {
              if (widget.onTaskDeleted != null) {
                widget.onTaskDeleted!();
              } else {
                Navigator.of(context).pop();
              }
            },
            buttonColor: AppTheme.primaryColor,
          ),
        ),
        HelpMenu(
          titleKey: TaskTranslationKeys.detailsHelpTitle,
          markdownContentKey: TaskTranslationKeys.detailsHelpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TaskDetailsContent(
            key: _contentKey,
            taskId: widget.taskId,
            onTitleUpdated: _refreshTitle,
            onCompletedChanged: (isCompleted) {
              setState(() {
                _isCompleted = isCompleted;
              });
              // Refresh the task list when completion status changes
              _refreshEverything();
            },
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sizeSmall,
              vertical: AppTheme.sizeXSmall,
            ),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.list),
                      const SizedBox(width: 8),
                      Text(_translationService.translate(TaskTranslationKeys.subTasksLabel)),
                      const SizedBox(width: 8),
                      if (_subTasksCompletionPercentage != null && _subTasksCompletionPercentage! > 0)
                        Text(
                          '${_subTasksCompletionPercentage!.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_showCompletedTasks)
                        TaskAddButton(
                          onTaskCreated: (taskId) {
                            // Use the comprehensive refresh mechanism
                            _refreshEverything();
                          },
                          initialParentTaskId: widget.taskId,
                        ),
                      if (widget.showCompletedTasksToggle)
                        Tooltip(
                          message: _translationService.translate(TaskTranslationKeys.showCompletedTasksTooltip),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _onCompletedTasksToggle, // Use the proper toggle handler
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  _showCompletedTasks ? Icons.check_circle : Icons.check_circle_outline,
                                  color: _showCompletedTasks
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            margin: const EdgeInsets.fromLTRB(
              AppTheme.sizeSmall,
              0,
              AppTheme.sizeSmall,
              AppTheme.sizeSmall,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
              child: TaskList(
                key: _tasksListKey,
                rebuildKey: _listRebuildKey,
                mediator: container.resolve<Mediator>(),
                translationService: _translationService,
                onClickTask: (task) async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsPage(
                        taskId: task.id,
                        hideSidebar: true,
                        showCompletedTasksToggle: widget.showCompletedTasksToggle,
                        // Add back button for subtask detail pages
                        onTaskDeleted: () {
                          _refreshEverything();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                  _refreshEverything();
                },
                parentTaskId: widget.taskId,
                // Use correct filter value based on toggle state
                filterByCompleted: _showCompletedTasks,
                onTaskCompleted: () {
                  _hideCompletedTasks();
                  _refreshEverything();
                },
                onScheduleTask: (_, __) => _refreshEverything(),
                enableReordering: !_showCompletedTasks,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sizeSmall),
        ],
      ),
      hideSidebar: widget.hideSidebar,
    );
  }
}
