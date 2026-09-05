import 'dart:collection';

import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';

enum HabitDayState { notApplicable, successful, failed, incomplete, partial }

typedef LocalDateTimeFactory = DateTime Function(int year, int month, int day);
typedef HabitDayRangeResolver = ({DateTime start, DateTime end}) Function(DateTime date);

class HabitDayStateResolver {
  const HabitDayStateResolver();

  static ({DateTime start, DateTime end}) utcRangeFor(
    DateTime date, {
    LocalDateTimeFactory localDateTime = DateTime.new,
  }) {
    final localDate = DateTimeHelper.toLocalDateTime(date);
    final start = localDateTime(localDate.year, localDate.month, localDate.day).toUtc();
    final nextStart = localDateTime(localDate.year, localDate.month, localDate.day + 1).toUtc();
    return (start: start, end: nextStart.subtract(const Duration(microseconds: 1)));
  }

  HabitDayStateSource createSource({
    required Habit habit,
    required Iterable<HabitRecord> records,
    required DateTime now,
  }) {
    return HabitDayStateSource._(
      habitType: habit.type,
      recordsByDay: _indexRecords(habit, records),
      creationDay: _LocalDay.from(habit.createdDate),
      archiveDay: habit.archivedDate == null ? null : _LocalDay.from(habit.archivedDate!),
      dailyTarget: habit.getDailyTarget(),
      today: _LocalDay.from(now),
    );
  }

  Map<_LocalDay, _DayRecordCounts> _indexRecords(
    Habit habit,
    Iterable<HabitRecord> records,
  ) {
    final recordsByDay = <_LocalDay, _DayRecordCounts>{};

    for (final record in records) {
      if (record.habitId != habit.id || record.deletedDate != null) continue;

      final day = _LocalDay.from(record.occurredAt);
      final counts = recordsByDay[day] ?? const _DayRecordCounts();
      recordsByDay[day] = counts.add(record.status);
    }

    return UnmodifiableMapView(recordsByDay);
  }
}

class HabitDayStateSource {
  final HabitType _habitType;
  final Map<_LocalDay, _DayRecordCounts> _recordsByDay;
  final _LocalDay _creationDay;
  final _LocalDay? _archiveDay;
  final int _dailyTarget;
  final _LocalDay _today;

  const HabitDayStateSource._({
    required HabitType habitType,
    required Map<_LocalDay, _DayRecordCounts> recordsByDay,
    required _LocalDay creationDay,
    required _LocalDay? archiveDay,
    required int dailyTarget,
    required _LocalDay today,
  })  : _habitType = habitType,
        _recordsByDay = recordsByDay,
        _creationDay = creationDay,
        _archiveDay = archiveDay,
        _dailyTarget = dailyTarget,
        _today = today;

  HabitDayState resolve(DateTime date) {
    final day = _LocalDay.from(date);
    if (!_isApplicable(day)) return HabitDayState.notApplicable;

    final records = _recordsByDay[day] ?? const _DayRecordCounts();
    return switch (_habitType) {
      HabitType.bad => records.notDoneCount > 0 ? HabitDayState.failed : HabitDayState.successful,
      HabitType.good => _resolveGoodHabit(records),
    };
  }

  bool _isApplicable(_LocalDay day) {
    final archiveDay = _archiveDay;

    return day.compareTo(_creationDay) >= 0 &&
        day.compareTo(_today) <= 0 &&
        (archiveDay == null || day.compareTo(archiveDay) <= 0);
  }

  HabitDayState _resolveGoodHabit(_DayRecordCounts records) {
    if (records.completeCount >= _dailyTarget) {
      return HabitDayState.successful;
    }
    if (records.completeCount > 0) return HabitDayState.partial;
    if (records.notDoneCount > 0) return HabitDayState.failed;
    return HabitDayState.incomplete;
  }
}

class _DayRecordCounts {
  final int completeCount;
  final int notDoneCount;

  const _DayRecordCounts({this.completeCount = 0, this.notDoneCount = 0});

  _DayRecordCounts add(HabitRecordStatus status) => switch (status) {
        HabitRecordStatus.complete => _DayRecordCounts(
            completeCount: completeCount + 1,
            notDoneCount: notDoneCount,
          ),
        HabitRecordStatus.notDone => _DayRecordCounts(
            completeCount: completeCount,
            notDoneCount: notDoneCount + 1,
          ),
        HabitRecordStatus.skipped => this,
      };
}

class _LocalDay implements Comparable<_LocalDay> {
  final int year;
  final int month;
  final int day;

  const _LocalDay(this.year, this.month, this.day);

  factory _LocalDay.from(DateTime date) {
    final localDate = DateTimeHelper.toLocalDateTime(date);
    return _LocalDay(localDate.year, localDate.month, localDate.day);
  }

  @override
  int compareTo(_LocalDay other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) return yearComparison;

    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) return monthComparison;

    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is _LocalDay && year == other.year && month == other.month && day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
