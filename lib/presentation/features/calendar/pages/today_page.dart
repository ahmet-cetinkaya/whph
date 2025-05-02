import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_filters.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/components/done_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/calendar/constants/calendar_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tasks/components/task_filters.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class TodayPage extends StatefulWidget {
  static const String route = '/today';

  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  final _habitsListKey = GlobalKey<HabitsListState>();
  final _tasksListKey = GlobalKey<TaskListState>();
  final _timeChartKey = GlobalKey<TagTimeChartState>();

  bool _isHabitListEmpty = false;
  bool _isTaskListEmpty = false;
  List<String>? _selectedTagFilter;
  bool _showNoTagsFilter = false; // Added to track "None" filter selection
  bool _isCheckedUpdate = false;
  bool _showCompletedTasks = false;
  String? _searchQuery;
  bool _isRefreshing = false;

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
    if (mounted) {
      setState(() {
        _isTaskListEmpty = false;
      });
      _tasksListKey.currentState?.refresh(showLoading: false);
    }
  }

  void _refreshAllElements() {
    if (_isRefreshing) return;
    _isRefreshing = true;

    // Reset empty state flags to ensure components are shown while loading
    if (mounted) {
      setState(() {
        _isHabitListEmpty = false;
        _isTaskListEmpty = false;
      });
    }

    // Get references to component states
    final habitsListState = _habitsListKey.currentState;
    final tasksListState = _tasksListKey.currentState;
    final timeChartState = _timeChartKey.currentState;

    // Run all refreshes in parallel for better performance
    Future.wait([
      // Force refresh for habits list
      habitsListState != null ? habitsListState.refresh() : Future.value(),

      // Force refresh for tasks list
      tasksListState != null ? tasksListState.refresh(showLoading: true) : Future.value(),

      // Force refresh for time chart
      timeChartState != null ? timeChartState.refresh() : Future.value(),
    ]).then((_) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
      // Don't show error - component-specific error handling is preferred
    });
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
    final isEmpty = count == 0;
    // Only update state if it's actually changing to avoid infinite loops
    if (_isHabitListEmpty != isEmpty && mounted) {
      setState(() {
        _isHabitListEmpty = isEmpty;
      });
    }
  }

  void _onTaskList(int count) {
    final isEmpty = count == 0;
    // Only update state if it's actually changing to avoid infinite loops
    if (_isTaskListEmpty != isEmpty && mounted) {
      setState(() {
        _isTaskListEmpty = isEmpty;
      });
    }
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
    super.build(context);
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
          // Shared Tag Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TagSelectDropdown(
                    isMultiSelect: true,
                    onTagsSelected: (tags, isNoneSelected) {
                      if (_isRefreshing) return;
                      setState(() {
                        _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                        _showNoTagsFilter = isNoneSelected; // Update "None" filter state
                        _isHabitListEmpty = false;
                        _isTaskListEmpty = false;
                      });
                      _refreshAllElements();
                    },
                    icon: Icons.label,
                    color: (_selectedTagFilter?.isNotEmpty ?? false) || _showNoTagsFilter
                        ? AppTheme.primaryColor
                        : Colors.grey,
                    tooltip: _translationService.translate(SharedTranslationKeys.filterByTagsTooltip),
                    showLength: true,
                    showNoneOption: true, // Enable "None" option
                    initialSelectedTags: _selectedTagFilter != null
                        ? _selectedTagFilter!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                        : [],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Habits
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Habits title
                    Text(
                      _translationService.translate(CalendarTranslationKeys.habitsTitle),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 24),

                    // Habit filters
                    Expanded(
                      child: HabitFilters(
                        selectedTagIds: _selectedTagFilter,
                        showNoTagsFilter: _showNoTagsFilter, // Add this to pass the None filter option state
                        onTagFilterChange: (List<DropdownOption<String>> tags, bool isNoneSelected) {
                          setState(() {
                            _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                            _showNoTagsFilter = isNoneSelected; // Update None filter state
                            _isHabitListEmpty = false;
                          });
                          _refreshAllElements();
                        },
                        showTagFilter: false,
                      ),
                    ),
                  ],
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
                          filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                          filterNoTags: _showNoTagsFilter,
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
                    // Task title
                    Text(
                      _translationService.translate(CalendarTranslationKeys.tasksTitle),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 24), // Add more space between title and filters

                    // Task filters and add button
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Task filters
                          Expanded(
                            child: TaskFilters(
                              selectedTagIds: _selectedTagFilter,
                              showNoTagsFilter: _showNoTagsFilter, // Add this to pass the None filter state
                              onTagFilterChange: (tags, isNoneSelected) {
                                setState(() {
                                  _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                                  _showNoTagsFilter = isNoneSelected; // Update None filter state
                                  _isTaskListEmpty = false;
                                });
                                _refreshAllElements();
                              },
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
                              hasItems: true,
                              showDateFilter: false,
                              showTagFilter: false,
                            ),
                          ),

                          // Add button
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: TaskAddButton(
                              initialTagIds: _selectedTagFilter,
                              initialPlannedDate: DateTime.now(),
                              onTaskCreated: (_, __) => _refreshTasks(),
                            ),
                          ),
                        ],
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
                      filterByCompleted: _showCompletedTasks,
                      filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                      filterNoTags: _showNoTagsFilter,
                      filterByPlannedEndDate: DateTime.now().add(const Duration(days: 1)),
                      filterByDeadlineEndDate: DateTime.now().add(const Duration(days: 1)),
                      filterDateOr: true,
                      sortByPlannedDate: SortDirection.desc,
                      search: _searchQuery,
                      onClickTask: (task) => _openTaskDetails(context, task.id),
                      onList: _onTaskList,
                      onScheduleTask: (_, __) => _refreshTasks(),
                      enableReordering: true,
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

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away
}
