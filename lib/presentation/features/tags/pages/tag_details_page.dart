import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _activeTasksListKey = GlobalKey<TaskListState>();
  final _completedTasksListKey = GlobalKey<TaskListState>();

  String? _title;
  bool _isCompletedTasksExpanded = false;

  void _refreshTasks() {
    _activeTasksListKey.currentState?.refresh();
    _completedTasksListKey.currentState?.refresh();
  }

  void _refreshTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title.replaceAll('\n', ' ');
      });
    }
  }

  Future<void> _openTaskDetails(TaskListItem task) async {
    await Navigator.of(context).pushNamed(
      TaskDetailsPage.route,
      arguments: {'id': task.id},
    );
    _refreshTasks();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: _title != null ? Text(_title!) : null,
      appBarActions: [
        // Archive
        TagArchiveButton(
          tagId: widget.tagId,
          onArchiveSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.archiveTagTooltip),
        ),

        // Delete
        TagDeleteButton(
          tagId: widget.tagId,
          onDeleteSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.deleteTagTooltip),
        ),

        // Help
        HelpMenu(
          titleKey: TagTranslationKeys.detailsHelpTitle,
          markdownContentKey: TagTranslationKeys.helpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => ListView(
        children: [
          // Details
          TagDetailsContent(
            tagId: widget.tagId,
            onNameUpdated: _refreshTitle,
          ),

          // Tasks Header
          ListTile(
            contentPadding: const EdgeInsets.only(left: 1),
            leading: const Icon(Icons.task),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_translationService.translate(TagTranslationKeys.detailsTasksLabel)),

                // Add Task
                TaskAddButton(
                  onTaskCreated: (taskId) => _refreshTasks(),
                  initialTagIds: [widget.tagId],
                ),
              ],
            ),
          ),

          // Active Tasks List
          TaskList(
            key: _activeTasksListKey,
            mediator: _mediator,
            translationService: _translationService,
            onClickTask: _openTaskDetails,
            filterByTags: [widget.tagId],
            filterByCompleted: false,
            onTaskCompleted: _refreshTasks,
            onScheduleTask: (_, __) => _refreshTasks(),
          ),
          const SizedBox(height: 8),

          // Completed Tasks
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
                  key: _completedTasksListKey,
                  mediator: _mediator,
                  translationService: _translationService,
                  onClickTask: _openTaskDetails,
                  filterByTags: [widget.tagId],
                  filterByCompleted: true,
                  onTaskCompleted: _refreshTasks,
                  onScheduleTask: (_, __) => _refreshTasks(),
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
    );
  }
}
