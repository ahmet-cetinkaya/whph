import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_name_input_field.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TagDetailsPage extends StatefulWidget {
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> {
  final Mediator mediator = container.resolve<Mediator>();

  bool _isTasksExpanded = false;

  Future<void> _openTaskDetails(TaskListItem task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(taskId: task.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: TagNameInputField(
          id: widget.tagId,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TagDeleteButton(
                tagId: widget.tagId,
                onDeleteSuccess: () {
                  Navigator.of(context).pop();
                },
                buttonColor: AppTheme.primaryColor,
                buttonBackgroundColor: AppTheme.surface2),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Details
          TagDetailsContent(
            tagId: widget.tagId,
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
                      contentPadding: EdgeInsets.only(left: 8),
                      leading: Icon(Icons.task),
                      title: Text('Tasks'),
                    );
                  },
                  body: TaskList(
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
