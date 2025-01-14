import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_name_input_field.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';

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

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: TagNameInputField(id: widget.tagId),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TagArchiveButton(
            tagId: widget.tagId,
            onArchiveSuccess: () => Navigator.of(context).pop(),
            buttonColor: AppTheme.primaryColor,
            buttonBackgroundColor: AppTheme.surface2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TagDeleteButton(
            tagId: widget.tagId,
            onDeleteSuccess: () => Navigator.of(context).pop(),
            buttonColor: AppTheme.primaryColor,
            buttonBackgroundColor: AppTheme.surface2,
          ),
        ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TagDetailsContent(tagId: widget.tagId),
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
                      title: Text('Tasks'),
                      trailing: TaskAddButton(
                        onTaskCreated: (taskId) => _refreshTasks(),
                        buttonColor: AppTheme.primaryColor,
                        buttonBackgroundColor: AppTheme.surface2,
                        initialTagIds: [widget.tagId],
                      ),
                    );
                  },
                  body: TaskList(
                    key: _tasksListKey,
                    mediator: mediator,
                    onClickTask: _openTaskDetails,
                    filterByTags: [widget.tagId],
                  ),
                  backgroundColor: AppTheme.surface2,
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
