import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_list_options.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/calendar/components/today_page_list_options.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/features/calendar/constants/calendar_translation_keys.dart';

class TodayPage extends StatefulWidget {
  static const String route = '/today';

  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();

  // Main list options state
  List<String>? _selectedTagFilter;
  bool _showNoTagsFilter = false;

  // Task list options state
  static const String _taskFilterOptionsSettingKeySuffix = 'TODAY_PAGE';
  bool _showCompletedTasks = false;
  String? _taskSearchQuery;
  SortConfig<TaskSortFields> _taskSortConfig = TaskDefaults.sorting;

  // Habit list options state
  static const String _habitFilterOptionsSettingKeySuffix = 'TODAY_PAGE';

  // Time chart options state
  static const String _timeChartOptionsSettingKeySuffix = 'TODAY_PAGE';
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  // Loading states
  bool _mainListOptionSettingsLoaded = false;
  bool _habitListOptionSettingsLoaded = false;
  bool _taskListOptionSettingsLoaded = false;
  bool _timeChartOptionsLoaded = false;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away for marathon page

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
    );
  }

  Future<void> _openHabitDetails(BuildContext context, String id) async {
    // Use ResponsiveDialogHelper to show habit details
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: HabitDetailsPage(
        habitId: id,
      ),
    );
  }

  Future<void> _openMarathonPage(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      MarathonPage.route,
      arguments: {'fullScreen': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final now = DateTime.now();

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
          // Page list options
          TodayPageListOptions(
            onSettingsLoaded: _onMainListOptionSettingsLoaded,
            selectedTagIds: _selectedTagFilter,
            showNoTagsFilter: _showNoTagsFilter,
            onFilterChange: _onMainListOptionChange,
          ),
          const SizedBox(height: AppTheme.sizeMedium),

          if (_mainListOptionSettingsLoaded) ...[
            // Habits Section
            // Habits title and options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.sizeSmall,
                    bottom: AppTheme.sizeXSmall,
                  ),
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
                        child: HabitListOptions(
                          settingKeyVariantSuffix: _habitFilterOptionsSettingKeySuffix,
                          onSettingsLoaded: _onHabitListOptionSettingsLoaded,
                          selectedTagIds: _selectedTagFilter,
                          showNoTagsFilter: _showNoTagsFilter, // Add this to pass the None filter option state
                          onTagFilterChange: (List<DropdownOption<String>> tags, bool isNoneSelected) {
                            setState(() {
                              _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                              _showNoTagsFilter = isNoneSelected; // Update None filter state
                            });
                          },
                          showTagFilter: false,
                          showArchiveFilter: false,
                        ),
                      ),
                    ],
                  ),
                ),

                // Habits list
                if (_habitListOptionSettingsLoaded)
                  HabitsList(
                    size: 5,
                    mini: true,
                    filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                    filterNoTags: _showNoTagsFilter,
                    onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                    showDoneOverlayWhenEmpty: true,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Tasks Section
            // Tasks title and options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.sizeSmall,
                    bottom: AppTheme.sizeXSmall,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Task title
                      Text(
                        _translationService.translate(CalendarTranslationKeys.tasksTitle),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: AppTheme.sizeLarge),

                      // Task filters and add button
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Task filters
                            Expanded(
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
                                sortConfig: _taskSortConfig,
                                onSortChange: _onSortConfigChange,
                                hasItems: true,
                                showDateFilter: false,
                                showTagFilter: false,
                              ),
                            ),

                            // Add button
                            Padding(
                              padding: const EdgeInsets.only(right: AppTheme.sizeLarge),
                              child: TaskAddButton(
                                initialTagIds: _selectedTagFilter,
                                initialPlannedDate: DateTime.now(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tasks list
                if (_taskListOptionSettingsLoaded)
                  TaskList(
                    filterByCompleted: _showCompletedTasks,
                    filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                    filterNoTags: _showNoTagsFilter,
                    filterByPlannedEndDate: DateTime.now().add(const Duration(days: 1)),
                    filterByDeadlineEndDate: DateTime.now().add(const Duration(days: 1)),
                    filterDateOr: true,
                    search: _taskSearchQuery,
                    onClickTask: (task) => _openTaskDetails(context, task.id),
                    enableReordering: _taskSortConfig.useCustomOrder,
                    showDoneOverlayWhenEmpty: true,
                    sortConfig: _taskSortConfig,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Times Section
            // Times title and options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.sizeSmall,
                    bottom: AppTheme.sizeXSmall,
                  ),
                  child: Row(
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
                ),

                // Time chart
                if (_timeChartOptionsLoaded)
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.sizeSmall),
                    child: Center(
                      child: TagTimeChart(
                        filterByTags: _selectedTagFilter,
                        startDate: DateTime(now.year, now.month, now.day),
                        endDate: DateTime(now.year, now.month, now.day + 1),
                        selectedCategories: _selectedCategories,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
