import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_name_input_field.dart';
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

  bool _isTasksExpanded = false;
  Key _tasksListKey = UniqueKey();
  Key _contentKey = UniqueKey();
  Key _titleKey = UniqueKey();

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _tasksListKey = UniqueKey();
      });
    }
  }

  void _refreshTitle() {
    if (mounted) {
      setState(() {
        _titleKey = UniqueKey();
      });
    }
  }

  void _refreshContent() {
    if (mounted) {
      setState(() {
        _contentKey = UniqueKey();
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
      appBarTitle: TagNameInputField(
        key: _titleKey,
        id: widget.tagId,
        onTagUpdated: _refreshContent,
      ),
      appBarActions: [
        TagArchiveButton(
          tagId: widget.tagId,
          onArchiveSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.archiveTagTooltip),
        ),
        TagDeleteButton(
          tagId: widget.tagId,
          onDeleteSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.deleteTagTooltip),
        ),
        HelpMenu(
          titleKey: TagTranslationKeys.detailsHelpTitle,
          markdownContentKey: TagTranslationKeys.helpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Details
          TagDetailsContent(
            key: _contentKey,
            tagId: widget.tagId,
            onTagUpdated: _refreshTitle,
          ),

          // Tasks
          ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              if (!mounted) return;
              setState(() {
                _isTasksExpanded = isExpanded;
              });
            },
            children: [
              ExpansionPanel(
                  isExpanded: _isTasksExpanded,
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      contentPadding: EdgeInsets.only(left: 1),
                      leading: Icon(Icons.task),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_translationService.translate(TagTranslationKeys.detailsTasksLabel)),
                          TagAddButton(
                            onTagCreated: (taskId) => _refreshTasks(),
                            tooltip: _translationService.translate(TagTranslationKeys.addTaskTooltip),
                          ),
                        ],
                      ),
                    );
                  },
                  body: TaskList(
                    key: _tasksListKey,
                    mediator: _mediator,
                    translationService: _translationService,
                    onClickTask: _openTaskDetails,
                    filterByTags: [widget.tagId],
                    onTaskCompleted: _refreshTasks,
                    onScheduleTask: (_, __) => _refreshTasks(),
                  ),
                  backgroundColor: Colors.transparent,
                  canTapOnHeader: true)
            ],
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
