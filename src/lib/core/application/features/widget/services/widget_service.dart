import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/widgets.dart' hide Container;
import 'package:home_widget/home_widget.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/core/shared/utils/logger.dart';
import '../models/widget_data.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/presentation/ui/shared/services/filter_settings_manager.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/calendar/models/today_page_list_option_settings.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_sounds.dart';

/// Background callback function for HomeWidget interactive widgets
/// This function is called when a widget is clicked and performs the actual completion logic
@pragma("vm:entry-point")
FutureOr<void> widgetBackgroundCallback(Uri? data) async {
  if (data == null) {
    Logger.error('Widget background callback received null URI');
    return;
  }

  try {
    // Extract action and itemId from URI
    final action = data.queryParameters['action'];
    final itemId = data.queryParameters['itemId'];

    if (action != null && itemId != null) {
      // Initialize Flutter binding for background isolate
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize the container for background processing
      IContainer container;
      try {
        // Try to initialize a new container instance for the background isolate
        // Add a timeout to prevent hanging in test environments
        container = await AppBootstrapService.initializeApp().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Container initialization timed out', const Duration(seconds: 10));
          },
        );
      } catch (e) {
        // If container initialization fails (e.g., services already registered, timeout, etc.),
        // try to use the existing container instance
        Logger.warning('Container initialization failed, using existing instance: $e');
        try {
          final containerInstance = Container().instance;
          container = containerInstance;
        } catch (containerError) {
          Logger.error('Failed to get existing container instance: $containerError');
          return;
        }
      }

      // Verify that the Mediator is registered before trying to resolve it
      Mediator mediator;
      try {
        mediator = container.resolve<Mediator>();
      } catch (e) {
        Logger.error('Failed to resolve Mediator from container: $e');
        // If we can't resolve the Mediator, we can't proceed with the action
        // This is expected in test environments where the full DI setup is not available
        return;
      }

      switch (action) {
        case 'toggle_task':
          await _backgroundToggleTask(mediator, container, itemId);
          break;
        case 'toggle_habit':
          await _backgroundToggleHabit(mediator, container, itemId);
          break;
        default:
          Logger.error('Unknown action in background callback: $action');
          return;
      }

      // Update the widget immediately after completion
      try {
        final widgetService = container.resolve<WidgetService>();
        // Update widget to show immediate completion state
        await widgetService.updateWidget();

        // Update again to refresh and hide completed habits if needed
        // This ensures the widget shows current state without relying on arbitrary delays
        await widgetService.updateWidget();
      } catch (e) {
        Logger.error('Failed to resolve WidgetService or update widget: $e');
        // This is expected in test environments where the full DI setup is not available
      }
    } else {
      Logger.error('Missing action or itemId in background callback');
    }
  } catch (e, stackTrace) {
    Logger.error('Error in widget background callback: $e');
    Logger.debug('Stack trace: $stackTrace');
  }
}

/// Background task toggle function
Future<void> _backgroundToggleTask(Mediator mediator, IContainer container, String taskId) async {
  try {
    final taskResult = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );

    final newCompletedAt = taskResult.completedAt == null ? DateTime.now().toUtc() : null;
    await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
      SaveTaskCommand(
        id: taskResult.id,
        title: taskResult.title,
        description: taskResult.description,
        priority: taskResult.priority,
        plannedDate: taskResult.plannedDate,
        deadlineDate: taskResult.deadlineDate,
        estimatedTime: taskResult.estimatedTime,
        completedAt: newCompletedAt,
        parentTaskId: taskResult.parentTaskId,
        order: taskResult.order,
        plannedDateReminderTime: taskResult.plannedDateReminderTime,
        deadlineDateReminderTime: taskResult.deadlineDateReminderTime,
        recurrenceType: taskResult.recurrenceType,
        recurrenceInterval: taskResult.recurrenceInterval,
        recurrenceStartDate: taskResult.recurrenceStartDate,
        recurrenceEndDate: taskResult.recurrenceEndDate,
        recurrenceCount: taskResult.recurrenceCount,
      ),
    );

    // Play completion sound if task was completed
    if (newCompletedAt != null) {
      try {
        final soundManagerService = container.resolve<ISoundManagerService>();
        soundManagerService.playTaskCompletion();
      } catch (e) {
        Logger.warning('Error playing completion sound: $e');
        // Don't rethrow - sound failure shouldn't break the task completion
        // This is expected in test environments where the full DI setup is not available
      }
    }
  } catch (e, stackTrace) {
    Logger.error('Error toggling task $taskId: $e');
    Logger.debug('Stack trace: $stackTrace');
    rethrow;
  }
}

/// Background habit toggle function with smart behavior for multiple occurrences
Future<void> _backgroundToggleHabit(Mediator mediator, IContainer container, String habitId) async {
  try {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get habit details to check for custom goals
    final habit = await mediator.send<GetHabitQuery, GetHabitQueryResponse>(
      GetHabitQuery(id: habitId),
    );
    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

    // Get today's records with sufficient page size for multiple occurrences
    final recordsResult = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
      GetListHabitRecordsQuery(
        pageIndex: 0,
        pageSize: 20, // Allow for multiple daily occurrences
        habitId: habitId,
        startDate: startOfDay,
        endDate: endOfDay,
      ),
    );

    final todayCount = recordsResult.items.length;

    if (hasCustomGoals && dailyTarget > 1) {
      // Smart behavior for multi-occurrence habits with custom goals
      if (todayCount < dailyTarget) {
        // Add new record (increment)
        await mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
          ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
        );

        // Play completion sound
        try {
          final soundManagerService = container.resolve<ISoundManagerService>();
          soundManagerService.playHabitCompletion();
        } catch (e) {
          Logger.warning('Error playing completion sound: $e');
        }
      } else {
        // Reset to 0 (remove all records for today)
        for (final record in recordsResult.items) {
          await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
            DeleteHabitRecordCommand(id: record.id),
          );
        }
      }
    } else {
      // Traditional behavior for simple habits or habits without custom goals
      // Remove ALL records for today (handles case where multiple records exist from when custom goals were enabled)
      if (todayCount > 0) {
        for (final record in recordsResult.items) {
          await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
            DeleteHabitRecordCommand(id: record.id),
          );
        }
      } else {
        // Add new record
        await mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
          ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
        );

        // Play completion sound
        try {
          final soundManagerService = container.resolve<ISoundManagerService>();
          soundManagerService.playHabitCompletion();
        } catch (e) {
          Logger.warning('Error playing completion sound: $e');
        }
      }
    }
  } catch (e, stackTrace) {
    Logger.error('Error toggling habit $habitId: $e');
    Logger.debug('Stack trace: $stackTrace');
    rethrow;
  }
}

class WidgetService {
  static const String _tasksWidgetName = 'WhphTasksWidgetProvider';
  static const String _habitsWidgetName = 'WhphHabitsWidgetProvider';
  static const String _dataKey = 'widget_data';

  final Mediator _mediator;
  final IContainer _container;
  late final FilterSettingsManager _filterSettingsManager;

  WidgetService({required Mediator mediator, required IContainer container})
      : _mediator = mediator,
        _container = container {
    _filterSettingsManager = FilterSettingsManager(_mediator);
  }

  /// Update both tasks and habits widgets
  Future<void> updateWidget() async {
    await Future.wait([
      updateTasksWidget(),
      updateHabitsWidget(),
    ]);
  }

  /// Update only the tasks widget
  Future<void> updateTasksWidget() async {
    try {
      final widgetData = await _getWidgetData();
      final jsonData = jsonEncode(widgetData.toJson());

      await HomeWidget.saveWidgetData(_dataKey, jsonData);
      await HomeWidget.updateWidget(
        name: _tasksWidgetName,
        androidName: _tasksWidgetName,
      );
    } catch (e) {
      Logger.error('Error updating tasks widget: $e');
    }
  }

  /// Update only the habits widget
  Future<void> updateHabitsWidget() async {
    try {
      final widgetData = await _getWidgetData();
      final jsonData = jsonEncode(widgetData.toJson());

      await HomeWidget.saveWidgetData(_dataKey, jsonData);
      await HomeWidget.updateWidget(
        name: _habitsWidgetName,
        androidName: _habitsWidgetName,
      );
    } catch (e) {
      Logger.error('Error updating habits widget: $e');
    }
  }

  Future<WidgetData> _getWidgetData() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    // Load saved tag filter settings from TodayPage to apply the same filtering
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
      developer.log('Error loading tag filter settings for widget: $e', name: 'WidgetService');
      // Continue with no tag filtering if settings can't be loaded
    }

    // Get today's incomplete tasks using the same filtering logic as TodayPage
    final tasksResult = await _mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(
      GetListTasksQuery(
        pageIndex: 0,
        pageSize: 5, // Match TodayPage's page size
        // Filter for incomplete tasks only
        filterByCompleted: false,
        // Date filtering: tasks with planned date OR deadline date within today
        filterByPlannedStartDate: DateTime(0), // From beginning of time
        filterByPlannedEndDate: endOfDay, // End of today
        filterByDeadlineStartDate: DateTime(0), // From beginning of time
        filterByDeadlineEndDate: endOfDay, // End of today
        filterDateOr: true, // Match if EITHER planned OR deadline date is within range
        // Apply tag filtering from TodayPage settings
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
      ),
    );

    // Only include incomplete tasks
    final tasks = tasksResult.items
        .where((task) => !task.isCompleted)
        .map((task) => WidgetTaskData(
              id: task.id,
              title: task.title,
              isCompleted: task.isCompleted,
              plannedDate: task.plannedDate,
              deadlineDate: task.deadlineDate,
            ))
        .toList();

    // Get habits using the same filtering logic as TodayPage
    final habitsResult = await _mediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(
      GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 5, // Match TodayPage's page size
        filterByArchived: false,
        // Use the same period-aware exclusion logic as TodayPage
        excludeCompletedForDate: startOfDay,
        // Apply tag filtering from TodayPage settings
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
      ),
    );

    // Convert habits to widget data with completion progress
    List<WidgetHabitData> habits = [];

    // Get all habit records for today for all habits in a single query to avoid N+1 problem
    final habitIds = habitsResult.items.map((habit) => habit.id).toList();
    List todayRecordsList = [];
    Map<String, List> habitRecordsMap = {};

    if (habitIds.isNotEmpty) {
      final todayRecordsWhereFilter = CustomWhereFilter(
        "habit_id IN (${habitIds.map((_) => '?').join(',')}) AND occurred_at >= ? AND occurred_at <= ? AND deleted_date IS NULL",
        [...habitIds, startOfDay, endOfDay],
      );

      // Resolve the habit record repository directly to use getList with customWhereFilter
      final habitRecordRepository = _container.resolve<IHabitRecordRepository>();
      final todayRecordsResult = await habitRecordRepository.getList(
        0,
        habitIds.length * 20, // Enough for multiple daily occurrences per habit
        customWhereFilter: todayRecordsWhereFilter,
      );

      todayRecordsList = todayRecordsResult.items;

      // Group records by habit ID
      for (final record in todayRecordsList) {
        habitRecordsMap.putIfAbsent(record.habitId, () => []).add(record);
      }
    }

    // Since we're using excludeCompletedForDate, period-satisfied habits are already filtered out
    // We don't need complex period goal calculations anymore

    // Process each habit with pre-fetched records
    for (final habit in habitsResult.items) {
      // Get today's records for this habit
      final todayRecords = habitRecordsMap[habit.id] ?? [];
      final currentCompletionCount = todayRecords.length;
      final hasGoal = habit.hasGoal;
      final dailyTarget = hasGoal ? (habit.dailyTarget ?? 1) : 1;
      final isDailyTargetMet = currentCompletionCount >= dailyTarget;
      final isCompletedToday = currentCompletionCount > 0;

      // Since we use excludeCompletedForDate, period-satisfied habits are already filtered out
      // Any habit that appears here either has no period goal or the period goal is not yet met
      bool isPeriodGoalMet = false;

      // Determine final goal met status
      final isDailyGoalMet = hasGoal ? (habit.periodDays > 1 ? isPeriodGoalMet : isDailyTargetMet) : isDailyTargetMet;

      // Determine completion timestamp for completed habits
      DateTime? completedAt;
      if (isDailyGoalMet && todayRecords.isNotEmpty) {
        // Use the last record's timestamp as completion time
        final lastRecord = todayRecords.last;
        completedAt = lastRecord.occurredAt;
      }

      // Hide completed habits after 3 seconds
      const hideDelaySeconds = 3;
      final shouldHideCompletedHabit =
          isDailyGoalMet && completedAt != null && DateTime.now().difference(completedAt).inSeconds >= hideDelaySeconds;

      if (shouldHideCompletedHabit) {
        continue; // Skip this habit - it's completed and delay has passed
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

    return WidgetData(
      tasks: tasks,
      habits: habits,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> handleWidgetClick(String action, String itemId) async {
    try {
      developer.log('=== HANDLE WIDGET CLICK START ===', name: 'WidgetService');
      developer.log('Action: $action', name: 'WidgetService');
      developer.log('Item ID: $itemId', name: 'WidgetService');

      // Show immediate feedback
      developer.log('Showing completion feedback...', name: 'WidgetService');
      await _showCompletionFeedback(action, itemId);
      developer.log('Completion feedback shown', name: 'WidgetService');

      switch (action) {
        case 'toggle_task':
          developer.log('Processing task toggle for ID: $itemId', name: 'WidgetService');
          await _toggleTask(itemId);
          developer.log('Task $itemId toggled successfully', name: 'WidgetService');
          break;
        case 'toggle_habit':
          developer.log('Processing habit toggle for ID: $itemId', name: 'WidgetService');
          await _toggleHabit(itemId);
          developer.log('Habit $itemId toggled successfully', name: 'WidgetService');
          break;
        default:
          developer.log('ERROR: Unknown widget action: $action', name: 'WidgetService');
          return;
      }

      // Update widget to reflect changes immediately
      developer.log('Updating widget after successful $action...', name: 'WidgetService');
      await updateWidget();
    } catch (e, stackTrace) {
      Logger.error('Error handling widget click ($action, $itemId): $e');
      Logger.debug('Stack trace: $stackTrace');

      // Show error feedback
      await _showErrorFeedback(action, itemId);

      // Still try to update widget to show current state immediately
      try {
        await updateWidget();
      } catch (updateError) {
        Logger.error('Error updating widget after failed action: $updateError');
      }
      developer.log('=== HANDLE WIDGET CLICK ERROR END ===', name: 'WidgetService');
    }
  }

  Future<void> _showCompletionFeedback(String action, String itemId) async {
    try {
      final feedbackMessage = action == 'toggle_task' ? 'Task completed! ✓' : 'Habit completed! ✓';

      // Create temporary feedback data
      final feedbackData = {
        'tasks': [],
        'habits': [],
        'lastUpdated': DateTime.now().toIso8601String(),
        'feedback': feedbackMessage,
      };

      final jsonData = jsonEncode(feedbackData);
      await HomeWidget.saveWidgetData(_dataKey, jsonData);

      // Update both widgets to show feedback
      await Future.wait([
        HomeWidget.updateWidget(
          name: _tasksWidgetName,
          androidName: _tasksWidgetName,
        ),
        HomeWidget.updateWidget(
          name: _habitsWidgetName,
          androidName: _habitsWidgetName,
        ),
      ]);

      developer.log('Completion feedback shown for $action', name: 'WidgetService');
    } catch (e) {
      developer.log('Error showing completion feedback: $e', name: 'WidgetService');
    }
  }

  Future<void> _showErrorFeedback(String action, String itemId) async {
    try {
      final errorMessage = 'Error completing ${action == 'toggle_task' ? 'task' : 'habit'}';

      // Create temporary error feedback data
      final feedbackData = {
        'tasks': [],
        'habits': [],
        'lastUpdated': DateTime.now().toIso8601String(),
        'error': errorMessage,
      };

      final jsonData = jsonEncode(feedbackData);
      await HomeWidget.saveWidgetData(_dataKey, jsonData);

      // Update both widgets to show error feedback
      await Future.wait([
        HomeWidget.updateWidget(
          name: _tasksWidgetName,
          androidName: _tasksWidgetName,
        ),
        HomeWidget.updateWidget(
          name: _habitsWidgetName,
          androidName: _habitsWidgetName,
        ),
      ]);
    } catch (e) {
      Logger.error('Error showing error feedback: $e');
    }
  }

  Future<void> _toggleTask(String taskId) async {
    try {
      final taskResult = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: taskId),
      );

      final newCompletedAt = taskResult.completedAt == null ? DateTime.now().toUtc() : null;

      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
        SaveTaskCommand(
          id: taskResult.id,
          title: taskResult.title,
          description: taskResult.description,
          priority: taskResult.priority,
          plannedDate: taskResult.plannedDate,
          deadlineDate: taskResult.deadlineDate,
          estimatedTime: taskResult.estimatedTime,
          completedAt: newCompletedAt,
          parentTaskId: taskResult.parentTaskId,
          order: taskResult.order,
          plannedDateReminderTime: taskResult.plannedDateReminderTime,
          deadlineDateReminderTime: taskResult.deadlineDateReminderTime,
          recurrenceType: taskResult.recurrenceType,
          recurrenceInterval: taskResult.recurrenceInterval,
          recurrenceStartDate: taskResult.recurrenceStartDate,
          recurrenceEndDate: taskResult.recurrenceEndDate,
          recurrenceCount: taskResult.recurrenceCount,
        ),
      );
    } catch (e, stackTrace) {
      Logger.error('Error toggling task $taskId: $e');
      Logger.debug('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _toggleHabit(String habitId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get habit details to check for custom goals
      final habit = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
        GetHabitQuery(id: habitId),
      );
      final hasCustomGoals = habit.hasGoal;
      final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

      // Get today's records with sufficient page size for multiple occurrences
      final recordsResult = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
        GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: 20, // Allow for multiple daily occurrences
          habitId: habitId,
          startDate: startOfDay,
          endDate: endOfDay,
        ),
      );

      final todayCount = recordsResult.items.length;

      if (hasCustomGoals && dailyTarget > 1) {
        // Smart behavior for multi-occurrence habits with custom goals
        if (todayCount < dailyTarget) {
          // Add new record (increment)
          await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
            ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
          );
        } else {
          // Reset to 0 (remove all records for today)
          for (final record in recordsResult.items) {
            await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
              DeleteHabitRecordCommand(id: record.id),
            );
          }
        }
      } else {
        // Traditional behavior for simple habits or habits without custom goals
        // Remove ALL records for today (handles case where multiple records exist from when custom goals were enabled)
        if (todayCount > 0) {
          for (final record in recordsResult.items) {
            await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
              DeleteHabitRecordCommand(id: record.id),
            );
          }
        } else {
          // Add new record
          await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
            ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error toggling habit $habitId: $e');
      Logger.debug('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.me.ahmetcetinkaya.whph');

      // Register background callback for interactive widgets
      HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);

      // Set up widget click listener
      HomeWidget.widgetClicked.listen((uri) {
        if (uri == null) {
          Logger.error('Received null URI from widget click');
          return;
        }

        final action = uri.queryParameters['action'];
        final itemId = uri.queryParameters['itemId'];

        if (action != null && itemId != null) {
          handleWidgetClick(action, itemId);
        } else {
          Logger.error('Missing action or itemId in widget click URI');
        }
      });
    } catch (e, stackTrace) {
      Logger.error('ERROR during widget service initialization: $e');
      Logger.debug('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Debug method to force widget refresh
  Future<void> forceRefresh() async {
    // Clear existing data first
    await HomeWidget.saveWidgetData(_dataKey, '');

    // Update with fresh data immediately
    await updateWidget();

    Logger.info('Force widget refresh completed');
  }
}
