import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/done_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TasksPage extends StatefulWidget {
  static const String route = '/tasks';

  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  List<String>? _selectedTagIds;

  Key _tasksListKey = UniqueKey();
  bool _isTasksListEmpty = false;

  bool _isCompletedTasksExpanded = false;
  Key _completedTasksListKey = UniqueKey();

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  String? _searchQuery;

  void _refreshAllTasks() {
    if (mounted) {
      setState(() {
        _isTasksListEmpty = false;
        _tasksListKey = UniqueKey();
        _completedTasksListKey = UniqueKey();
      });
    }
  }

  Future<void> _openTaskDetails(String taskId) async {
    await Navigator.of(context).pushNamed(
      TaskDetailsPage.route,
      arguments: {'id': taskId},
    );
    _refreshAllTasks();
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

  void _onFilterTags(List<DropdownOption<String>> tagOptions) {
    if (mounted) {
      setState(() {
        _selectedTagIds = tagOptions.map((option) => option.value).toList();
        _refreshAllTasks();
      });
    }
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (mounted) {
      setState(() {
        _filterStartDate = start;
        _filterEndDate = end;
        _refreshAllTasks();
      });
    }
  }

  void _onSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _refreshAllTasks();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TaskTranslationKeys.tasksPageTitle),
      appBarActions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskAddButton(
              onTaskCreated: (_) => _refreshAllTasks(),
              buttonColor: AppTheme.primaryColor,
              initialTagIds: _selectedTagIds,
            ),
            HelpMenu(
              titleKey: TaskTranslationKeys.tasksHelpTitle,
              markdownContentKey: TaskTranslationKeys.tasksHelpContent,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
      builder: (context) => ListView(
        children: [
          TaskFilters(
            selectedTagIds: _selectedTagIds,
            selectedStartDate: _filterStartDate,
            selectedEndDate: _filterEndDate,
            onTagFilterChange: _onFilterTags,
            onDateFilterChange: _onDateFilterChange,
            onSearchChange: _onSearchChange,
          ),
          const SizedBox(height: 8),
          if (_isTasksListEmpty)
            const Center(child: DoneOverlay())
          else
            TaskList(
              key: _tasksListKey,
              mediator: _mediator,
              translationService: _translationService,
              filterByCompleted: false,
              filterByTags: _selectedTagIds,
              filterByPlannedStartDate: _filterStartDate,
              filterByPlannedEndDate: _filterEndDate,
              search: _searchQuery,
              onClickTask: (task) => _openTaskDetails(task.id),
              onTaskCompleted: _refreshAllTasks,
              onList: _onTasksList,
              onScheduleTask: (_, __) => _refreshAllTasks(),
            ),
          const SizedBox(height: 8),
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
                      title: Text(_translationService.translate(TaskTranslationKeys.completedTasksTitle)),
                    );
                  },
                  body: TaskList(
                    key: _completedTasksListKey,
                    mediator: _mediator,
                    translationService: _translationService,
                    filterByCompleted: true,
                    filterByTags: _selectedTagIds,
                    search: _searchQuery,
                    onClickTask: (task) => _openTaskDetails(task.id),
                    onTaskCompleted: _refreshAllTasks,
                    onScheduleTask: (_, __) => _refreshAllTasks(),
                  ),
                  backgroundColor: Colors.transparent,
                  canTapOnHeader: true),
            ],
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
