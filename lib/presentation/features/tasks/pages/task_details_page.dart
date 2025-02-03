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
              widget.onTaskDeleted?.call();
              // Remove the Navigator.pop() from here since we'll handle navigation in the parent
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
            padding: const EdgeInsets.all(16.0),
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
                TaskAddButton(
                  onTaskCreated: (taskId) => _refreshSubTasks(),
                  initialParentTaskId: widget.taskId,
                ),
              ],
            ),
          ),

          // Sub-Tasks List
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
            onTaskCompleted: _refreshSubTasks,
            onScheduleTask: (_, __) => _refreshSubTasks(),
          ),
          const SizedBox(height: 8),
        ],
      ),
      hideSidebar: widget.hideSidebar,
    );
  }
}
