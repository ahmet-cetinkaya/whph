import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
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
import 'package:whph/presentation/features/tasks/components/task_filters.dart';

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
  final _tasksListKey = GlobalKey<TaskListState>();

  String? _title;
  String? _searchQuery;
  bool _showCompletedTasks = false;

  void _refreshTasks() {
    if (mounted) {
      _tasksListKey.currentState?.refresh(showLoading: true);
    }
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
          const SizedBox(height: AppTheme.sizeSmall),

          // Tasks Section
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
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        const Icon(Icons.task),
                        const SizedBox(width: 8),
                        Text(_translationService.translate(TagTranslationKeys.detailsTasksLabel)),

                        // Filters
                        const SizedBox(width: AppTheme.sizeMedium),
                        Expanded(
                          child: TaskFilters(
                            onSearchChange: (query) {
                              setState(() {
                                _searchQuery = query;
                              });
                              _refreshTasks();
                            },
                            showCompletedTasks: _showCompletedTasks,
                            onCompletedTasksToggle: (showCompleted) {
                              setState(() {
                                _showCompletedTasks = showCompleted;
                              });
                              _refreshTasks();
                            },
                            showDateFilter: false,
                            showTagFilter: false,
                            hasItems: true,
                          ),
                        ),

                        // Add Task
                        if (!_showCompletedTasks)
                          TaskAddButton(
                            onTaskCreated: (_, __) => _refreshTasks(),
                            initialTagIds: [widget.tagId],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Task List Container
          Expanded(
            child: Container(
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
                  mediator: _mediator,
                  translationService: _translationService,
                  onClickTask: _openTaskDetails,
                  filterByTags: [widget.tagId],
                  filterByCompleted: _showCompletedTasks,
                  search: _searchQuery,
                  onTaskCompleted: _refreshTasks,
                  onScheduleTask: (_, __) => _refreshTasks(),
                  enableReordering: !_showCompletedTasks,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
