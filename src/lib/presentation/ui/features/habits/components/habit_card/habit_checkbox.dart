import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_progress.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';

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
    final isMobileCalendar =
        style == HabitListStyle.calendar && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);
    final isCompactView = style != HabitListStyle.calendar || isMobileCalendar;

    // Increase touch target sizes to match TaskCard (approx 36-40px)
    // For mobile calendar view, we want larger buttons despite being in compact layout
    final useLargeSize = !isCompactView || isMobileCalendar;
    final double buttonSize = useLargeSize ? 36.0 : AppTheme.buttonSizeMedium;
    final double iconSize = useLargeSize ? 24.0 : AppTheme.iconSizeMedium;

    // For habits with custom goals and dailyTarget > 1, show completion badge
    if (hasCustomGoals && dailyTarget > 1) {
      return HabitProgress(
        currentCount: todayCount,
        dailyTarget: dailyTarget,
        isDisabled: isDisabled,
        onTap: onTap,
        useLargeSize: useLargeSize,
      );
    }

    // For habits without custom goals, show traditional icon
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
        onPressed: isDisabled ? null : onTap,
        icon: Icon(
          hasRecordToday ? Icons.link : Icons.close,
          size: iconSize,
          color: isDisabled
              ? AppTheme.textColor.withValues(alpha: 0.3)
              : hasRecordToday
                  ? Colors.green
                  : Colors.red.withValues(alpha: 0.7),
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
}
