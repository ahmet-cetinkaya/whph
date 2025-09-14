import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_list_options.dart';
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/ui/features/calendar/components/today_page_list_options.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_floating_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_defaults.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_confetti_animation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/calendar/constants/calendar_translation_keys.dart';

class TodayPage extends StatefulWidget {
  static const String route = '/today';

  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _confettiAnimationService = container.resolve<IConfettiAnimationService>();
  final _themeService = container.resolve<IThemeService>();

  // Main list options state
  List<String>? _selectedTagFilter;
  bool _showNoTagsFilter = false;

  // Task list options state
  static const String _taskFilterOptionsSettingKeySuffix = 'TODAY_PAGE';
  bool _showCompletedTasks = false;
  bool _showSubTasks = false;
  String? _taskSearchQuery;
  SortConfig<TaskSortFields> _taskSortConfig = TaskDefaults.sorting;
  bool _taskForceOriginalLayout = false;

  // Habit list options state
  static const String _habitFilterOptionsSettingKeySuffix = 'TODAY_PAGE';
  SortConfig<HabitSortFields> _habitSortConfig = HabitDefaults.sorting;
  bool _habitForceOriginalLayout = false;

  // Time chart options state
  static const String _timeChartOptionsSettingKeySuffix = 'TODAY_PAGE';
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  // Loading states
  bool _mainListOptionSettingsLoaded = false;
  bool _habitListOptionSettingsLoaded = false;
  bool _taskListOptionSettingsLoaded = false;
  bool _timeChartOptionsLoaded = false;

  // Completion tracking for confetti
  bool _confettiShownToday = false;
  int _remainingHabits = 0;
  int _remainingTasks = 0;
  bool _habitsLoaded = false;
  bool _tasksLoaded = false;

  // Cached date calculations for performance
  late DateTime _todayStart;
  late DateTime _todayEnd;
  late DateTime _tomorrowStart;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away for marathon page

  @override
  void initState() {
    super.initState();
    // Reset confetti flag daily by checking if it's a new day
    _resetConfettiIfNewDay();
    // Initialize cached date calculations
    _updateDateCalculations();
  }

  void _resetConfettiIfNewDay() {
    // This could be enhanced to check actual date change
    // For now, reset when page initializes
    _confettiShownToday = false;
  }

  void _updateDateCalculations() {
    final now = DateTime.now();
    _todayStart = DateTime(now.year, now.month, now.day);
    _todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _tomorrowStart = DateTime(now.year, now.month, now.day + 1);
  }

  bool _isDateCacheStale() {
    final now = DateTime.now();
    final currentDayStart = DateTime(now.year, now.month, now.day);
    return !_todayStart.isAtSameMomentAs(currentDayStart);
  }

  void _onMainListOptionSettingsLoaded() {
    if (mounted) {
      setState(() {
        _mainListOptionSettingsLoaded = true;
      });
    }
  }

  void _onHabitListOptionSettingsLoaded() {
    if (mounted) {
      setState(() {
        _habitListOptionSettingsLoaded = true;
      });
    }
  }

  void _onTaskListOptionSettingsLoaded() {
    if (mounted) {
      setState(() {
        _taskListOptionSettingsLoaded = true;
      });
    }
  }

  void _onTimeChartOptionsLoaded() {
    if (mounted) {
      setState(() {
        _timeChartOptionsLoaded = true;
      });
    }
  }

  void _onSortConfigChange(SortConfig<TaskSortFields> newConfig) {
    if (mounted) {
      setState(() {
        _taskSortConfig = newConfig;
      });
    }
  }

  void _onTaskLayoutToggleChange(bool forceOriginalLayout) {
    if (mounted) {
      setState(() {
        _taskForceOriginalLayout = forceOriginalLayout;
      });
    }
  }

  void _onHabitSortConfigChange(SortConfig<HabitSortFields> newConfig) {
    if (mounted) {
      setState(() {
        _habitSortConfig = newConfig;
      });
    }
  }

  void _onHabitLayoutToggleChange(bool forceOriginalLayout) {
    if (mounted) {
      setState(() {
        _habitForceOriginalLayout = forceOriginalLayout;
      });
    }
  }

  void _onMainListOptionChange(tags, isNoneSelected) {
    setState(() {
      _selectedTagFilter = tags;
      _showNoTagsFilter = isNoneSelected;
    });
  }

  Future<void> _openTaskDetails(BuildContext context, String taskId) async {
    // Use ResponsiveDialogHelper to show task details
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TaskDetailsPage(
        taskId: taskId,
        hideSidebar: true,
      ),
      size: DialogSize.large,
    );
  }

  Future<void> _openHabitDetails(BuildContext context, String id) async {
    // Use ResponsiveDialogHelper to show habit details
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: HabitDetailsPage(
        habitId: id,
      ),
      size: DialogSize.large,
    );
  }

  Future<void> _openMarathonPage(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      MarathonPage.route,
      arguments: {'fullScreen': true},
    );
  }

  void _onHabitCompleted() {
    // When a habit is completed, check if this was the last remaining item
    _checkIfLastItemCompleted();
  }

  void _onTaskCompleted() {
    // When a task is completed, check if this was the last remaining item
    _checkIfLastItemCompleted();
  }

  void _onHabitsListed(int incompleteHabitCount) {
    _remainingHabits = incompleteHabitCount;
    _habitsLoaded = true;
  }

  void _onTasksListed(int incompleteTaskCount) {
    _remainingTasks = incompleteTaskCount;
    _tasksLoaded = true;
  }

  void _checkIfLastItemCompleted() {
    // Use a delay to allow the lists to refresh after completion
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _confettiShownToday) return;

      // Check if both lists are loaded and both have 0 remaining items
      if (_habitsLoaded && _tasksLoaded && _remainingHabits == 0 && _remainingTasks == 0) {
        _confettiShownToday = true;
        _confettiAnimationService.showConfettiFromBottomOfScreen(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Check if date cache is stale and update if needed
    if (_isDateCacheStale()) {
      _updateDateCalculations();
      // Reset confetti flag for new day
      _confettiShownToday = false;
    }

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(CalendarTranslationKeys.todayTitle),
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.timer),
          onPressed: () => _openMarathonPage(context),
          color: _themeService.primaryColor,
          tooltip: _translationService.translate(TaskTranslationKeys.marathon),
        ),
        KebabMenu(
          helpTitleKey: CalendarTranslationKeys.todayHelpTitle,
          helpMarkdownContentKey: CalendarTranslationKeys.todayHelpContent,
        ),
      ],
      // Add floating action button for mobile devices
      floatingActionButton: TaskAddFloatingButton(
        initialTagIds: _showNoTagsFilter ? [] : _selectedTagFilter,
        initialPlannedDate: DateTime.now(),
        initialTitle: _taskSearchQuery,
        initialCompleted: _showCompletedTasks,
      ),
      builder: (context) => ListView(
        children: [
          // Page list options
          TodayPageListOptions(
            onSettingsLoaded: _onMainListOptionSettingsLoaded,
            selectedTagIds: _selectedTagFilter,
            showNoTagsFilter: _showNoTagsFilter,
            onFilterChange: _onMainListOptionChange,
          ),

          if (_mainListOptionSettingsLoaded) ...[
            // Habits Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Habits title and options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Habits title
                      Text(
                        _translationService.translate(CalendarTranslationKeys.habitsTitle),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      // Habit filters
                      Expanded(
                        child: HabitListOptions(
                          settingKeyVariantSuffix: _habitFilterOptionsSettingKeySuffix,
                          onSettingsLoaded: _onHabitListOptionSettingsLoaded,
                          selectedTagIds: _selectedTagFilter,
                          showNoTagsFilter: _showNoTagsFilter,
                          sortConfig: _habitSortConfig,
                          forceOriginalLayout: _habitForceOriginalLayout,
                          onTagFilterChange: (List<DropdownOption<String>> tags, bool isNoneSelected) {
                            setState(() {
                              _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                              _showNoTagsFilter = isNoneSelected;
                            });
                          },
                          onSortChange: _onHabitSortConfigChange,
                          onLayoutToggleChange: _onHabitLayoutToggleChange,
                          showTagFilter: false,
                          showArchiveFilter: false,
                          showSortButton: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sizeSmall),

                  // Habits list
                  if (_habitListOptionSettingsLoaded)
                    HabitsList(
                      pageSize: 5,
                      mini: true,
                      filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                      filterNoTags: _showNoTagsFilter,
                      // Only show habits not completed today
                      excludeCompletedForDate: _todayStart,
                      sortConfig: _habitSortConfig,
                      enableReordering: _habitSortConfig.useCustomOrder,
                      forceOriginalLayout: _habitForceOriginalLayout,
                      onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                      onHabitCompleted: _onHabitCompleted,
                      onListing: _onHabitsListed,
                      onReorderComplete: () {
                        // Refresh the habits list to ensure correct order
                        setState(() {});
                      },
                      showDoneOverlayWhenEmpty: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sizeMedium),

            // Tasks Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tasks title and options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Task title
                      Text(
                        _translationService.translate(CalendarTranslationKeys.tasksTitle),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),

                      // Task filters and add button
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Task filters
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
                                child: TaskListOptions(
                                  settingKeyVariantSuffix: _taskFilterOptionsSettingKeySuffix,
                                  onSettingsLoaded: _onTaskListOptionSettingsLoaded,
                                  onSearchChange: (query) {
                                    setState(() {
                                      _taskSearchQuery = query;
                                    });
                                  },
                                  showCompletedTasks: _showCompletedTasks,
                                  onCompletedTasksToggle: (showCompleted) {
                                    setState(() {
                                      _showCompletedTasks = showCompleted;
                                    });
                                  },
                                  showSubTasks: _showSubTasks,
                                  onSubTasksToggle: (showSubTasks) {
                                    setState(() {
                                      _showSubTasks = showSubTasks;
                                    });
                                  },
                                  sortConfig: _taskSortConfig,
                                  forceOriginalLayout: _taskForceOriginalLayout,
                                  onSortChange: _onSortConfigChange,
                                  onLayoutToggleChange: _onTaskLayoutToggleChange,
                                  hasItems: true,
                                  showDateFilter: false,
                                  showTagFilter: false,
                                  showSubTasksToggle: true,
                                ),
                              ),
                            ),

                            // Add button
                            TaskAddButton(
                              initialTagIds: _showNoTagsFilter ? [] : _selectedTagFilter,
                              initialPlannedDate: DateTime.now(),
                              initialTitle: _taskSearchQuery,
                              initialCompleted: _showCompletedTasks,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Tasks list
                  if (_taskListOptionSettingsLoaded)
                    TaskList(
                      filterByCompleted: _showCompletedTasks,
                      filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                      filterNoTags: _showNoTagsFilter,
                      filterByPlannedStartDate: DateTime(0),
                      filterByPlannedEndDate: _todayEnd,
                      filterByDeadlineStartDate: DateTime(0),
                      filterByDeadlineEndDate: _todayEnd,
                      filterDateOr: true,
                      search: _taskSearchQuery,
                      includeSubTasks: _showSubTasks,
                      pageSize: 5,
                      onClickTask: (task) => _openTaskDetails(context, task.id),
                      onTaskCompleted: _onTaskCompleted,
                      onList: _onTasksListed,
                      enableReordering: _taskSortConfig.useCustomOrder,
                      forceOriginalLayout: _taskForceOriginalLayout,
                      showDoneOverlayWhenEmpty: true,
                      sortConfig: _taskSortConfig,
                    ),
                ],
              ),
            ),

            // Times Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Times title and options
                  Row(
                    children: [
                      // Times title
                      Text(
                        _translationService.translate(TagTranslationKeys.timeDistribution),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: AppTheme.sizeSmall),

                      // Time chart filters
                      TagTimeChartOptions(
                        settingKeyVariantSuffix: _timeChartOptionsSettingKeySuffix,
                        onSettingsLoaded: _onTimeChartOptionsLoaded,
                        selectedCategories: _selectedCategories,
                        onCategoriesChanged: (categories) {
                          setState(() {
                            _selectedCategories = categories;
                          });
                        },
                        showDateFilter: false,
                      ),
                    ],
                  ),

                  // Time chart
                  if (_timeChartOptionsLoaded)
                    Center(
                      child: TagTimeChart(
                        filterByTags: _selectedTagFilter,
                        startDate: _todayStart,
                        endDate: _tomorrowStart,
                        selectedCategories: _selectedCategories,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
