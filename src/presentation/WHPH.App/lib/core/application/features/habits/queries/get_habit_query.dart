import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';

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
    super.dailyTarget,
    required this.statistics,
  }) {
    setReminderDaysFromList(reminderDays);
  }
}

class GetHabitQueryHandler implements IRequestHandler<GetHabitQuery, GetHabitQueryResponse> {
  late final IHabitRepository _habitRepository;
  late final IHabitRecordRepository _habitRecordRepository;
  late final ISettingRepository _settingsRepository;

  GetHabitQueryHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required ISettingRepository settingsRepository,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _settingsRepository = settingsRepository;

  @override
  Future<GetHabitQueryResponse> call(GetHabitQuery request) async {
    Habit? habit = await _habitRepository.getById(request.id!);
    if (habit == null) {
      throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
    }

    // Get all records for statistics calculation using pagination
    final records = await _getAllHabitRecords(habit.id);
    final habitRecords = records.where((r) => r.deletedDate == null).toList();

    // Get 3-state setting
    final setting = await _settingsRepository.getByKey(SettingKeys.habitThreeStateEnabled);
    final isThreeStateEnabled = setting != null && setting.getValue<bool>() == true;

    // Update statistics calculation to handle archived habits and 3-state setting
    final statistics = await _calculateStatistics(habit, habitRecords, isThreeStateEnabled: isThreeStateEnabled);

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
      dailyTarget: habit.dailyTarget,
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

  Future<HabitStatistics> _calculateStatistics(Habit habit, List<HabitRecord> records,
      {bool isThreeStateEnabled = false}) async {
    // Use archive date as end date for archived habits
    final endDate = habit.archivedDate?.toLocal() ?? DateTime.now();
    final startOfMonth = DateTime(endDate.year, endDate.month, 1);
    final startOfYear = DateTime(endDate.year, 1, 1);

    // Get daily target (default to 1 for backward compatibility)
    final dailyTarget = habit.dailyTarget ?? 1;

    // Group records by date and calculate daily scores
    final recordsByDate = <DateTime, List<HabitRecord>>{};
    for (final record in records) {
      if (record.status == HabitRecordStatus.complete) {
        final dateKey = DateTime(record.recordDate.year, record.recordDate.month, record.recordDate.day);
        recordsByDate.putIfAbsent(dateKey, () => []).add(record);
      }
    }

    final dailyScores = <DateTime, double>{};
    for (final entry in recordsByDate.entries) {
      final dailyScore = entry.value.length / dailyTarget;
      dailyScores[entry.key] = dailyScore > 1.0 ? 1.0 : dailyScore; // Cap at 1.0
    }

    // Calculate overall score based on first record date
    var overallScore = 0.0;
    if (records.isNotEmpty) {
      final sortedRecords = records.toList()..sort((a, b) => a.recordDate.compareTo(b.recordDate));
      final firstRecordDate = sortedRecords.first.recordDate;
      int daysFromFirstRecord;

      if (isThreeStateEnabled) {
        daysFromFirstRecord = _countActiveDaysInRange(sortedRecords, firstRecordDate, endDate);
        if (daysFromFirstRecord == 0) daysFromFirstRecord = 1;
      } else {
        daysFromFirstRecord = endDate.difference(firstRecordDate).inDays + 1;
      }

      // Calculate average daily score
      final totalScore = dailyScores.values.fold(0.0, (sum, score) => sum + score);
      overallScore = totalScore / daysFromFirstRecord;
    }

    // Calculate monthly score based on daily scores
    int daysInCurrentMonth;
    if (isThreeStateEnabled) {
      daysInCurrentMonth = _countActiveDaysInRange(records, startOfMonth, endDate);
      if (daysInCurrentMonth == 0) daysInCurrentMonth = 1;
    } else {
      daysInCurrentMonth = endDate.difference(startOfMonth).inDays + 1;
    }

    final monthlyDailyScores = dailyScores.entries
        .where(
            (entry) => entry.key.isAfter(startOfMonth.subtract(const Duration(days: 1))) && !entry.key.isAfter(endDate))
        .map((entry) => entry.value);
    final monthlyTotalScore = monthlyDailyScores.fold(0.0, (sum, score) => sum + score);
    final monthlyScore = monthlyTotalScore / daysInCurrentMonth;

    // Calculate yearly score based on daily scores
    int daysInCurrentYear;
    if (isThreeStateEnabled) {
      daysInCurrentYear = _countActiveDaysInRange(records, startOfYear, endDate);
      if (daysInCurrentYear == 0) daysInCurrentYear = 1;
    } else {
      daysInCurrentYear = endDate.difference(startOfYear).inDays + 1;
    }

    final yearlyDailyScores = dailyScores.entries
        .where(
            (entry) => entry.key.isAfter(startOfYear.subtract(const Duration(days: 1))) && !entry.key.isAfter(endDate))
        .map((entry) => entry.value);
    final yearlyTotalScore = yearlyDailyScores.fold(0.0, (sum, score) => sum + score);
    final yearlyScore = yearlyTotalScore / daysInCurrentYear;

    // Calculate monthly scores for the last 12 months using daily scores
    final monthlyScores = <MapEntry<DateTime, double>>[];
    for (var i = 11; i >= 0; i--) {
      final month = DateTime(endDate.year, endDate.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final monthEnd = i == 0 ? endDate : nextMonth.subtract(const Duration(days: 1));

      final monthlyDailyScoresForMonth = dailyScores.entries
          .where((entry) => !entry.key.isBefore(month) && !entry.key.isAfter(monthEnd))
          .map((entry) => entry.value);

      final monthTotalScore = monthlyDailyScoresForMonth.fold(0.0, (sum, score) => sum + score);

      int daysInMonth;
      if (isThreeStateEnabled) {
        daysInMonth = _countActiveDaysInRange(records, month, monthEnd);
        if (daysInMonth == 0) daysInMonth = 1; // Avoid division by zero if no records (score 0 anyway)
      } else {
        daysInMonth = monthEnd.difference(month).inDays + 1;
      }

      monthlyScores.add(MapEntry(month, monthTotalScore / daysInMonth));
    }

    // Calculate top streaks up to archive date if archived, using daily scores
    final streaks = _calculateStreaks(records,
        habit: habit, endDate: habit.archivedDate, dailyScores: dailyScores, isThreeStateEnabled: isThreeStateEnabled);
    final topStreaks = streaks.take(5).toList();

    // Calculate yearly frequency
    final yearlyFrequency = <int, int>{};

    for (final record in records) {
      if (record.status == HabitRecordStatus.complete) {
        final dayOfYear = record.recordDate.difference(DateTime(record.recordDate.year, 1, 1)).inDays;
        yearlyFrequency[dayOfYear] = (yearlyFrequency[dayOfYear] ?? 0) + 1;
      }
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
              record.status == HabitRecordStatus.complete &&
              !record.recordDate.isBefore(periodStart) &&
              !record.recordDate.isAfter(periodEnd))
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
      totalRecords: records.where((r) => r.status == HabitRecordStatus.complete).length,
      monthlyScores: monthlyScores,
      topStreaks: topStreaks,
      yearlyFrequency: yearlyFrequency,
      goalSuccessRate: goalSuccessRate,
      daysGoalMet: daysGoalMet,
      totalDaysWithGoal: totalDaysWithGoal,
    );
  }

  /// Counts the number of unique days with records matching the specified status
  /// within the given date range (inclusive).
  int _countActiveDaysInRange(List<HabitRecord> records, DateTime startDate, DateTime endDate) {
    return records
        .where((r) =>
            (r.status == HabitRecordStatus.complete || r.status == HabitRecordStatus.notDone) &&
            !r.recordDate.isBefore(startDate) &&
            !r.recordDate.isAfter(endDate))
        .map((r) => DateTime(r.recordDate.year, r.recordDate.month, r.recordDate.day))
        .toSet()
        .length;
  }

  List<HabitStreak> _calculateStreaks(List<HabitRecord> records,
      {required Habit habit,
      DateTime? endDate,
      required Map<DateTime, double> dailyScores,
      bool isThreeStateEnabled = false}) {
    if (records.isEmpty) return [];

    if (habit.hasGoal) {
      return _calculateGoalBasedStreaks(records, habit, endDate, dailyScores: dailyScores);
    } else {
      return _calculateConsecutiveDayStreaks(records, endDate,
          minDays: 2, dailyScores: dailyScores, habit: habit, isThreeStateEnabled: isThreeStateEnabled);
    }
  }

  List<HabitStreak> _calculateConsecutiveDayStreaks(List<HabitRecord> records, DateTime? endDate,
      {int minDays = 2,
      required Map<DateTime, double> dailyScores,
      required Habit habit,
      bool isThreeStateEnabled = false}) {
    if (dailyScores.isEmpty) return [];

    // Logic using daily scores - a day is complete if score >= 1.0
    final completeDays = dailyScores.entries.where((entry) => entry.value >= 1.0).map((entry) => entry.key).toList()
      ..sort();

    // Find explicit "Not Done" days
    final notDoneDays = records
        .where((r) => r.status == HabitRecordStatus.notDone)
        .map((r) => DateTime(r.recordDate.year, r.recordDate.month, r.recordDate.day))
        .toSet();

    if (completeDays.isEmpty) return [];

    final streaks = <HabitStreak>[];
    var streakStart = completeDays.first;
    var lastDate = streakStart;

    final isSingleTarget = (habit.dailyTarget ?? 1) == 1;

    for (var i = 1; i < completeDays.length; i++) {
      final currentDate = completeDays[i];
      bool broken = false;

      if (currentDate.difference(lastDate).inDays > 1) {
        // Gap detected
        if (isSingleTarget) {
          // Check if gap is "clean" (no NotDone records)
          // Gap spans from lastDate + 1 day to currentDate - 1 day
          var checkDate = lastDate.add(const Duration(days: 1));
          while (checkDate.isBefore(currentDate)) {
            // Strict mode (3-state disabled): Any gap (even untracked) breaks streak.
            // 3-state enabled: Only explicit "Not Done" breaks streak (Skip behavior).
            if (!isThreeStateEnabled) {
              broken = true;
              break;
            }

            if (notDoneDays.contains(checkDate)) {
              broken = true;
              break;
            }
            checkDate = checkDate.add(const Duration(days: 1));
          }
        } else {
          // Strict mode for multi-target: any gap breaks it
          broken = true;
        }

        if (broken) {
          // End of current streak
          if (endDate == null || !lastDate.isAfter(endDate)) {
            if (lastDate.difference(streakStart).inDays >= minDays - 1) {
              streaks.add(HabitStreak(
                startDate: streakStart,
                endDate: lastDate,
                days: isThreeStateEnabled
                    ? completeDays.where((d) => !d.isBefore(streakStart) && !d.isAfter(lastDate)).length
                    : lastDate.difference(streakStart).inDays + 1,
              ));
            }
          }
          streakStart = currentDate;
        }
      }
      lastDate = currentDate;
    }

    // Add the last streak if it exists and respects the end date
    if (lastDate.difference(streakStart).inDays >= minDays - 1 && (endDate == null || !lastDate.isAfter(endDate))) {
      streaks.add(HabitStreak(
        startDate: streakStart,
        endDate: lastDate,
        days: isThreeStateEnabled
            ? completeDays.where((d) => !d.isBefore(streakStart) && !d.isAfter(lastDate)).length
            : lastDate.difference(streakStart).inDays + 1,
      ));
    }

    // Sort by streak length
    streaks.sort((a, b) => b.days.compareTo(a.days));
    return streaks;
  }

  List<HabitStreak> _calculateGoalBasedStreaks(List<HabitRecord> records, Habit habit, DateTime? endDate,
      {required Map<DateTime, double> dailyScores}) {
    if (records.isEmpty) return [];

    final sortedRecords = records.toList()..sort((a, b) => a.recordDate.compareTo(b.recordDate));
    final streaks = <HabitStreak>[];

    // Calculate streaks based on goal periods
    var currentPeriodStart = sortedRecords.first.recordDate;
    var streakStart = currentPeriodStart;
    var consecutiveSuccessfulPeriods = 0;

    while (currentPeriodStart.isBefore(endDate ?? DateTime.now())) {
      final currentPeriodEnd = currentPeriodStart.add(Duration(days: habit.periodDays - 1));

      // Count complete days in current period (daily score >= 1.0)
      final completeDaysInPeriod = dailyScores.entries
          .where((entry) =>
              entry.value >= 1.0 &&
              !entry.key.isBefore(currentPeriodStart) &&
              entry.key.isBefore(currentPeriodEnd.add(const Duration(days: 1))))
          .length;

      final goalMet = completeDaysInPeriod >= habit.targetFrequency;

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
