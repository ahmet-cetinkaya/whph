import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:whph/src/core/domain/features/habits/habit_record.dart';
import 'package:whph/src/core/application/features/habits/constants/habit_translation_keys.dart';

class GetHabitQuery implements IRequest<GetHabitQueryResponse> {
  late String? id;

  GetHabitQuery({this.id});
}

class HabitStreak {
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final int? completions; // For goal-based streaks, this represents the number of completed periods

  HabitStreak({
    required this.startDate,
    required this.endDate,
    required this.days,
    this.completions,
  });
}

class HabitStatistics {
  final double overallScore;
  final double monthlyScore;
  final double yearlyScore;
  final int totalRecords;
  final List<MapEntry<DateTime, double>> monthlyScores;
  final List<HabitStreak> topStreaks;
  final Map<int, int> yearlyFrequency;
  final double? goalSuccessRate;
  final int? daysGoalMet;
  final int? totalDaysWithGoal;

  HabitStatistics({
    required this.overallScore,
    required this.monthlyScore,
    required this.yearlyScore,
    required this.totalRecords,
    required this.monthlyScores,
    required this.topStreaks,
    required this.yearlyFrequency,
    this.goalSuccessRate,
    this.daysGoalMet,
    this.totalDaysWithGoal,
  });
}

class GetHabitQueryResponse extends Habit {
  final HabitStatistics statistics;

  GetHabitQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required super.name,
    required super.description,
    super.estimatedTime,
    super.hasReminder = false,
    super.reminderTime,
    super.archivedDate,
    List<int> reminderDays = const [],
    super.hasGoal = false,
    super.targetFrequency = 1,
    super.periodDays = 7,
    required this.statistics,
  }) {
    setReminderDaysFromList(reminderDays);
  }
}

class GetHabitQueryHandler implements IRequestHandler<GetHabitQuery, GetHabitQueryResponse> {
  late final IHabitRepository _habitRepository;
  late final IHabitRecordRepository _habitRecordRepository;

  GetHabitQueryHandler(
      {required IHabitRepository habitRepository, required IHabitRecordRepository habitRecordRepository})
      : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository;

  @override
  Future<GetHabitQueryResponse> call(GetHabitQuery request) async {
    Habit? habit = await _habitRepository.getById(request.id!);
    if (habit == null) {
      throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
    }

    // Get all records for statistics calculation using pagination
    final records = await _getAllHabitRecords(habit.id);
    final habitRecords = records.where((r) => r.deletedDate == null).toList();

    // Update statistics calculation to handle archived habits
    final statistics = await _calculateStatistics(habit, habitRecords);

    // Get the reminderDays directly from the database
    final reminderDaysResult = await _habitRepository.getReminderDaysById(habit.id);
    final reminderDaysList = reminderDaysResult.isNotEmpty
        ? reminderDaysResult.split(',').where((s) => s.isNotEmpty).map((s) => int.parse(s.trim())).toList()
        : <int>[];

    return GetHabitQueryResponse(
      id: habit.id,
      createdDate: habit.createdDate,
      modifiedDate: habit.modifiedDate,
      name: habit.name,
      description: habit.description,
      estimatedTime: habit.estimatedTime,
      hasReminder: habit.hasReminder,
      reminderTime: habit.reminderTime,
      reminderDays: reminderDaysList,
      archivedDate: habit.archivedDate,
      deletedDate: habit.deletedDate,
      hasGoal: habit.hasGoal,
      targetFrequency: habit.targetFrequency,
      periodDays: habit.periodDays,
      statistics: statistics,
    );
  }

  Future<List<HabitRecord>> _getAllHabitRecords(String habitId) async {
    const int pageSize = 100;
    int pageIndex = 0;
    List<HabitRecord> allRecords = [];
    bool hasMoreRecords = true;

    while (hasMoreRecords) {
      final result = await _habitRecordRepository.getListByHabitIdAndRangeDate(
        habitId,
        DateTime(0).toUtc(),
        DateTime.now().toUtc(),
        pageIndex,
        pageSize,
      );

      allRecords.addAll(result.items);
      hasMoreRecords = result.items.length == pageSize;
      pageIndex++;
    }

    return allRecords;
  }

  Future<HabitStatistics> _calculateStatistics(Habit habit, List<HabitRecord> records) async {
    // Use archive date as end date for archived habits
    final endDate = habit.archivedDate?.toLocal() ?? DateTime.now();
    final startOfMonth = DateTime(endDate.year, endDate.month, 1);
    final startOfYear = DateTime(endDate.year, 1, 1);

    // Calculate overall score based on first record date
    var overallScore = 0.0;
    if (records.isNotEmpty) {
      final sortedRecords = records.toList()..sort((a, b) => a.date.compareTo(b.date));
      final firstRecordDate = sortedRecords.first.date;
      final daysFromFirstRecord = endDate.difference(firstRecordDate).inDays + 1;
      overallScore = records.length / daysFromFirstRecord;
    }

    // Calculate monthly score
    final daysInCurrentMonth = endDate.difference(startOfMonth).inDays + 1;
    final monthlyRecords =
        records.where((r) => r.date.isAfter(startOfMonth) || _isSameDay(r.date, startOfMonth)).length;
    final monthlyScore = monthlyRecords / daysInCurrentMonth;

    // Calculate yearly score
    final daysInCurrentYear = endDate.difference(startOfYear).inDays + 1;
    final yearlyRecords = records.where((r) => r.date.isAfter(startOfYear) || _isSameDay(r.date, startOfYear)).length;
    final yearlyScore = yearlyRecords / daysInCurrentYear;

    // Calculate monthly scores for the last 12 months
    final monthlyScores = <MapEntry<DateTime, double>>[];
    for (var i = 11; i >= 0; i--) {
      final month = DateTime(endDate.year, endDate.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final monthEnd = i == 0 ? endDate : nextMonth.subtract(const Duration(days: 1));

      final monthRecords = records
          .where((r) =>
              (r.date.isAfter(month) || _isSameDay(r.date, month)) &&
              (r.date.isBefore(monthEnd) || _isSameDay(r.date, monthEnd)))
          .length;
      final daysInMonth = monthEnd.difference(month).inDays + 1;
      monthlyScores.add(MapEntry(month, monthRecords / daysInMonth));
    }

    // Calculate top streaks up to archive date if archived
    final streaks = _calculateStreaks(records, habit: habit, endDate: habit.archivedDate);
    final topStreaks = streaks.take(5).toList();

    // Calculate yearly frequency
    final yearlyFrequency = <int, int>{};
    for (final record in records) {
      final dayOfYear = record.date.difference(DateTime(record.date.year, 1, 1)).inDays;
      yearlyFrequency[dayOfYear] = (yearlyFrequency[dayOfYear] ?? 0) + 1;
    }

    // Calculate goal statistics if goal is enabled
    double? goalSuccessRate;
    int? daysGoalMet;
    int? totalDaysWithGoal;

    if (habit.hasGoal) {
      final periodEnd = endDate;
      final periodStart = periodEnd.subtract(Duration(days: habit.periodDays - 1));

      final recordsInCurrentPeriod = records
          .where((record) =>
              (record.date.isAfter(periodStart.subtract(const Duration(days: 1))) ||
                  _isSameDay(record.date, periodStart)) &&
              (record.date.isBefore(periodEnd.add(const Duration(days: 1))) || _isSameDay(record.date, periodEnd)))
          .length;

      daysGoalMet = recordsInCurrentPeriod;
      totalDaysWithGoal = habit.targetFrequency;
      goalSuccessRate = recordsInCurrentPeriod.toDouble() / habit.targetFrequency;
      if (goalSuccessRate > 1.0) goalSuccessRate = 1.0;
    }

    return HabitStatistics(
      overallScore: overallScore,
      monthlyScore: monthlyScore,
      yearlyScore: yearlyScore,
      totalRecords: records.length,
      monthlyScores: monthlyScores,
      topStreaks: topStreaks,
      yearlyFrequency: yearlyFrequency,
      goalSuccessRate: goalSuccessRate,
      daysGoalMet: daysGoalMet,
      totalDaysWithGoal: totalDaysWithGoal,
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  List<HabitStreak> _calculateStreaks(List<HabitRecord> records, {required Habit habit, DateTime? endDate}) {
    if (records.isEmpty) return [];

    if (habit.hasGoal) {
      return _calculateGoalBasedStreaks(records, habit, endDate);
    } else {
      return _calculateConsecutiveDayStreaks(records, endDate, minDays: 2);
    }
  }

  List<HabitStreak> _calculateConsecutiveDayStreaks(List<HabitRecord> records, DateTime? endDate, {int minDays = 2}) {
    final sortedRecords = records.toList()..sort((a, b) => a.date.compareTo(b.date));

    final streaks = <HabitStreak>[];
    var streakStart = sortedRecords.first.date;
    var lastDate = streakStart;

    for (var i = 1; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      if (record.date.difference(lastDate).inDays > 1) {
        // Only add streaks that ended before or on the archive date
        if (endDate == null || !lastDate.isAfter(endDate)) {
          if (lastDate.difference(streakStart).inDays >= minDays - 1) {
            streaks.add(HabitStreak(
              startDate: streakStart,
              endDate: lastDate,
              days: lastDate.difference(streakStart).inDays + 1,
            ));
          }
        }
        streakStart = record.date;
      }
      lastDate = record.date;
    }

    // Add the last streak if it exists and respects the end date
    if (lastDate.difference(streakStart).inDays >= minDays - 1 && (endDate == null || !lastDate.isAfter(endDate))) {
      streaks.add(HabitStreak(
        startDate: streakStart,
        endDate: lastDate,
        days: lastDate.difference(streakStart).inDays + 1,
      ));
    }

    // Sort by streak length
    streaks.sort((a, b) => b.days.compareTo(a.days));
    return streaks;
  }

  List<HabitStreak> _calculateGoalBasedStreaks(List<HabitRecord> records, Habit habit, DateTime? endDate) {
    if (records.isEmpty) return [];

    final sortedRecords = records.toList()..sort((a, b) => a.date.compareTo(b.date));
    final streaks = <HabitStreak>[];

    // Calculate streaks based on goal periods
    var currentPeriodStart = sortedRecords.first.date;
    var streakStart = currentPeriodStart;
    var consecutiveSuccessfulPeriods = 0;

    while (currentPeriodStart.isBefore(endDate ?? DateTime.now())) {
      final currentPeriodEnd = currentPeriodStart.add(Duration(days: habit.periodDays - 1));

      // Count records in current period
      final recordsInPeriod = sortedRecords
          .where((record) =>
              (record.date.isAfter(currentPeriodStart.subtract(const Duration(days: 1))) ||
                  _isSameDay(record.date, currentPeriodStart)) &&
              (record.date.isBefore(currentPeriodEnd.add(const Duration(days: 1))) ||
                  _isSameDay(record.date, currentPeriodEnd)))
          .length;

      final goalMet = recordsInPeriod >= habit.targetFrequency;

      if (goalMet) {
        if (consecutiveSuccessfulPeriods == 0) {
          streakStart = currentPeriodStart;
        }
        consecutiveSuccessfulPeriods++;
      } else {
        if (consecutiveSuccessfulPeriods >= 2) {
          // At least 2 successful periods to count as streak
          streaks.add(HabitStreak(
            startDate: streakStart,
            endDate: currentPeriodStart.subtract(const Duration(days: 1)),
            days: consecutiveSuccessfulPeriods * habit.periodDays,
            completions: consecutiveSuccessfulPeriods,
          ));
        }
        consecutiveSuccessfulPeriods = 0;
      }

      currentPeriodStart = currentPeriodStart.add(Duration(days: habit.periodDays));
    }

    // Add the last streak if it exists
    if (consecutiveSuccessfulPeriods >= 2) {
      streaks.add(HabitStreak(
        startDate: streakStart,
        endDate: currentPeriodStart.subtract(const Duration(days: 1)),
        days: consecutiveSuccessfulPeriods * habit.periodDays,
        completions: consecutiveSuccessfulPeriods,
      ));
    }

    // Sort by streak length
    streaks.sort((a, b) => b.days.compareTo(a.days));
    return streaks;
  }
}
