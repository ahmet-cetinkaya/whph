import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart'; // For HabitRecordListItem
import 'package:acore/acore.dart' as acore;
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

class HabitCardCalendar extends StatelessWidget {
  final HabitListItem habit;
  final List<HabitRecordListItem>? habitRecords;
  final int dateRange;
  final bool isDense;
  final bool isDateLabelShowing;
  final DateTime? archivedDate;
  final Function(DateTime) onDayTap;
  final IThemeService themeService;

  const HabitCardCalendar({
    super.key,
    required this.habit,
    required this.habitRecords,
    required this.dateRange,
    required this.isDense,
    required this.isDateLabelShowing,
    required this.onDayTap,
    required this.themeService,
    this.archivedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (habitRecords == null) {
      return const SizedBox(
        width: AppTheme.calendarDayWidth,
        height: AppTheme.calendarDayHeight,
        child: SizedBox.shrink(),
      );
    }

    final referenceDate = archivedDate != null ? acore.DateTimeHelper.toLocalDateTime(archivedDate!) : DateTime.now();

    // Generate days (Today, Yesterday, ...)
    final days = List.generate(
      dateRange,
      (index) => referenceDate.subtract(Duration(days: index)),
    );

    // Reverse to show Oldest -> Newest (Left -> Right) to match typical calendar flow
    final orderedDays = days.reversed.toList();

    final dayWidgets = <Widget>[];
    for (int i = 0; i < orderedDays.length; i++) {
      if (i > 0) dayWidgets.add(const SizedBox(width: HabitUiConstants.calendarDaySpacing));
      dayWidgets.add(_buildCalendarDay(context, orderedDays[i]));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: dayWidgets,
    );
  }

  Widget _buildCalendarDay(BuildContext context, DateTime date) {
    final isDisabled = _isDateDisabled(date);
    final localDate = acore.DateTimeHelper.toLocalDateTime(date);
    final isToday = acore.DateTimeHelper.isSameDay(localDate, DateTime.now());
    final hasRecord = _hasRecordForDate(date);

    // Support for daily targets
    final dailyCompletionCount = _countRecordsForDate(date);
    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;
    final isDailyGoalMet = hasCustomGoals ? (dailyCompletionCount >= dailyTarget) : hasRecord;

    // Calculate period-based progress for period goals
    int periodCompletionCount = 0;
    bool isPeriodGoalMet = false;

    if (hasCustomGoals && habit.periodDays > 1) {
      // Calculate the period window that contains this date
      final periodStart = _getPeriodStart(date, habit.periodDays);
      final periodEnd = DateTime(date.year, date.month, date.day);

      // Count completed daily targets in this period window
      Map<String, int> dailyRecordCounts = {};

      // Group records by date and count them
      if (habitRecords != null) {
        for (final record in habitRecords!) {
          final recordDate = DateTime(
              acore.DateTimeHelper.toLocalDateTime(record.occurredAt).year,
              acore.DateTimeHelper.toLocalDateTime(record.occurredAt).month,
              acore.DateTimeHelper.toLocalDateTime(record.occurredAt).day);

          if ((recordDate.isAfter(periodStart.subtract(const Duration(days: 1))) ||
                  recordDate.isAtSameMomentAs(periodStart)) &&
              (recordDate.isBefore(periodEnd.add(const Duration(days: 1))) || recordDate.isAtSameMomentAs(periodEnd))) {
            final dateKey = '${recordDate.year}-${recordDate.month}-${recordDate.day}';
            dailyRecordCounts[dateKey] = (dailyRecordCounts[dateKey] ?? 0) + 1;
          }
        }
      }

      // Count how many days met the daily target
      periodCompletionCount = dailyRecordCounts.values.where((count) => count >= dailyTarget).length;
      isPeriodGoalMet = periodCompletionCount >= habit.targetFrequency;
    }

    // Determine icon based on completion state
    IconData icon;
    Color iconColor;

    if (isDisabled) {
      icon = HabitUiConstants.noRecordIcon;
      iconColor = AppTheme.textColor.withValues(alpha: 0.3);
    } else if (hasCustomGoals && habit.periodDays > 1) {
      // Period-based frequency behavior
      if (dailyTarget > 1) {
        // Both daily target AND period goal
        if (isDailyGoalMet && isPeriodGoalMet) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.green;
        } else if (isDailyGoalMet) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.green;
        } else if (isPeriodGoalMet && dailyCompletionCount == 0) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.grey;
        } else if (dailyCompletionCount > 0) {
          icon = Icons.add;
          iconColor = Colors.blue;
        } else {
          icon = HabitUiConstants.noRecordIcon;
          iconColor = Colors.red.withValues(alpha: 0.7);
        }
      } else {
        // Period-based goal with daily target = 1
        if (isPeriodGoalMet && dailyCompletionCount == 0) {
          // Period goal is met and this day has no record - show satisfied state with link icon
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.grey.withValues(alpha: 0.5);
        } else if (hasRecord) {
          // This day has a record - show completed
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.green;
        } else {
          // Period goal not met and this day has no record - show incomplete
          icon = HabitUiConstants.noRecordIcon;
          iconColor = Colors.red.withValues(alpha: 0.7);
        }
      }
    } else if (hasCustomGoals && dailyTarget > 1) {
      if (isDailyGoalMet) {
        icon = HabitUiConstants.recordIcon;
        iconColor = Colors.green;
      } else if (dailyCompletionCount > 0) {
        icon = Icons.add;
        iconColor = Colors.blue;
      } else {
        icon = HabitUiConstants.noRecordIcon;
        iconColor = Colors.red.withValues(alpha: 0.7);
      }
    } else {
      icon = hasRecord ? HabitUiConstants.recordIcon : HabitUiConstants.noRecordIcon;
      iconColor = _getRecordStateColor(hasRecord, isDisabled);
    }

    // Use passed context for screen size check, or pass isMobileCalendar as param
    // But passing context is fine here since it is build method context
    final isMobileCalendar = AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);

    // If mobile calendar, we want LARGE icons/buttons, overriding isDense
    final useLargeSize = !isDense || isMobileCalendar;

    // Day size should match HabitsPage header: 36.0 on Mobile, 46.0 (calendarDaySize) on Desktop
    final double daySize = isMobileCalendar ? 36.0 : HabitUiConstants.calendarDaySize;

    return SizedBox(
      width: daySize,
      height: useLargeSize
          ? daySize * 1.5
          : (isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDateLabelShowing) ...[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  acore.DateTimeHelper.getWeekday(localDate.weekday),
                  style: AppTheme.bodySmall.copyWith(
                    color: isToday
                        ? themeService.primaryColor
                        : AppTheme.textColor.withValues(alpha: isDisabled ? 0.5 : 1),
                  ),
                ),
              ),
            ),
            SizedBox(height: isDense ? 1 : 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  localDate.day.toString(),
                  style: AppTheme.bodySmall.copyWith(
                    color: isToday
                        ? themeService.primaryColor
                        : AppTheme.textColor.withValues(alpha: isDisabled ? 0.5 : 1),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
          SizedBox(
            width: daySize,
            height: daySize,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDisabled ? null : () => onDayTap(date),
                borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                child: Icon(
                  icon,
                  size: isMobileCalendar
                      ? AppTheme.iconSizeMedium
                      : (isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium),
                  color: iconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to check if a date is disabled for habit recording
  bool _isDateDisabled(DateTime date) {
    return date.isAfter(DateTime.now()) ||
        (archivedDate != null && date.isAfter(acore.DateTimeHelper.toLocalDateTime(archivedDate!)));
  }

  // Helper method to check if there's a record for a specific date
  bool _hasRecordForDate(DateTime date) {
    if (habitRecords == null) return false;
    return habitRecords!.any((record) => acore.DateTimeHelper.isSameDay(
        acore.DateTimeHelper.toLocalDateTime(record.occurredAt), acore.DateTimeHelper.toLocalDateTime(date)));
  }

  // Helper method to count records for a specific date
  int _countRecordsForDate(DateTime date) {
    if (habitRecords == null) return 0;
    return habitRecords!
        .where((record) => acore.DateTimeHelper.isSameDay(
            acore.DateTimeHelper.toLocalDateTime(record.occurredAt), acore.DateTimeHelper.toLocalDateTime(date)))
        .length;
  }

  // Helper method to calculate the start date of the period that contains the given date
  DateTime _getPeriodStart(DateTime date, int periodDays) {
    // Use a simple rolling window: each day looks back periodDays-1 days
    // This ensures every day belongs to a period window
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: periodDays - 1));
  }

  // Helper method to get the appropriate color for record state
  Color _getRecordStateColor(bool hasRecord, bool isDisabled) {
    if (isDisabled) {
      return AppTheme.textColor.withValues(alpha: 0.3);
    }
    return hasRecord ? HabitUiConstants.completedColor : HabitUiConstants.inCompletedColor;
  }
}
