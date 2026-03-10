import 'dart:async';
import 'package:flutter/widgets.dart' hide Container;
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import '../widget_service.dart';

/// Background callback function for HomeWidget interactive widgets.
/// This function is called when a widget is clicked and performs the actual completion logic.
@pragma("vm:entry-point")
FutureOr<void> widgetBackgroundCallback(Uri? data) async {
  if (data == null) {
    Logger.error('Widget background callback received null URI');
    return;
  }

  try {
    final action = data.queryParameters['action'];
    final itemId = data.queryParameters['itemId'];

    if (action != null && itemId != null) {
      WidgetsFlutterBinding.ensureInitialized();

      IContainer container;
      try {
        container = await AppBootstrapService.initializeApp().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Container initialization timed out', const Duration(seconds: 10));
          },
        );
      } catch (e) {
        Logger.warning('Container initialization failed, using existing instance: $e');
        try {
          final containerInstance = Container().instance;
          container = containerInstance;
        } catch (containerError) {
          Logger.error('Failed to get existing container instance: $containerError');
          return;
        }
      }

      Mediator mediator;
      try {
        mediator = container.resolve<Mediator>();
      } catch (e) {
        Logger.error('Failed to resolve Mediator from container: $e');
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

      try {
        final widgetService = container.resolve<WidgetService>();
        await widgetService.updateWidget();
        await widgetService.updateWidget();
      } catch (e) {
        Logger.error('Failed to resolve WidgetService or update widget: $e');
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
        plannedDateReminderCustomOffset: taskResult.plannedDateReminderCustomOffset,
        deadlineDateReminderTime: taskResult.deadlineDateReminderTime,
        deadlineDateReminderCustomOffset: taskResult.deadlineDateReminderCustomOffset,
        recurrenceType: taskResult.recurrenceType,
        recurrenceInterval: taskResult.recurrenceInterval,
        recurrenceStartDate: taskResult.recurrenceStartDate,
        recurrenceEndDate: taskResult.recurrenceEndDate,
        recurrenceCount: taskResult.recurrenceCount,
        recurrenceParentId: taskResult.recurrenceParentId,
        recurrenceConfiguration: taskResult.recurrenceConfiguration,
      ),
    );

    if (newCompletedAt != null) {
      try {
        final soundManagerService = container.resolve<ISoundManagerService>();
        soundManagerService.playTaskCompletion();
      } catch (e) {
        Logger.warning('Error playing completion sound: $e');
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

    final habit = await mediator.send<GetHabitQuery, GetHabitQueryResponse>(
      GetHabitQuery(id: habitId),
    );
    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

    final recordsResult = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
      GetListHabitRecordsQuery(
        pageIndex: 0,
        pageSize: 20,
        habitId: habitId,
        startDate: startOfDay,
        endDate: endOfDay,
      ),
    );

    final todayCount = recordsResult.items.length;

    if (hasCustomGoals && dailyTarget > 1) {
      if (todayCount < dailyTarget) {
        await mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
          ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
        );

        try {
          final soundManagerService = container.resolve<ISoundManagerService>();
          soundManagerService.playHabitCompletion();
        } catch (e) {
          Logger.warning('Error playing completion sound: $e');
        }
      } else {
        for (final record in recordsResult.items) {
          await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
            DeleteHabitRecordCommand(id: record.id),
          );
        }
      }
    } else {
      if (todayCount > 0) {
        for (final record in recordsResult.items) {
          await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
            DeleteHabitRecordCommand(id: record.id),
          );
        }
      } else {
        await mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
          ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
        );

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
