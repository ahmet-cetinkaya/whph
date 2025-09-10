import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:acore/acore.dart' as acore;

/// Centralized service for habit completion toggle logic
/// Eliminates duplication across UI components like HabitCard, HabitCalendarView, and WidgetService
class HabitCompletionService {

  /// Toggle habit completion for a specific date with smart multi-occurrence logic
  Future<void> toggleHabitCompletion({
    required HabitListItem habit,
    required DateTime date,
    required GetListHabitRecordsQueryResponse habitRecords,
    required Future<void> Function(String recordId) deleteRecord,
    required Future<void> Function(String habitId, DateTime date) createRecord,
    bool useIncrementalBehavior = false, // true for checkbox, false for calendar
  }) async {
    final dailyCompletionCount = _countRecordsForDate(habitRecords, date);
    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

    if (hasCustomGoals && dailyTarget > 1) {
      await _handleMultiOccurrenceHabit(
        habit: habit,
        date: date,
        dailyCompletionCount: dailyCompletionCount,
        dailyTarget: dailyTarget,
        habitRecords: habitRecords,
        deleteRecord: deleteRecord,
        createRecord: createRecord,
        useIncrementalBehavior: useIncrementalBehavior,
      );
    } else {
      await _handleTraditionalHabit(
        habit: habit,
        date: date,
        dailyCompletionCount: dailyCompletionCount,
        habitRecords: habitRecords,
        deleteRecord: deleteRecord,
        createRecord: createRecord,
      );
    }
  }

  /// Handle multi-occurrence habits with smart increment/reset logic
  Future<void> _handleMultiOccurrenceHabit({
    required HabitListItem habit,
    required DateTime date,
    required int dailyCompletionCount,
    required int dailyTarget,
    required GetListHabitRecordsQueryResponse habitRecords,
    required Future<void> Function(String recordId) deleteRecord,
    required Future<void> Function(String habitId, DateTime date) createRecord,
    required bool useIncrementalBehavior,
  }) async {
    if (useIncrementalBehavior) {
      // Checkbox behavior: increment until target, then reset
      if (dailyCompletionCount < dailyTarget) {
        await createRecord(habit.id, date);
      } else {
        await _deleteAllRecordsForDate(habitRecords, date, deleteRecord);
      }
    } else {
      // Calendar behavior: toggle between complete/incomplete
      if (dailyCompletionCount >= dailyTarget) {
        await _deleteAllRecordsForDate(habitRecords, date, deleteRecord);
      } else {
        await createRecord(habit.id, date);
      }
    }
  }

  /// Handle traditional habits with simple toggle logic
  Future<void> _handleTraditionalHabit({
    required HabitListItem habit,
    required DateTime date,
    required int dailyCompletionCount,
    required GetListHabitRecordsQueryResponse habitRecords,
    required Future<void> Function(String recordId) deleteRecord,
    required Future<void> Function(String habitId, DateTime date) createRecord,
  }) async {
    if (dailyCompletionCount > 0) {
      // Remove ALL records for this date (handles case where multiple records exist from when custom goals were enabled)
      await _deleteAllRecordsForDate(habitRecords, date, deleteRecord);
    } else {
      await createRecord(habit.id, date);
    }
  }

  /// Delete all habit records for a specific date
  Future<void> _deleteAllRecordsForDate(
    GetListHabitRecordsQueryResponse habitRecords,
    DateTime date,
    Future<void> Function(String recordId) deleteRecord,
  ) async {
    final dayRecords = habitRecords.items
        .where((record) => acore.DateTimeHelper.isSameDay(
            acore.DateTimeHelper.toLocalDateTime(record.occurredAt),
            acore.DateTimeHelper.toLocalDateTime(date)))
        .toList();

    for (final record in dayRecords) {
      await deleteRecord(record.id);
    }
  }

  /// Count habit records for a specific date
  int _countRecordsForDate(GetListHabitRecordsQueryResponse habitRecords, DateTime date) {
    return habitRecords.items
        .where((record) => acore.DateTimeHelper.isSameDay(
            acore.DateTimeHelper.toLocalDateTime(record.occurredAt),
            acore.DateTimeHelper.toLocalDateTime(date)))
        .length;
  }
}