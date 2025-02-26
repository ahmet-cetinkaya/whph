import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/components/done_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/calendar/constants/calendar_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class TodayPage extends StatefulWidget {
  static const String route = '/today';

  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  final _habitsListKey = GlobalKey<HabitsListState>();
  final _tasksListKey = GlobalKey<TaskListState>();
  final _timeChartKey = GlobalKey<TagTimeChartState>();

  bool _isHabitListEmpty = false;
  bool _isTaskListEmpty = false;
  List<String>? _selectedTagFilter;
  bool _isCheckedUpdate = false;

  @override
  void initState() {
    super.initState();

    if (!_isCheckedUpdate) {
      final setupService = container.resolve<ISetupService>();
      setupService.checkForUpdates(context);
      _isCheckedUpdate = true;
    }
  }

  void _refreshHabits() {
    _habitsListKey.currentState?.refresh();
  }

  void _refreshTasks() {
    _tasksListKey.currentState?.refresh();
  }

  void _refreshAllElements() {
    _habitsListKey.currentState?.refresh();
    _tasksListKey.currentState?.refresh();
    _timeChartKey.currentState?.refresh();
  }

  Future<void> _openTaskDetails(BuildContext context, String taskId) async {
    await Navigator.of(context).pushNamed(
      TaskDetailsPage.route,
      arguments: {'id': taskId},
    );
    _refreshTasks();
  }

  Future<void> _openHabitDetails(BuildContext context, String id) async {
    await Navigator.of(context).pushNamed(
      HabitDetailsPage.route,
      arguments: {'id': id},
    );
    _refreshHabits();
  }

  void _onHabitList(int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isHabitListEmpty = count == 0;
        });
      }
    });
  }

  void _onTaskList(int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isTaskListEmpty = count == 0;
        });
      }
    });
  }

  void _onTagFilterSelect(List<DropdownOption<String>> tagOptions) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedTagFilter = tagOptions.map((option) => option.value).toList();
          _refreshAllElements();
        });
      }
    });
  }

  Future<void> _openMarathonPage(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      MarathonPage.route,
      arguments: {'fullScreen': true},
    );
    _refreshAllElements();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(CalendarTranslationKeys.todayTitle),
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.timer),
          onPressed: () => _openMarathonPage(context),
          color: AppTheme.primaryColor,
          tooltip: _translationService.translate(TaskTranslationKeys.marathon),
        ),
        HelpMenu(
          titleKey: CalendarTranslationKeys.todayHelpTitle,
          markdownContentKey: CalendarTranslationKeys.todayHelpContent,
        ),
        const SizedBox(width: 8),
      ],
      builder: (context) => ListView(
        children: [
          // Filters
          TagSelectDropdown(
            isMultiSelect: true,
            icon: Icons.label,
            color: _selectedTagFilter?.isNotEmpty ?? false ? AppTheme.primaryColor : null,
            tooltip: _translationService.translate(SharedTranslationKeys.filterByTagsTooltip),
            onTagsSelected: _onTagFilterSelect,
          ),

          // Habits
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  _translationService.translate(CalendarTranslationKeys.habitsTitle),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _isHabitListEmpty
                  ? DoneOverlay()
                  : SizedBox(
                      height: 60,
                      width: MediaQuery.of(context).size.width,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: HabitsList(
                          key: _habitsListKey,
                          mediator: _mediator,
                          size: 5,
                          mini: true,
                          filterByTags: _selectedTagFilter,
                          onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                          onList: _onHabitList,
                        ),
                      )),
            ],
          ),

          // Tasks
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _translationService.translate(CalendarTranslationKeys.tasksTitle),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: TaskAddButton(
                        initialTagIds: _selectedTagFilter,
                        initialPlannedDate: DateTime.now(),
                        onTaskCreated: (_) {
                          setState(() {
                            _isTaskListEmpty = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _isTaskListEmpty
                  ? DoneOverlay()
                  : TaskList(
                      key: _tasksListKey,
                      mediator: _mediator,
                      translationService: _translationService,
                      filterByCompleted: false,
                      filterByTags: _selectedTagFilter,
                      filterByPlannedEndDate: DateTime.now().add(const Duration(days: 1)),
                      filterByDeadlineEndDate: DateTime.now().add(const Duration(days: 1)),
                      filterDateOr: true,
                      onClickTask: (task) => _openTaskDetails(context, task.id),
                      onList: _onTaskList,
                      onScheduleTask: (_, __) => _refreshTasks(),
                    ),
            ],
          ),

          // Times
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  _translationService.translate(CalendarTranslationKeys.timeTitle),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: TagTimeChart(
                    key: _timeChartKey,
                    filterByTags: _selectedTagFilter,
                    startDate: DateTime.now(),
                    endDate: DateTime.now().add(const Duration(days: 1)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
