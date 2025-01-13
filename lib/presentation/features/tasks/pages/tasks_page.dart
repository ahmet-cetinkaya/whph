import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/done_overlay.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final Mediator _mediator = container.resolve<Mediator>();

  List<String>? _selectedTagIds;

  Key _tasksListKey = UniqueKey();
  bool _isTasksListEmpty = false;

  bool _isCompletedTasksExpanded = false;
  Key _completedTasksListKey = UniqueKey();

  void _refreshTasks() {
    if (mounted) {
      setState(() {
        _tasksListKey = UniqueKey();
        _completedTasksListKey = UniqueKey();
      });
    }
  }

  Future<void> _openTaskDetails(String taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(taskId: taskId),
      ),
    );
    _refreshTasks();
  }

  void _onTasksList(count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isTasksListEmpty = count == 0;
        });
      }
    });
  }

  void _onFilterTags(List<String> tagIds) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagIds;
        _refreshTasks();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Tasks'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TaskAddButton(
              onTaskCreated: (taskId) => _openTaskDetails(taskId),
              buttonBackgroundColor: AppTheme.surface2,
              buttonColor: AppTheme.primaryColor,
              initialTagIds: _selectedTagIds,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TagSelectDropdown(
                isMultiSelect: true,
                onTagsSelected: _onFilterTags,
                buttonLabel:
                    (_selectedTagIds?.isEmpty ?? true) ? 'Filter by tags' : '${_selectedTagIds!.length} tags selected',
              ),
            ),

            if (_isTasksListEmpty) DoneOverlay(),

            TaskList(
              key: _tasksListKey,
              mediator: _mediator,
              filterByCompleted: false,
              filterByTags: _selectedTagIds,
              onClickTask: (task) => _openTaskDetails(task.id),
              onTaskCompleted: _refreshTasks,
              onList: _onTasksList,
            ),

            // Expansion panel for completed tasks
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
                        contentPadding: EdgeInsets.only(left: 8),
                        leading: const Icon(Icons.done_all),
                        title: const Text('Completed tasks'),
                      );
                    },
                    body: TaskList(
                      key: _completedTasksListKey,
                      mediator: _mediator,
                      filterByCompleted: true,
                      filterByTags: _selectedTagIds,
                      onClickTask: (task) => _openTaskDetails(task.id),
                      onTaskCompleted: _refreshTasks,
                    ),
                    backgroundColor: AppTheme.surface2,
                    canTapOnHeader: true),
              ],
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
            )
          ],
        ),
      ),
    );
  }
}
