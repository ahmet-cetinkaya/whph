import 'dart:developer' as developer;
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/presentation/ui/shared/services/filter_settings_manager.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/calendar/models/today_page_list_option_settings.dart';
import 'package:whph/core/application/features/widget/models/widget_data.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_list_option_settings.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_option_settings.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_defaults.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/presentation/ui/shared/services/background_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

/// Aggregates widget data (tasks and habits) for the home widget display.
class WidgetDataAggregator {
  final Mediator _mediator;
  final IContainer _container;
  final FilterSettingsManager _filterSettingsManager;
  final BackgroundTranslationService _translationService;

  WidgetDataAggregator({
    required Mediator mediator,
    required IContainer container,
    required FilterSettingsManager filterSettingsManager,
    BackgroundTranslationService? translationService,
  })  : _mediator = mediator,
        _container = container,
        _filterSettingsManager = filterSettingsManager,
        _translationService = translationService ?? BackgroundTranslationService();

  /// Fetches and aggregates widget data including tasks and habits.
  Future<WidgetData> getWidgetData() async {
    // Initialize translation service if not already initialized
    if (_translationService.translationCache == null) {
      await _translationService.initialize();
    }

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    // Load saved tag filter settings from TodayPage
    List<String>? selectedTagIds;
    bool showNoTagsFilter = false;

    // Load Task Sort Settings
    SortConfig<TaskSortFields> taskSortConfig = TaskDefaults.sorting.copyWith(enableGrouping: false);

    // Load Habit Sort Settings
    SortConfig<HabitSortFields> habitSortConfig = HabitDefaults.sorting;

    try {
      // 1. Load Main List Options (Tags)
      final savedMainSettings = await _filterSettingsManager.loadFilterSettings(
        settingKey: SettingKeys.todayPageListOptionsSettings,
      );

      if (savedMainSettings != null) {
        final filterSettings = TodayPageListOptionSettings.fromJson(savedMainSettings);
        selectedTagIds = filterSettings.selectedTagIds;
        showNoTagsFilter = filterSettings.showNoTagsFilter;
      }

      // 2. Load Task Settings
      // Note: The key in TodayPage is constructed with a suffix 'TODAY_PAGE'.
      // We manually reconstruct it here.
      final savedTaskSettings = await _filterSettingsManager.loadFilterSettings(
        settingKey: '${SettingKeys.tasksListOptionsSettings}_TODAY_PAGE',
      );

      if (savedTaskSettings != null) {
        final taskSettings = TaskListOptionSettings.fromJson(savedTaskSettings);
        taskSortConfig = taskSettings.sortConfig?.copyWith(enableGrouping: false) ?? taskSortConfig;
      }

      // 3. Load Habit Settings
      final savedHabitSettings = await _filterSettingsManager.loadFilterSettings(
        settingKey: '${SettingKeys.habitsListOptionsSettings}_TODAY_PAGE',
      );

      if (savedHabitSettings != null) {
        final habitSettings = HabitListOptionSettings.fromJson(savedHabitSettings);
        habitSortConfig = habitSettings.sortConfig ?? habitSortConfig;
      }
    } catch (e) {
      developer.log('Error loading settings for widget: $e', name: 'WidgetDataAggregator');
    }

    final tasks = await _getTasksData(startOfDay, endOfDay, selectedTagIds, showNoTagsFilter, taskSortConfig);
    final habits = await _getHabitsData(startOfDay, endOfDay, selectedTagIds, showNoTagsFilter, habitSortConfig);

    // Get translations
    final tasksTitle = _translationService.translateWithFallback(TaskTranslationKeys.tasksPageTitle, 'Tasks');
    final habitsTitle = _translationService.translateWithFallback(HabitTranslationKeys.pageTitle, 'Habits');
    final noPendingTasks = _translationService.translateWithFallback(TaskTranslationKeys.noTasks, 'No tasks');
    final noPendingHabits = _translationService.translateWithFallback(HabitTranslationKeys.noHabitsFound, 'No habits');
    final todayLabel = _translationService.translateWithFallback(SharedTranslationKeys.today, 'Today');

    developer.log('Widget translations: tasksTitle=$tasksTitle, habitsTitle=$habitsTitle, todayLabel=$todayLabel',
        name: 'WidgetDataAggregator');

    return WidgetData(
      tasks: tasks,
      habits: habits,
      lastUpdated: DateTime.now(),
      tasksTitle: tasksTitle,
      habitsTitle: habitsTitle,
      noPendingTasks: noPendingTasks,
      noPendingHabits: noPendingHabits,
      todayLabel: todayLabel,
    );
  }

  Future<List<WidgetTaskData>> _getTasksData(
    DateTime startOfDay,
    DateTime endOfDay,
    List<String>? selectedTagIds,
    bool showNoTagsFilter,
    SortConfig<TaskSortFields> sortConfig,
  ) async {
    final tasksResult = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
      GetListTasksQuery(
        pageIndex: 0,
        pageSize: 1000, // Significantly increased limit for widget
        filterByCompleted: false,
        filterByPlannedStartDate: DateTime(0),
        filterByPlannedEndDate: endOfDay,
        filterByDeadlineStartDate: DateTime(0),
        filterByDeadlineEndDate: endOfDay,
        filterDateOr: true,
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
        sortBy: sortConfig.orderOptions,
        sortByCustomSort: sortConfig.useCustomOrder,
      ),
    );

    return tasksResult.items
        .where((task) => !task.isCompleted)
        .map((task) => WidgetTaskData(
              id: task.id,
              title: task.title,
              isCompleted: task.isCompleted,
              plannedDate: task.plannedDate,
              deadlineDate: task.deadlineDate,
            ))
        .toList();
  }

  Future<List<WidgetHabitData>> _getHabitsData(
    DateTime startOfDay,
    DateTime endOfDay,
    List<String>? selectedTagIds,
    bool showNoTagsFilter,
    SortConfig<HabitSortFields> sortConfig,
  ) async {
    final habitsResult = await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(
      GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 1000, // Significantly increased limit for widget
        filterByArchived: false,
        excludeCompletedForDate: startOfDay,
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
        sortBy: sortConfig.orderOptions,
        sortByCustomSort: sortConfig.useCustomOrder,
      ),
    );

    final habitIds = habitsResult.items.map((habit) => habit.id).toList();
    final habitRecordsMap = await _getHabitRecordsMap(habitIds, startOfDay, endOfDay);

    List<WidgetHabitData> habits = [];

    for (final habit in habitsResult.items) {
      final todayRecords = habitRecordsMap[habit.id] ?? [];
      final currentCompletionCount = todayRecords.length;
      final hasGoal = habit.hasGoal;
      final dailyTarget = hasGoal ? (habit.dailyTarget ?? 1) : 1;
      final isDailyTargetMet = currentCompletionCount >= dailyTarget;
      final isCompletedToday = currentCompletionCount > 0;
      bool isPeriodGoalMet = false;

      final isDailyGoalMet = hasGoal ? (habit.periodDays > 1 ? isPeriodGoalMet : isDailyTargetMet) : isDailyTargetMet;

      DateTime? completedAt;
      if (isDailyGoalMet && todayRecords.isNotEmpty) {
        final lastRecord = todayRecords.last;
        completedAt = lastRecord.occurredAt;
      }

      const hideDelaySeconds = 3;
      final shouldHideCompletedHabit =
          isDailyGoalMet && completedAt != null && DateTime.now().difference(completedAt).inSeconds >= hideDelaySeconds;

      if (shouldHideCompletedHabit) {
        continue;
      }

      habits.add(WidgetHabitData(
        id: habit.id,
        name: habit.name,
        isCompletedToday: isCompletedToday,
        hasGoal: hasGoal,
        dailyTarget: dailyTarget,
        currentCompletionCount: currentCompletionCount,
        isDailyGoalMet: isDailyGoalMet,
        completedAt: completedAt,
        targetFrequency: habit.targetFrequency,
        periodDays: habit.periodDays,
        isPeriodGoalMet: isPeriodGoalMet,
      ));
    }

    return habits;
  }

  Future<Map<String, List<dynamic>>> _getHabitRecordsMap(
    List<String> habitIds,
    DateTime startOfDay,
    DateTime endOfDay,
  ) async {
    if (habitIds.isEmpty) {
      return {};
    }

    final todayRecordsWhereFilter = CustomWhereFilter(
      "habit_id IN (${habitIds.map((_) => '?').join(',')}) AND occurred_at >= ? AND occurred_at <= ? AND deleted_date IS NULL",
      [...habitIds, startOfDay, endOfDay],
    );

    final habitRecordRepository = _container.resolve<IHabitRecordRepository>();
    final todayRecordsResult = await habitRecordRepository.getList(
      0,
      habitIds.length * 20, // Increased multiplier to ensure we get all records if limit is high
      customWhereFilter: todayRecordsWhereFilter,
    );

    Map<String, List<dynamic>> habitRecordsMap = {};
    for (final record in todayRecordsResult.items) {
      habitRecordsMap.putIfAbsent(record.habitId, () => []).add(record);
    }

    return habitRecordsMap;
  }
}
