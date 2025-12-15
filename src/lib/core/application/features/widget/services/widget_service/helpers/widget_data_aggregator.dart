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

/// Aggregates widget data (tasks and habits) for the home widget display.
class WidgetDataAggregator {
  final Mediator _mediator;
  final IContainer _container;
  final FilterSettingsManager _filterSettingsManager;

  WidgetDataAggregator({
    required Mediator mediator,
    required IContainer container,
    required FilterSettingsManager filterSettingsManager,
  })  : _mediator = mediator,
        _container = container,
        _filterSettingsManager = filterSettingsManager;

  /// Fetches and aggregates widget data including tasks and habits.
  Future<WidgetData> getWidgetData() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    // Load saved tag filter settings from TodayPage
    List<String>? selectedTagIds;
    bool showNoTagsFilter = false;

    try {
      final savedSettings = await _filterSettingsManager.loadFilterSettings(
        settingKey: SettingKeys.todayPageListOptionsSettings,
      );

      if (savedSettings != null) {
        final filterSettings = TodayPageListOptionSettings.fromJson(savedSettings);
        selectedTagIds = filterSettings.selectedTagIds;
        showNoTagsFilter = filterSettings.showNoTagsFilter;
      }
    } catch (e) {
      developer.log('Error loading tag filter settings for widget: $e', name: 'WidgetDataAggregator');
    }

    final tasks = await _getTasksData(startOfDay, endOfDay, selectedTagIds, showNoTagsFilter);
    final habits = await _getHabitsData(startOfDay, endOfDay, selectedTagIds, showNoTagsFilter);

    return WidgetData(
      tasks: tasks,
      habits: habits,
      lastUpdated: DateTime.now(),
    );
  }

  Future<List<WidgetTaskData>> _getTasksData(
    DateTime startOfDay,
    DateTime endOfDay,
    List<String>? selectedTagIds,
    bool showNoTagsFilter,
  ) async {
    final tasksResult = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
      GetListTasksQuery(
        pageIndex: 0,
        pageSize: 5,
        filterByCompleted: false,
        filterByPlannedStartDate: DateTime(0),
        filterByPlannedEndDate: endOfDay,
        filterByDeadlineStartDate: DateTime(0),
        filterByDeadlineEndDate: endOfDay,
        filterDateOr: true,
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
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
  ) async {
    final habitsResult = await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(
      GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 5,
        filterByArchived: false,
        excludeCompletedForDate: startOfDay,
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
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
      habitIds.length * 20,
      customWhereFilter: todayRecordsWhereFilter,
    );

    Map<String, List<dynamic>> habitRecordsMap = {};
    for (final record in todayRecordsResult.items) {
      habitRecordsMap.putIfAbsent(record.habitId, () => []).add(record);
    }

    return habitRecordsMap;
  }
}
