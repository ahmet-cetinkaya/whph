import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_list_options.dart';
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
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
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_confetti_animation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay/tour_overlay.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';
import 'package:whph/presentation/ui/features/calendar/constants/calendar_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/section_header.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';

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
  final _habitsService = container.resolve<HabitsService>();
  final _mediator = container.resolve<Mediator>();

  final Completer<void> _pageReadyCompleter = Completer<void>();
  int _loadedComponents = 0;
  static const int _totalComponentsToLoad = 6;

  // Tour keys
  final GlobalKey _mainListOptionsKey = GlobalKey();
  final GlobalKey _habitsSectionKey = GlobalKey();
  final GlobalKey _tasksSectionKey = GlobalKey();
  final GlobalKey _mainContentKey = GlobalKey();
  final GlobalKey _timeChartSectionKey = GlobalKey();
  final GlobalKey _marathonButtonKey = GlobalKey();
  final GlobalKey _addTaskButtonKey = GlobalKey();

  // Main list options state
  List<String>? _selectedTagFilter;
  bool _showNoTagsFilter = false;

  // Task list options state
  static const String _taskFilterOptionsSettingKeySuffix = 'TODAY_PAGE';
  bool _showCompletedTasks = false;
  bool _showSubTasks = false;
  String? _taskSearchQuery;
  SortConfig<TaskSortFields> _taskSortConfig = TaskDefaults.sorting.copyWith(enableGrouping: false);
  bool _taskForceOriginalLayout = false;

  // Habit list options state
  static const String _habitFilterOptionsSettingKeySuffix = 'TODAY_PAGE';
  SortConfig<HabitSortFields> _habitSortConfig = HabitDefaults.sorting;
  bool _habitForceOriginalLayout = false;
  HabitListStyle _habitListStyle = HabitDefaults.defaultListStyle;
  bool _isThreeStateEnabled = false;

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
    // Load habit settings
    _habitsService.onSettingsChanged.addListener(_loadHabitSettings);
    _loadHabitSettings();
    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
  }

  void _checkAndStartTour() async {
    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _pageReadyCompleter.future;
        if (mounted) {
          _startTour(isMultiPageTour: true);
        }
      });
      return;
    }

    final tourAlreadyDone = await TourNavigationService.isTourCompletedOrSkipped();
    if (tourAlreadyDone) return;
  }

  void _componentLoaded() {
    _loadedComponents++;
    if (_loadedComponents >= _totalComponentsToLoad && !_pageReadyCompleter.isCompleted) {
      _pageReadyCompleter.complete();
    }
  }

  Future<void> _loadHabitSettings() async {
    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.habitThreeStateEnabled),
      );
      if (setting != null && setting.getValue<bool>() == true) {
        if (mounted) {
          setState(() {
            _isThreeStateEnabled = true;
          });
        }
      }
    } catch (e, stackTrace) {
      DomainLogger.error("Failed to load habit settings in TodayPage", error: e, stackTrace: stackTrace);
    }
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
      _componentLoaded();
    }
  }

  void _onHabitListOptionSettingsLoaded() {
    if (mounted) {
      setState(() {
        _habitListOptionSettingsLoaded = true;
      });
      _componentLoaded();
    }
  }

  void _onTaskListOptionSettingsLoaded() {
    if (mounted) {
      setState(() {
        _taskListOptionSettingsLoaded = true;
      });
      _componentLoaded();
    }
  }

  void _onTimeChartOptionsLoaded() {
    if (mounted) {
      setState(() {
        _timeChartOptionsLoaded = true;
      });
      _componentLoaded();
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

  void _onHabitListStyleChange(HabitListStyle style) {
    if (mounted) {
      setState(() {
        _habitListStyle = style;
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

  void _onMainListOptionChange(List<String>? tags, bool isNoneSelected) {
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
      size: DialogSize.max,
    );
  }

  Future<void> _openHabitDetails(BuildContext context, String id) async {
    // Use ResponsiveDialogHelper to show habit details
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: HabitDetailsPage(
        habitId: id,
      ),
      size: DialogSize.max,
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

  Future<void> _onTaskCompleted(String taskId) async {
    try {
      await _mediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
        CompleteTaskCommand(id: taskId),
      );

      // When a task is completed, check if this was the last remaining item
      _checkIfLastItemCompleted();
    } catch (e, stackTrace) {
      DomainLogger.error(
        '[$TaskErrorIds.swipeGestureFailed] Failed to complete task from today page',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _onHabitsListed(int incompleteHabitCount) {
    if (mounted) {
      setState(() {
        _remainingHabits = incompleteHabitCount;
        _habitsLoaded = true;
      });
      _componentLoaded();
    }
  }

  void _onTasksListed(int incompleteTaskCount) {
    if (mounted) {
      setState(() {
        _remainingTasks = incompleteTaskCount;
        _tasksLoaded = true;
      });
      _componentLoaded();
    }
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

  /// Check if all page data has finished loading
  bool get _isPageFullyLoaded {
    return _mainListOptionSettingsLoaded &&
        _habitListOptionSettingsLoaded &&
        _taskListOptionSettingsLoaded &&
        _timeChartOptionsLoaded &&
        _habitsLoaded &&
        _tasksLoaded;
  }

  @override
  void dispose() {
    _habitsService.onSettingsChanged.removeListener(_loadHabitSettings);
    super.dispose();
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
          key: _marathonButtonKey,
          icon: const Icon(Icons.timer),
          onPressed: () => _openMarathonPage(context),
          color: _themeService.primaryColor,
          tooltip: _translationService.translate(TaskTranslationKeys.marathon),
        ),
        KebabMenu(
          helpTitleKey: CalendarTranslationKeys.todayHelpTitle,
          helpMarkdownContentKey: CalendarTranslationKeys.todayHelpContent,
          onStartTour: _startIndividualTour,
        ),
      ],
      // Add floating action button for mobile devices
      floatingActionButton: TaskAddFloatingButton(
        key: _addTaskButtonKey,
        initialTagIds: _showNoTagsFilter ? [] : _selectedTagFilter,
        initialPlannedDate: DateTime.now(),
        initialTitle: _taskSearchQuery,
        initialCompleted: _showCompletedTasks,
      ),
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: CustomScrollView(
          key: _mainContentKey,
          slivers: [
            // Page list options
            SliverToBoxAdapter(
              child: TodayPageListOptions(
                key: _mainListOptionsKey,
                onSettingsLoaded: _onMainListOptionSettingsLoaded,
                selectedTagIds: _selectedTagFilter,
                showNoTagsFilter: _showNoTagsFilter,
                onFilterChange: _onMainListOptionChange,
              ),
            ),

            if (_mainListOptionSettingsLoaded) ...[
              // Habits Header
              SliverToBoxAdapter(
                child: Column(
                  key: _habitsSectionKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: _translationService.translate(CalendarTranslationKeys.habitsTitle),
                      trailing: Expanded(
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
                          onHabitListStyleChange: _onHabitListStyleChange,
                          habitListStyle: _habitListStyle,
                          showViewStyleOption: true,
                          showOnlyTodayStyles: true,
                          showTagFilter: false,
                          showArchiveFilter: false,
                          showSortButton: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.sizeSmall),
                  ],
                ),
              ),

              // Habits List
              if (_habitListOptionSettingsLoaded)
                HabitsList(
                  key: ValueKey(
                      'habits_list_${_habitListStyle}_${_selectedTagFilter?.join(',') ?? 'noTags'}${_showNoTagsFilter ? 'none' : 'some'}_$_isThreeStateEnabled'),
                  isThreeStateEnabled: _isThreeStateEnabled,
                  pageSize: 5,
                  style: _habitListStyle,
                  filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                  filterNoTags: _showNoTagsFilter,
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
                  useSliver: true,
                ),

              SliverToBoxAdapter(child: const SizedBox(height: AppTheme.sizeMedium)),

              // Tasks Header
              SliverToBoxAdapter(
                child: Column(
                  key: _tasksSectionKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: _translationService.translate(CalendarTranslationKeys.tasksTitle),
                      trailing: Expanded(
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
                                  showGroupingOption: true,
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
                    ),
                  ],
                ),
              ),

              // Tasks List
              if (_taskListOptionSettingsLoaded)
                TaskList(
                  key: ValueKey(
                      'task_list_${_taskForceOriginalLayout}_${_selectedTagFilter?.join(',') ?? 'noTags'}${_showNoTagsFilter ? 'none' : 'some'}${_showCompletedTasks ? 'completed' : 'incomplete'}${_taskSearchQuery ?? 'no-search'}'),
                  filterByCompleted: _showCompletedTasks,
                  filterByTags: _showNoTagsFilter ? [] : _selectedTagFilter,
                  filterNoTags: _showNoTagsFilter,
                  filterByPlannedStartDate: _showCompletedTasks ? null : DateTime(0),
                  filterByPlannedEndDate: _showCompletedTasks ? null : _todayEnd,
                  filterByDeadlineStartDate: _showCompletedTasks ? null : DateTime(0),
                  filterByDeadlineEndDate: _showCompletedTasks ? null : _todayEnd,
                  filterDateOr: true,
                  filterByCompletedStartDate: _showCompletedTasks ? _todayStart : null,
                  filterByCompletedEndDate: _showCompletedTasks ? _todayEnd : null,
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
                  useSliver: true,
                ),

              SliverToBoxAdapter(child: const SizedBox(height: AppTheme.size2Small)),

              // Time Chart
              SliverToBoxAdapter(
                child: Column(
                  key: _timeChartSectionKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: _translationService.translate(TagTranslationKeys.timeDistribution),
                      trailing: Expanded(
                        child: TagTimeChartOptions(
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
                      ),
                    ),
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
      ),
    );
  }

  void _startTour({bool isMultiPageTour = false}) {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(CalendarTranslationKeys.tourWelcomeTitle),
        description: _translationService.translate(CalendarTranslationKeys.tourWelcomeDescription),
        icon: Icons.today,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. General list options (tag filter)
      TourStep(
        title: _translationService.translate(CalendarTranslationKeys.tourTagFilterTitle),
        description: _translationService.translate(CalendarTranslationKeys.tourTagFilterDescription),
        targetKey: _mainListOptionsKey,
        position: TourPosition.bottom,
      ),
      // 3. Habits section introduce
      TourStep(
        title: _translationService.translate(CalendarTranslationKeys.tourHabitsTitle),
        description: _translationService.translate(CalendarTranslationKeys.tourHabitsDescription),
        targetKey: _habitsSectionKey,
        position: TourPosition.bottom,
      ),
      // 4. Tasks section introduce
      TourStep(
        title: _translationService.translate(CalendarTranslationKeys.tourTasksTitle),
        description: _translationService.translate(CalendarTranslationKeys.tourTasksDescription),
        targetKey: _tasksSectionKey,
        position: TourPosition.bottom,
      ),
      // 5. Time distribution introduce
      TourStep(
        title: _translationService.translate(CalendarTranslationKeys.tourTimeDistributionTitle),
        description: _translationService.translate(CalendarTranslationKeys.tourTimeDistributionDescription),
        targetKey: _timeChartSectionKey,
        position: TourPosition.top,
      ),
      // 6. Marathon page button introduce
      TourStep(
        title: _translationService.translate(CalendarTranslationKeys.tourMarathonModeTitle),
        description: _translationService.translate(CalendarTranslationKeys.tourMarathonModeDescription),
        targetKey: _marathonButtonKey,
        position: TourPosition.bottom,
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (overlayContext) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(overlayContext).pop();
          if (isMultiPageTour) {
            TourNavigationService.onPageTourCompleted(overlayContext);
          }
        },
        onSkip: () async {
          if (isMultiPageTour) {
            await TourNavigationService.skipMultiPageTour();
          }
          if (overlayContext.mounted) Navigator.of(overlayContext).pop();
        },
        onBack: isMultiPageTour && TourNavigationService.canNavigateBack
            ? () => TourNavigationService.navigateBackInTour(overlayContext)
            : null,
        showBackButton: isMultiPageTour,
        isFinalPageOfTour: !isMultiPageTour || TourNavigationService.currentTourIndex == 5, // Notes page is final
        translationService: _translationService,
      ),
    );
  }

  void _startIndividualTour() {
    _startTour(isMultiPageTour: false);
  }
}
