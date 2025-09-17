// ignore_for_file: unused_local_variable

import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:acore/acore.dart';

class ToggleHabitCompletionCommand implements IRequest<ToggleHabitCompletionCommandResponse> {
  final String habitId;
  final DateTime date;
  final bool useIncrementalBehavior;

  ToggleHabitCompletionCommand({
    required this.habitId,
    required this.date,
    this.useIncrementalBehavior = false,
  });
}

class ToggleHabitCompletionCommandResponse {}

class ToggleHabitCompletionCommandHandler
    implements IRequestHandler<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse> {
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  ToggleHabitCompletionCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<ToggleHabitCompletionCommandResponse> call(ToggleHabitCompletionCommand request) async {
    // Validate that the habit exists and fetch its details
    final habit = await _habitRepository.getById(request.habitId);
    if (habit == null) {
      throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
    }

    // Normalize the date to start of day for consistent comparison
    final targetDate = DateTimeHelper.toLocalDateTime(request.date);
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).toUtc();
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    // Fetch existing habit records for the date
    final habitRecords = await _habitRecordRepository.getListByHabitIdAndRangeDate(
      request.habitId,
      startOfDay,
      endOfDay,
      0,
      1000, // Sufficient for a single day
    );

    for (int i = 0; i < habitRecords.items.length; i++) {
      final record = habitRecords.items[i];
    }

    // Count records for the specific date
    final dailyCompletionCount = _countRecordsForDate(habitRecords.items, request.date);
    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

    if (hasCustomGoals && dailyTarget > 1) {
      print('🔄 Handling MULTI-OCCURRENCE habit');
      await _handleMultiOccurrenceHabit(
        habit: habit,
        date: request.date,
        dailyCompletionCount: dailyCompletionCount,
        dailyTarget: dailyTarget,
        useIncrementalBehavior: request.useIncrementalBehavior,
        existingRecords: habitRecords.items,
      );
    } else {
      print('🔄 Handling TRADITIONAL habit');
      await _handleTraditionalHabit(
        habit: habit,
        date: request.date,
        dailyCompletionCount: dailyCompletionCount,
        existingRecords: habitRecords.items,
      );
    }

    return ToggleHabitCompletionCommandResponse();
  }

  /// Handle multi-occurrence habits with smart increment/reset logic
  Future<void> _handleMultiOccurrenceHabit({
    required dynamic habit,
    required DateTime date,
    required int dailyCompletionCount,
    required int dailyTarget,
    required bool useIncrementalBehavior,
    required List<dynamic> existingRecords,
  }) async {
    if (useIncrementalBehavior) {
      // Checkbox behavior: increment until target, then reset
      if (dailyCompletionCount < dailyTarget) {
        print('📈 CHECKBOX: Adding habit record (under target)');
        await _addHabitRecord(habit.id, date, habit);
      } else {
        print('🔄 CHECKBOX: Resetting to 0 (at/over target)');
        await _deleteAllHabitRecordsForDay(habit, date, existingRecords);
      }
    } else {
      // Calendar behavior: toggle between complete/incomplete
      if (dailyCompletionCount >= dailyTarget) {
        print('✖️ CALENDAR: Uncompleting (removing all records)');
        await _deleteAllHabitRecordsForDay(habit, date, existingRecords);
      } else {
        print('✅ CALENDAR: Completing (adding record)');
        await _addHabitRecord(habit.id, date, habit);
      }
    }
  }

  /// Handle traditional habits with simple toggle logic
  Future<void> _handleTraditionalHabit({
    required dynamic habit,
    required DateTime date,
    required int dailyCompletionCount,
    required List<dynamic> existingRecords,
  }) async {
    if (dailyCompletionCount > 0) {
      print('✖️ TRADITIONAL: Uncompleting (removing all records)');
      // Remove ALL records for this date (handles case where multiple records exist from when custom goals were enabled)
      await _deleteAllHabitRecordsForDay(habit, date, existingRecords);
    } else {
      print('✅ TRADITIONAL: Completing (adding record)');
      await _addHabitRecord(habit.id, date, habit);
    }
  }

  /// Add a habit record (includes time record logic from AddHabitRecordCommand)
  Future<void> _addHabitRecord(String habitId, DateTime date, dynamic habit) async {
    final now = DateTime.now().toUtc();
    final occurredAt = DateTimeHelper.toUtcDateTime(date);

    // Create the habit record
    HabitRecord habitRecord = HabitRecord(
      id: KeyHelper.generateStringId(),
      createdDate: now,
      habitId: habitId,
      occurredAt: occurredAt,
    );
    await _habitRecordRepository.add(habitRecord);

    // Handle time records for habits with estimated time
    if (habit.estimatedTime != null && habit.estimatedTime! > 0) {
      final targetDate = occurredAt;
      final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
      final endOfHour = startOfHour.add(const Duration(hours: 1));

      // Check if there's already a time record for this hour
      final filter = CustomWhereFilter(
          'habit_id = ? AND created_date >= ? AND created_date < ?', [habitId, startOfHour, endOfHour]);

      final existingRecord = await _habitTimeRecordRepository.getFirst(filter);

      if (existingRecord != null) {
        // Add the estimated time to the existing record
        existingRecord.duration = (existingRecord.duration + (habit.estimatedTime! * 60)).toInt();
        await _habitTimeRecordRepository.update(existingRecord);
      } else {
        // Create a new time record
        HabitTimeRecord timeRecord = HabitTimeRecord(
          id: KeyHelper.generateStringId(),
          createdDate: startOfHour, // Use hour bucket start time for consistency
          habitId: habitId,
          duration: (habit.estimatedTime! * 60).toInt(), // Use estimated time as duration
          occurredAt: occurredAt, // Set when the time was actually logged
        );
        await _habitTimeRecordRepository.add(timeRecord);
      }
    } else {}
  }

  /// Delete all habit records for a day (includes proper time record management)
  Future<void> _deleteAllHabitRecordsForDay(dynamic habit, DateTime date, List<dynamic> existingRecords) async {
    print('🗑️ DELETE ALL HABIT RECORDS FOR DAY called:');
    print('   Habit ID: ${habit.id}');
    print('   Date: $date');
    print('   Existing records count: ${existingRecords.length}');

    // Use the same date conversion as when creating records to ensure we find the right time records
    final occurredAt = DateTimeHelper.toUtcDateTime(date);
    final targetDate = DateTime.utc(occurredAt.year, occurredAt.month, occurredAt.day);
    final nextDay = targetDate.add(const Duration(days: 1));

    print('   🔍 Original date: $date');
    print('   🔍 Occurred at (UTC): $occurredAt');
    print('   🔍 Target date (UTC): $targetDate');

    // Get all habit records for the habit on the same date
    final habitRecords = await _habitRecordRepository.getListByHabitIdAndRangeDate(
      habit.id,
      targetDate,
      nextDay.subtract(const Duration(microseconds: 1)),
      0,
      1000, // Sufficient for a single day
    );

    print('   🔍 Found ${habitRecords.items.length} habit records in date range:');
    for (int i = 0; i < habitRecords.items.length; i++) {
      final record = habitRecords.items[i];
      print('   Record $i: ${record.id}, occurredAt: ${record.occurredAt}, createdDate: ${record.createdDate}');
    }

    // Get ALL time records for the habit and filter them by date manually
    // This ensures we catch all records for the day, regardless of how they were created
    final allTimeRecords = await _habitTimeRecordRepository.getByHabitId(habit.id);
    final timeRecords = allTimeRecords.where((record) {
      // Check if the record occurred on the same day using multiple date fields
      // Priority: occurredAt (actual occurrence) -> createdDate (fallback)
      final recordOccurredAt = record.occurredAt;
      final recordCreatedAt = record.createdDate;

      // Use the original date for comparison instead of converted targetDate
      final originalLocalDate = DateTimeHelper.toLocalDateTime(date);

      // First try to match by occurredAt if it exists
      if (recordOccurredAt != null) {
        final recordLocalDate = DateTimeHelper.toLocalDateTime(recordOccurredAt);
        final isSameDay = DateTimeHelper.isSameDay(recordLocalDate, originalLocalDate);
        if (isSameDay) return true;
      }

      // Fallback: check if createdDate matches the original date (for records without occurredAt)
      final recordCreatedLocalDate = DateTimeHelper.toLocalDateTime(recordCreatedAt);
      final isSameDayByCreatedDate = DateTimeHelper.isSameDay(recordCreatedLocalDate, originalLocalDate);

      return isSameDayByCreatedDate;
    }).toList();

    print('   🔍 Original date (local): ${DateTimeHelper.toLocalDateTime(date)}');
    print('   🔍 Target date (local): ${DateTimeHelper.toLocalDateTime(targetDate)}');
    print('   🔍 Found ${timeRecords.length} time records for the day:');
    for (int i = 0; i < timeRecords.length; i++) {
      final record = timeRecords[i];
      final occurredAtLocal = record.occurredAt != null ? DateTimeHelper.toLocalDateTime(record.occurredAt!) : null;
      final createdAtLocal = DateTimeHelper.toLocalDateTime(record.createdDate);
      print(
          '   Record $i: ${record.id}, duration: ${record.duration}s');
      print('     occurredAt: ${record.occurredAt} (local: $occurredAtLocal)');
      print('     createdDate: ${record.createdDate} (local: $createdAtLocal)');
    }

    // Delete all time records for the specified date
    for (int i = 0; i < timeRecords.length; i++) {
      final timeRecord = timeRecords[i];
      await _habitTimeRecordRepository.delete(timeRecord);
    }

    // Delete all habit records for the specified habit and date
    for (int i = 0; i < habitRecords.items.length; i++) {
      final habitRecord = habitRecords.items[i];
      await _habitRecordRepository.delete(habitRecord);
    }
  }

  /// Count habit records for a specific date
  int _countRecordsForDate(List<dynamic> habitRecords, DateTime date) {
    return habitRecords
        .where((record) => DateTimeHelper.isSameDay(
            DateTimeHelper.toLocalDateTime(record.occurredAt), DateTimeHelper.toLocalDateTime(date)))
        .length;
  }
}
