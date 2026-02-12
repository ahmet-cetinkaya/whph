import 'package:flutter/material.dart';
import 'package:application/features/habits/queries/get_list_habits_query.dart';
import 'package:application/features/habits/queries/get_list_habit_records_query.dart'; // For HabitRecordListItem
import 'package:domain/features/habits/habit_record_status.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/features/habits/components/habit_calendar_view/habit_calendar_color_helper.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/utils/app_theme_helper.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';

class HabitCardCalendar extends StatelessWidget {
  final HabitListItem habit;
  final List<HabitRecordListItem>? habitRecords;
  final int dateRange;
  final bool isDense;
  final bool isDateLabelShowing;
  final DateTime? archivedDate;
  final Function(DateTime) onDayTap;
  final IThemeService themeService;
  final bool isThreeStateEnabled;
  final bool isReverseDayOrder;

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
    this.isThreeStateEnabled = false,
    this.isReverseDayOrder = false,
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

    // Reverse to show Oldest -> Newest (Left -> Right) by default
    final orderedDays = isReverseDayOrder ? days : days.reversed.toList();

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
    final record = _getRecordForDate(date);
    final status = record?.status ?? HabitRecordStatus.skipped;
    final hasRecord = status == HabitRecordStatus.complete;

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

    final colorHelper = HabitCalendarColorHelper(
      hasGoal: hasCustomGoals,
      targetFrequency: habit.targetFrequency,
      periodDays: habit.periodDays,
      dailyTarget: dailyTarget,
    );

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
        if (hasRecord && status != HabitRecordStatus.notDone) {
          if (isDailyGoalMet && isPeriodGoalMet) {
            icon = HabitUiConstants.recordIcon;
            iconColor = Colors.green;
          } else if (isDailyGoalMet) {
            icon = HabitUiConstants.recordIcon;
            iconColor = Colors.green;
          } else {
            icon = Icons.add;
            iconColor = Colors.blue;
          }
        } else if (status == HabitRecordStatus.notDone) {
          icon = Icons.close;
          iconColor = Colors.red;
        } else if (isPeriodGoalMet) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.grey;
        } else if (periodCompletionCount > 0) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.orange;
        } else {
          // Skipped
          if (isThreeStateEnabled) {
            icon = Icons.question_mark;
            iconColor = Colors.grey;
          } else {
            icon = HabitUiConstants.noRecordIcon;
            iconColor = Colors.red;
          }
        }
      } else {
        // Period-based goal with daily target = 1
        if (hasRecord && status != HabitRecordStatus.notDone) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.green;
        } else if (status == HabitRecordStatus.notDone) {
          icon = Icons.close;
          iconColor = Colors.red;
        } else if (isPeriodGoalMet) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.grey; // Grey check for period satisfied
        } else if (periodCompletionCount > 0) {
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.orange;
        } else {
          // Skipped
          if (isThreeStateEnabled) {
            icon = Icons.question_mark;
            iconColor = Colors.grey;
          } else {
            icon = HabitUiConstants.noRecordIcon;
            iconColor = Colors.red.withValues(alpha: 0.7);
          }
        }
      }
    } else if (hasCustomGoals && dailyTarget > 1) {
      if (isDailyGoalMet) {
        icon = HabitUiConstants.recordIcon;
        iconColor = Colors.green;
      } else if (status == HabitRecordStatus.notDone) {
        icon = Icons.close;
        iconColor = Colors.red;
      } else if (dailyCompletionCount > 0) {
        icon = Icons.add;
        iconColor = Colors.blue;
      } else {
        // Skipped
        if (isThreeStateEnabled) {
          icon = Icons.question_mark;
          iconColor = Colors.grey;
        } else {
          icon = HabitUiConstants.noRecordIcon;
          iconColor = Colors.red.withValues(alpha: 0.7);
        }
      }
    } else {
      final isSkipped = status == HabitRecordStatus.skipped &&
          (_isSkipped(date) ||
              (hasCustomGoals && habit.periodDays > 1 && isPeriodGoalMet && dailyCompletionCount == 0));

      switch (status) {
        case HabitRecordStatus.complete:
          icon = HabitUiConstants.recordIcon;
          iconColor = Colors.green;
          break;
        case HabitRecordStatus.notDone:
          icon = Icons.close;
          iconColor = Colors.red;
          break;
        case HabitRecordStatus.skipped:
          if (isSkipped) {
            icon = HabitUiConstants.recordIcon;
            iconColor = HabitUiConstants.skippedColor;
          } else if (isThreeStateEnabled) {
            icon = Icons.question_mark;
            iconColor = Colors.grey;
          } else {
            icon = HabitUiConstants.noRecordIcon;
            iconColor = _getRecordStateColor(false, isDisabled);
          }
          break;
      }
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
      height: isDateLabelShowing
          ? (useLargeSize
              ? daySize * 1.5
              : (isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2))
          : daySize,
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
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        icon,
                        size: isMobileCalendar
                            ? AppTheme.iconSizeMedium
                            : (isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium),
                        color: iconColor,
                      ),
                    ),
                    if (hasCustomGoals &&
                        colorHelper.shouldShowBadge() &&
                        colorHelper.shouldShowBadgeForThisDay(
                          hasRecords: dailyCompletionCount > 0 || status != HabitRecordStatus.skipped,
                          isPeriodGoalMet: isPeriodGoalMet,
                          dailyCompletionCount: dailyCompletionCount,
                        ) &&
                        !isDisabled)
                      Positioned(
                        top: 1,
                        left: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorHelper.getBadgeColor(
                              isDailyGoalMet: isDailyGoalMet,
                              isPeriodGoalMet: isPeriodGoalMet,
                              hasRecords: dailyCompletionCount > 0 || status != HabitRecordStatus.skipped,
                              periodCompletionCount: periodCompletionCount,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            colorHelper.getBadgeText(
                              dailyCompletionCount: dailyCompletionCount,
                              periodCompletionCount: periodCompletionCount,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get record for a specific date
  HabitRecordListItem? _getRecordForDate(DateTime date) {
    if (habitRecords == null) return null;
    return habitRecords!
        .where((record) => acore.DateTimeHelper.isSameDay(
            acore.DateTimeHelper.toLocalDateTime(record.occurredAt), acore.DateTimeHelper.toLocalDateTime(date)))
        .firstOrNull;
  }

  // Helper method to check if a date is disabled for habit recording
  bool _isDateDisabled(DateTime date) {
    return date.isAfter(DateTime.now()) ||
        (archivedDate != null && date.isAfter(acore.DateTimeHelper.toLocalDateTime(archivedDate!)));
  }

  bool _isSkipped(DateTime date) {
    if (!habit.hasGoal || habit.periodDays <= 1) {
      return false;
    }

    final targetFrequency = habit.targetFrequency;
    final periodDays = habit.periodDays;
    final dailyTarget = habit.dailyTarget ?? 1;

    final periodStartDate = date.subtract(Duration(days: periodDays - 1));

    final recordsInPeriod = habitRecords?.where((record) {
          final recordDate = acore.DateTimeHelper.toLocalDateTime(record.occurredAt);
          final compareDate = DateTime(recordDate.year, recordDate.month, recordDate.day);
          final startDate = DateTime(periodStartDate.year, periodStartDate.month, periodStartDate.day);
          final endDate = DateTime(date.year, date.month, date.day);

          return !compareDate.isBefore(startDate) && !compareDate.isAfter(endDate);
        }).toList() ??
        [];

    final recordsByDate = <DateTime, int>{};
    for (final record in recordsInPeriod) {
      if (record.status != HabitRecordStatus.complete) continue;

      final recordDate = acore.DateTimeHelper.toLocalDateTime(record.occurredAt);
      final dateKey = DateTime(recordDate.year, recordDate.month, recordDate.day);
      recordsByDate[dateKey] = (recordsByDate[dateKey] ?? 0) + 1;
    }

    int completedDaysInPeriod = 0;
    for (final count in recordsByDate.values) {
      if (count >= dailyTarget) {
        completedDaysInPeriod++;
      }
    }

    return completedDaysInPeriod >= targetFrequency;
  }

  // Helper method to count records for a specific date
  int _countRecordsForDate(DateTime date) {
    if (habitRecords == null) return 0;
    return habitRecords!
        .where((record) =>
            record.status == HabitRecordStatus.complete &&
            acore.DateTimeHelper.isSameDay(
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
