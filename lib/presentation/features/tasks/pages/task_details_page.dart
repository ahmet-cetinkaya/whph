import 'package:flutter/material.dart';
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

  const TaskDetailsPage({
    super.key,
    required this.taskId,
    this.hideSidebar = false,
    this.onTaskDeleted,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  String? _title;
  Key _contentKey = UniqueKey();
  bool _isCompleted = false;
  Key _subTasksListKey = UniqueKey();
  bool _isCompletedTasksExpanded = false;
  Key _completedSubTasksListKey = UniqueKey();

  final _translationService = container.resolve<ITranslationService>();

  void _refreshContent() {
    if (mounted) {
      setState(() {
        _contentKey = UniqueKey();
      });
    }
  }

  void _refreshTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title.replaceAll('\n', ' ');
      });
    }
  }

  void _refreshSubTasks() {
    if (mounted) {
      setState(() {
        _subTasksListKey = UniqueKey();
        _completedSubTasksListKey = UniqueKey();
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: Row(
        children: [
          TaskCompleteButton(
            taskId: widget.taskId,
            isCompleted: _isCompleted,
            onToggleCompleted: () => _refreshContent(),
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
        children: [
          // Task Details Content
          TaskDetailsContent(
            key: _contentKey,
            taskId: widget.taskId,
            onTitleUpdated: _refreshTitle,
            onCompletedChanged: (isCompleted) {
              setState(() {
                _isCompleted = isCompleted;
              });
            },
          ),

          // Sub-Tasks Header
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeSmall),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.list),
                    const SizedBox(width: 8),
                    Text(_translationService.translate(TaskTranslationKeys.subTasksLabel)),
                    const SizedBox(width: 8),
                    StreamBuilder<GetTaskQueryResponse>(
                      stream: Stream.fromFuture(
                        container.resolve<Mediator>().send(GetTaskQuery(id: widget.taskId)),
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data?.subTasks.isEmpty == true) {
                          return const SizedBox.shrink();
                        }

                        return Text(
                          '${snapshot.data!.subTasksCompletionPercentage.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.sizeXSmall),
                  child: TaskAddButton(
                    onTaskCreated: (taskId) => _refreshSubTasks(),
                    initialParentTaskId: widget.taskId,
                  ),
                ),
              ],
            ),
          ),

          // Active Sub-Tasks List
          TaskList(
            key: _subTasksListKey,
            mediator: container.resolve<Mediator>(),
            translationService: container.resolve<ITranslationService>(),
            onClickTask: (task) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TaskDetailsPage(taskId: task.id),
                ),
              );
              _refreshSubTasks();
            },
            parentTaskId: widget.taskId,
            filterByCompleted: false,
            onTaskCompleted: _refreshSubTasks,
            onScheduleTask: (_, __) => _refreshSubTasks(),
          ),
          const SizedBox(height: 8),

          // Completed Sub-Tasks
          ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              if (!mounted) return;
              setState(() {
                _isCompletedTasksExpanded = !_isCompletedTasksExpanded;
              });
            },
            children: [
              ExpansionPanel(
                isExpanded: _isCompletedTasksExpanded,
                headerBuilder: (context, isExpanded) {
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 8),
                    leading: const Icon(Icons.done_all),
                    title: Text(_translationService.translate(TaskTranslationKeys.completedTasksTitle)),
                  );
                },
                body: TaskList(
                  key: _completedSubTasksListKey,
                  mediator: container.resolve<Mediator>(),
                  translationService: container.resolve<ITranslationService>(),
                  onClickTask: (task) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TaskDetailsPage(taskId: task.id),
                      ),
                    );
                    _refreshSubTasks();
                  },
                  parentTaskId: widget.taskId,
                  filterByCompleted: true,
                  onTaskCompleted: _refreshSubTasks,
                  onScheduleTask: (_, __) => _refreshSubTasks(),
                ),
                backgroundColor: Colors.transparent,
                canTapOnHeader: true,
              ),
            ],
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
          ),
        ],
      ),
      hideSidebar: widget.hideSidebar,
    );
  }
}
