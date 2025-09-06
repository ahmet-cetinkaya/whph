import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/widgets.dart' hide Container;
import 'package:home_widget/home_widget.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/shared/utils/logger.dart';
import '../models/widget_data.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
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

      // Update the widget after completion
      try {
        final widgetService = container.resolve<WidgetService>();
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

    final newCompletionStatus = !taskResult.isCompleted;
    await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
      SaveTaskCommand(
        id: taskResult.id,
        title: taskResult.title,
        description: taskResult.description,
        priority: taskResult.priority,
        plannedDate: taskResult.plannedDate,
        deadlineDate: taskResult.deadlineDate,
        estimatedTime: taskResult.estimatedTime,
        isCompleted: newCompletionStatus,
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
    if (newCompletionStatus) {
      try {
        final soundPlayer = container.resolve<ISoundPlayer>();
        soundPlayer.play(SharedSounds.done, volume: 1.0);
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

/// Background habit toggle function
Future<void> _backgroundToggleHabit(Mediator mediator, IContainer container, String habitId) async {
  try {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final recordsResult = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
      GetListHabitRecordsQuery(
        pageIndex: 0,
        pageSize: 1,
        habitId: habitId,
        startDate: startOfDay,
        endDate: endOfDay,
      ),
    );

    if (recordsResult.items.isNotEmpty) {
      // Habit is completed today, remove the record
      final recordId = recordsResult.items.first.id;
      await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
        DeleteHabitRecordCommand(id: recordId),
      );
    } else {
      // Habit is not completed today, add a record
      await mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(
        AddHabitRecordCommand(habitId: habitId, occurredAt: today),
      );

      // Play completion sound for habit completion
      try {
        final soundPlayer = container.resolve<ISoundPlayer>();
        soundPlayer.play(SharedSounds.done, volume: 1.0);
      } catch (e) {
        Logger.warning('Error playing completion sound: $e');
        // Don't rethrow - sound failure shouldn't break the habit completion
        // This is expected in test environments where the full DI setup is not available
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
  late final FilterSettingsManager _filterSettingsManager;

  WidgetService({required Mediator mediator}) : _mediator = mediator {
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
        // Exclude habits completed today (same as TodayPage)
        excludeCompletedForDate: startOfDay,
        // Apply tag filtering from TodayPage settings
        filterByTags: showNoTagsFilter ? [] : selectedTagIds,
        filterNoTags: showNoTagsFilter,
      ),
    );

    // Convert habits to widget data - these are already filtered to exclude completed ones
    final habits = habitsResult.items
        .map((habit) => WidgetHabitData(
              id: habit.id,
              name: habit.name,
              isCompletedToday: false, // These are already filtered to exclude completed ones
            ))
        .toList();

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

      // Update widget to reflect changes after a brief delay
      developer.log('Waiting 500ms before widget update...', name: 'WidgetService');
      await Future.delayed(const Duration(milliseconds: 500));

      developer.log('Updating widget after successful $action...', name: 'WidgetService');
      await updateWidget();
    } catch (e, stackTrace) {
      Logger.error('Error handling widget click ($action, $itemId): $e');
      Logger.debug('Stack trace: $stackTrace');

      // Show error feedback
      await _showErrorFeedback(action, itemId);

      // Still try to update widget to show current state after a delay
      await Future.delayed(const Duration(milliseconds: 1000));
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

      final newCompletionStatus = !taskResult.isCompleted;

      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(
        SaveTaskCommand(
          id: taskResult.id,
          title: taskResult.title,
          description: taskResult.description,
          priority: taskResult.priority,
          plannedDate: taskResult.plannedDate,
          deadlineDate: taskResult.deadlineDate,
          estimatedTime: taskResult.estimatedTime,
          isCompleted: newCompletionStatus,
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

      final recordsResult = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
        GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: 1,
          habitId: habitId,
          startDate: startOfDay,
          endDate: endOfDay,
        ),
      );

      if (recordsResult.items.isNotEmpty) {
        // Habit is completed today, remove the record
        final recordId = recordsResult.items.first.id;
        await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
          DeleteHabitRecordCommand(id: recordId),
        );
      } else {
        // Habit is not completed today, add a record
        await _mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(
          AddHabitRecordCommand(habitId: habitId, occurredAt: today),
        );
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

    // Wait a moment
    await Future.delayed(const Duration(milliseconds: 100));

    // Update with fresh data
    await updateWidget();

    Logger.info('Force widget refresh completed');
  }
}
