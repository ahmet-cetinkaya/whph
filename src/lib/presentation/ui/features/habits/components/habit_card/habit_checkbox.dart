import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_progress.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';

class HabitCheckbox extends StatelessWidget {
  final HabitListItem habit;
  final List<HabitRecordListItem>? habitRecords;
  final HabitListStyle style;
  final DateTime? archivedDate;
  final VoidCallback onTap;

  const HabitCheckbox({
    super.key,
    required this.habit,
    required this.habitRecords,
    required this.style,
    required this.onTap,
    this.archivedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (habitRecords == null) {
      return const SizedBox(
        width: AppTheme.buttonSizeMedium,
        height: AppTheme.buttonSizeMedium,
      );
    }

    final today = DateTime.now();
    final isDisabled = _isDateDisabled(today);
    final hasRecordToday = _hasRecordForDate(today);
    final todayCount = _countRecordsForDate(today);
    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;
    final isMobileCalendar = AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);

    // Increase touch target sizes to match TaskCard (approx 36-40px)
    // For mobile calendar view, we want larger buttons despite being in compact layout
    final double buttonSize = isMobileCalendar ? 36.0 : HabitUiConstants.calendarDaySize;
    final double iconSize = AppTheme.iconSizeMedium;

    // For habits with custom goals and dailyTarget > 1, show completion badge
    if (hasCustomGoals && dailyTarget > 1) {
      return HabitProgress(
        currentCount: todayCount,
        dailyTarget: dailyTarget,
        isDisabled: isDisabled,
        onTap: onTap,
        useLargeSize: isMobileCalendar, // Use mobile calendar flag as proxy for large size preference
      );
    }

    final isSkipped = !hasRecordToday && _isSkipped(today);

    // For habits without custom goals, show traditional icon
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
        onPressed: isDisabled ? null : onTap,
        icon: Icon(
          hasRecordToday || isSkipped ? HabitUiConstants.recordIcon : Icons.close,
          size: iconSize,
          color: isDisabled
              ? AppTheme.textColor.withValues(alpha: 0.3)
              : hasRecordToday
                  ? Colors.green
                  : isSkipped
                      ? HabitUiConstants.skippedColor
                      : Colors.red,
        ),
      ),
    );
  }

  bool _isDateDisabled(DateTime date) {
    return date.isAfter(DateTime.now()) ||
        (archivedDate != null && date.isAfter(acore.DateTimeHelper.toLocalDateTime(archivedDate!)));
  }

  bool _hasRecordForDate(DateTime date) {
    if (habitRecords == null) return false;
    return habitRecords!.any((record) => acore.DateTimeHelper.isSameDay(
        acore.DateTimeHelper.toLocalDateTime(record.occurredAt), acore.DateTimeHelper.toLocalDateTime(date)));
  }

  int _countRecordsForDate(DateTime date) {
    if (habitRecords == null) return 0;
    return habitRecords!
        .where((record) => acore.DateTimeHelper.isSameDay(
            acore.DateTimeHelper.toLocalDateTime(record.occurredAt), acore.DateTimeHelper.toLocalDateTime(date)))
        .length;
  }

  bool _isSkipped(DateTime date) {
    if (!habit.hasGoal || habit.periodDays <= 1) {
      return false;
    }

    final targetFrequency = habit.targetFrequency;
    final periodDays = habit.periodDays;
    final dailyTarget = habit.dailyTarget ?? 1;

    // Calculate start of period relative to the given date
    // We look back (periodDays - 1) days to see if the goal is already met for the period ending on 'date'
    final periodStartDate = date.subtract(Duration(days: periodDays - 1));

    // Get all records within this window
    final recordsInPeriod = habitRecords?.where((record) {
          final recordDate = acore.DateTimeHelper.toLocalDateTime(record.occurredAt);
          final compareDate = DateTime(recordDate.year, recordDate.month, recordDate.day);
          final startDate = DateTime(periodStartDate.year, periodStartDate.month, periodStartDate.day);
          final endDate = DateTime(date.year, date.month, date.day);

          return !compareDate.isBefore(startDate) && !compareDate.isAfter(endDate);
        }).toList() ??
        [];

    // Group by date to check daily targets
    final recordsByDate = <DateTime, int>{};
    for (final record in recordsInPeriod) {
      final recordDate = acore.DateTimeHelper.toLocalDateTime(record.occurredAt);
      final dateKey = DateTime(recordDate.year, recordDate.month, recordDate.day);
      recordsByDate[dateKey] = (recordsByDate[dateKey] ?? 0) + 1;
    }

    // Count days that met the daily target
    int completedDaysInPeriod = 0;
    for (final count in recordsByDate.values) {
      if (count >= dailyTarget) {
        completedDaysInPeriod++;
      }
    }

    // If we've already met or exceeded the target frequency, this day is skippable/skipped
    return completedDaysInPeriod >= targetFrequency;
  }
}
