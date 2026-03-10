import 'package:mediatr/mediatr.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';

/// Helper class for toggling task and habit completion states in the foreground.
class WidgetToggleHelper {
  final Mediator _mediator;

  WidgetToggleHelper({required Mediator mediator}) : _mediator = mediator;

  /// Toggles the completion state of a task.
  Future<void> toggleTask(String taskId) async {
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
    } catch (e, stackTrace) {
      Logger.error('Error toggling task $taskId: $e');
      Logger.debug('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Toggles the completion state of a habit with smart behavior for multiple occurrences.
  Future<void> toggleHabit(String habitId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final habit = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
        GetHabitQuery(id: habitId),
      );
      final hasCustomGoals = habit.hasGoal;
      final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

      final recordsResult = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(
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
          await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
            ToggleHabitCompletionCommand(habitId: habitId, date: today, useIncrementalBehavior: true),
          );
        } else {
          for (final record in recordsResult.items) {
            await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
              DeleteHabitRecordCommand(id: record.id),
            );
          }
        }
      } else {
        if (todayCount > 0) {
          for (final record in recordsResult.items) {
            await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(
              DeleteHabitRecordCommand(id: record.id),
            );
          }
        } else {
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
}
