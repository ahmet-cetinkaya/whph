import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/application/features/habits/constants/habit_translation_keys.dart';

class GetHabitQuery implements IRequest<GetHabitQueryResponse> {
  late String? id;

  GetHabitQuery({this.id});
}

class HabitHabitListItem {
  String id;
  String name;

  HabitHabitListItem({
    required this.id,
    required this.name,
  });
}

class HabitStreak {
  final DateTime startDate;
  final DateTime endDate;
  final int days;

  HabitStreak({
    required this.startDate,
    required this.endDate,
    required this.days,
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

  HabitStatistics({
    required this.overallScore,
    required this.monthlyScore,
    required this.yearlyScore,
    required this.totalRecords,
    required this.monthlyScores,
    required this.topStreaks,
    required this.yearlyFrequency,
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
    List<int> reminderDays = const [],
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
      throw BusinessException(HabitTranslationKeys.habitNotFoundError);
    }

    // Get all records for statistics calculation using pagination
    final records = await _getAllHabitRecords(habit.id);
    final habitRecords = records.where((r) => r.deletedDate == null).toList();

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
        DateTime(1970),
        DateTime.now(),
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
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    // Calculate overall score based on first record date
    var overallScore = 0.0;
    if (records.isNotEmpty) {
      final sortedRecords = records.toList()..sort((a, b) => a.date.compareTo(b.date));
      final firstRecordDate = sortedRecords.first.date;
      final daysFromFirstRecord = now.difference(firstRecordDate).inDays + 1;
      overallScore = records.length / daysFromFirstRecord;
    }

    // Calculate monthly score
    final daysInCurrentMonth = now.difference(startOfMonth).inDays + 1;
    final monthlyRecords =
        records.where((r) => r.date.isAfter(startOfMonth) || _isSameDay(r.date, startOfMonth)).length;
    final monthlyScore = monthlyRecords / daysInCurrentMonth;

    // Calculate yearly score
    final daysInCurrentYear = now.difference(startOfYear).inDays + 1;
    final yearlyRecords = records.where((r) => r.date.isAfter(startOfYear) || _isSameDay(r.date, startOfYear)).length;
    final yearlyScore = yearlyRecords / daysInCurrentYear;

    // Calculate monthly scores for the last 12 months
    final monthlyScores = <MapEntry<DateTime, double>>[];
    for (var i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final monthRecords = records.where((r) => r.date.isAfter(month) && r.date.isBefore(nextMonth)).length;
      final daysInMonth = nextMonth.difference(month).inDays;
      monthlyScores.add(MapEntry(month, monthRecords / daysInMonth));
    }

    // Calculate top streaks
    final streaks = _calculateStreaks(records);
    final topStreaks = streaks.take(5).toList();

    // Calculate yearly frequency
    final yearlyFrequency = <int, int>{};
    for (final record in records) {
      final dayOfYear = record.date.difference(DateTime(record.date.year, 1, 1)).inDays;
      yearlyFrequency[dayOfYear] = (yearlyFrequency[dayOfYear] ?? 0) + 1;
    }

    return HabitStatistics(
      overallScore: overallScore,
      monthlyScore: monthlyScore,
      yearlyScore: yearlyScore,
      totalRecords: records.length,
      monthlyScores: monthlyScores,
      topStreaks: topStreaks,
      yearlyFrequency: yearlyFrequency,
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  List<HabitStreak> _calculateStreaks(List<HabitRecord> records) {
    if (records.isEmpty) return [];

    final sortedRecords = records.toList()..sort((a, b) => a.date.compareTo(b.date));

    final streaks = <HabitStreak>[];
    var streakStart = sortedRecords.first.date;
    var lastDate = streakStart;

    for (var i = 1; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      if (record.date.difference(lastDate).inDays > 1) {
        if (lastDate.difference(streakStart).inDays >= 2) {
          streaks.add(HabitStreak(
            startDate: streakStart,
            endDate: lastDate,
            days: lastDate.difference(streakStart).inDays + 1,
          ));
        }
        streakStart = record.date;
      }
      lastDate = record.date;
    }

    // Add the last streak if it exists
    if (lastDate.difference(streakStart).inDays >= 2) {
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
}
