import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_name_input_field.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> {
  final Mediator mediator = container.resolve<Mediator>();

  bool _isTasksExpanded = false;
  Key _tasksListKey = UniqueKey();

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _tasksListKey = UniqueKey();
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
                      'Tag Details Help',
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
                  '🏷️ Tags help you organize and track time across related tasks.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Features',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Time tracking across tasks:',
                  '  - Automatically accumulates time from tasks',
                  '  - Shows total time investment for the tag',
                  '  - Helps track project or category focus',
                  '• Related tags:',
                  '  - Connect related projects or categories',
                  '  - Create tag hierarchies',
                  '  - Track time across related tag groups',
                  '• Task organization',
                  '• Archive functionality',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '💡 Usage Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Use for projects, categories, or contexts',
                  '• Link related tags to create hierarchies:',
                  '  - Project tags to department tags',
                  '  - Subtask tags to main project tags',
                  '  - Category tags to broader areas',
                  '• Track time investment across tag groups',
                  '• Group related tasks together',
                  '• Archive tags for completed projects',
                  '• Use meaningful names for better organization',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '⚙️ Management',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Edit tag name anytime',
                  '• Add/remove related tags',
                  '• Add/remove tasks as needed',
                  '• Archive tags to hide completed projects',
                  '• Delete tags you no longer need',
                  '• View time statistics',
                  '• Track aggregate time across related tags',
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
    return ResponsiveScaffoldLayout(
      appBarTitle: TagNameInputField(id: widget.tagId),
      appBarActions: [
        TagArchiveButton(
          tagId: widget.tagId,
          onArchiveSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
        ),
        TagDeleteButton(
          tagId: widget.tagId,
          onDeleteSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpModal,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Details
          TagDetailsContent(tagId: widget.tagId),

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
                          Text('Tasks'),
                          TaskAddButton(
                            onTaskCreated: (taskId) => _refreshTasks(),
                            initialTagIds: [widget.tagId],
                          ),
                        ],
                      ),
                    );
                  },
                  body: TaskList(
                    key: _tasksListKey,
                    mediator: mediator,
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
