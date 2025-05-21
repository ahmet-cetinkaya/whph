import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_filters.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/time_chart_filters.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/tasks/pages/marathon_page.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/calendar/constants/calendar_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tasks/components/task_list_options.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class TodayPage extends StatefulWidget {
  static const String route = '/today';

  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();

  List<String>? _selectedTagFilter;
  bool _showNoTagsFilter = false;
  bool _isCheckedUpdate = false;
  bool _showCompletedTasks = false;
  String? _searchQuery;
  bool _hasHabits = false;
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  @override
  void initState() {
    super.initState();

    if (!_isCheckedUpdate) {
      final setupService = container.resolve<ISetupService>();
      setupService.checkForUpdates(context);
      _isCheckedUpdate = true;
    }
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
          // Shared Tag Filter
          Row(
            children: [
              Expanded(
                child: TagSelectDropdown(
                  isMultiSelect: true,
                  onTagsSelected: (tags, isNoneSelected) {
                    setState(() {
                      _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                      _showNoTagsFilter = isNoneSelected; // Update "None" filter state
                    });
                  },
                  icon: TagUiConstants.tagIcon,
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

          // Habits
          const SizedBox(height: AppTheme.sizeLarge),
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
                      child: HabitFilters(
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
              _hasHabits
                  ? SizedBox(
                      height: 90,
                      width: MediaQuery.of(context).size.width,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: HabitsList(
                          size: 5,
                          mini: true,
                          filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                          filterNoTags: _showNoTagsFilter,
                          onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                          showDoneOverlayWhenEmpty: true,
                          onListing: (count) {
                            if (mounted) {
                              setState(() {
                                _hasHabits = count > 0;
                              });
                            }
                          },
                        ),
                      ))
                  : HabitsList(
                      size: 5,
                      mini: true,
                      filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                      filterNoTags: _showNoTagsFilter,
                      onClickHabit: (habit) => _openHabitDetails(context, habit.id),
                      showDoneOverlayWhenEmpty: true,
                      onListing: (count) {
                        if (mounted) {
                          setState(() {
                            _hasHabits = count > 0;
                          });
                        }
                      },
                    ),
            ],
          ),

          // Tasks
          const SizedBox(height: AppTheme.sizeLarge),
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
                              selectedTagIds: _selectedTagFilter,
                              showNoTagsFilter: _showNoTagsFilter, // Add this to pass the None filter state
                              onTagFilterChange: (tags, isNoneSelected) {
                                setState(() {
                                  _selectedTagFilter = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                                  _showNoTagsFilter = isNoneSelected; // Update None filter state
                                });
                              },
                              onSearchChange: (query) {
                                setState(() {
                                  _searchQuery = query;
                                });
                              },
                              showCompletedTasks: _showCompletedTasks,
                              onCompletedTasksToggle: (showCompleted) {
                                setState(() {
                                  _showCompletedTasks = showCompleted;
                                });
                              },
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
              TaskList(
                filterByCompleted: _showCompletedTasks,
                filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                filterNoTags: _showNoTagsFilter,
                filterByPlannedEndDate: DateTime.now().add(const Duration(days: 1)),
                filterByDeadlineEndDate: DateTime.now().add(const Duration(days: 1)),
                filterDateOr: true,
                search: _searchQuery,
                onClickTask: (task) => _openTaskDetails(context, task.id),
                enableReordering: true,
                showDoneOverlayWhenEmpty: true,
                sortByPlannedDate: SortDirection.desc,
              ),
            ],
          ),

          // Times
          const SizedBox(height: AppTheme.sizeLarge),
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
                    TimeChartFilters(
                      selectedCategories: _selectedCategories,
                      onCategoriesChanged: (categories) {
                        setState(() {
                          _selectedCategories = categories;
                        });
                      },
                      showDateFilter: false,
                      showCategoryFilter: true,
                    ),
                  ],
                ),
              ),

              // Time chart
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
      ),
    );
  }

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away
}
