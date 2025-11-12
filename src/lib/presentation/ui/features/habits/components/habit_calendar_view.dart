import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';

class HabitCalendarView extends StatefulWidget {
  final String habitId;
  final DateTime currentMonth;
  final List<HabitRecordListItem> records;
  final Function(String, DateTime) onCreateRecord;
  final Function(DateTime) onDeleteAllRecordsForDay;
  final Function() onPreviousMonth;
  final Function() onNextMonth;
  final VoidCallback? onRecordChanged;
  final DateTime? archivedDate;
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final int dailyTarget;

  const HabitCalendarView({
    super.key,
    required this.habitId,
    required this.currentMonth,
    required this.records,
    required this.onCreateRecord,
    required this.onDeleteAllRecordsForDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onRecordChanged,
    this.archivedDate,
    this.hasGoal = false,
    this.targetFrequency = 1,
    this.periodDays = 7,
    this.dailyTarget = 1,
  });

  @override
  State<HabitCalendarView> createState() => _HabitCalendarViewState();
}

class _HabitCalendarViewState extends State<HabitCalendarView> {
    final _soundManagerService = container.resolve<ISoundManagerService>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  @override
  void initState() {
    super.initState();
    _habitsService.onHabitRecordAdded.addListener(_handleRecordChange);
    _habitsService.onHabitRecordRemoved.addListener(_handleRecordChange);
  }

  @override
  void dispose() {
    _habitsService.onHabitRecordAdded.removeListener(_handleRecordChange);
    _habitsService.onHabitRecordRemoved.removeListener(_handleRecordChange);
    super.dispose();
  }

  void _handleRecordChange() {
    if (_habitsService.onHabitRecordAdded.value == widget.habitId ||
        _habitsService.onHabitRecordRemoved.value == widget.habitId) {
      widget.onRecordChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 600,
        child: Column(
          children: [
            _buildMonthNavigation(),
            const SizedBox(height: 8.0),
            _buildWeekdayLabels(),
            const SizedBox(height: 4.0),
            _buildMonthlyCalendar(),
          ],
        ),
      ),
    );
  }

  String _formatYearMonth(DateTime date) {
    final month = _translationService.translate(SharedTranslationKeys.getShortMonthKey(date.month));
    return '$month ${date.year}';
  }

  Widget _buildMonthNavigation() {
    final maxDate = widget.archivedDate ?? DateTime.now();
    final nextMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 1);
    final canGoNext = nextMonth.isBefore(maxDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(HabitUiConstants.previousIcon),
          onPressed: widget.onPreviousMonth,
        ),
        Text(
          _formatYearMonth(widget.currentMonth),
          style: AppTheme.bodyLarge,
        ),
        IconButton(
          icon: Icon(HabitUiConstants.nextIcon),
          onPressed: canGoNext ? widget.onNextMonth : null,
          color: canGoNext ? null : AppTheme.textColor.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    final List<String> weekDays = [
      _translationService.translate(HabitTranslationKeys.weekDayMon),
      _translationService.translate(HabitTranslationKeys.weekDayTue),
      _translationService.translate(HabitTranslationKeys.weekDayWed),
      _translationService.translate(HabitTranslationKeys.weekDayThu),
      _translationService.translate(HabitTranslationKeys.weekDayFri),
      _translationService.translate(HabitTranslationKeys.weekDaySat),
      _translationService.translate(HabitTranslationKeys.weekDaySun),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMonthlyCalendar() {
    // Calculate the days of the month
    int daysInMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0).day;
    int firstWeekdayOfMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month, 1).weekday;
    int previousMonthDays = firstWeekdayOfMonth - 1;

    // Calculate the days of the previous month
    DateTime firstDayOfPreviousMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month - 1, 1);
    int daysInPreviousMonth = DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month + 1, 0).day;

    // Calculate the days of the next month
    int lastWeekdayOfMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month, daysInMonth).weekday;
    int nextMonthDays = 7 - lastWeekdayOfMonth;

    List<DateTime> days = List.generate(daysInMonth + previousMonthDays + nextMonthDays, (index) {
      if (index < previousMonthDays) {
        return DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month,
            daysInPreviousMonth - previousMonthDays + index + 1);
      } else if (index >= previousMonthDays + daysInMonth) {
        return DateTime(
            widget.currentMonth.year, widget.currentMonth.month + 1, index - (previousMonthDays + daysInMonth) + 1);
      } else {
        return DateTime(widget.currentMonth.year, widget.currentMonth.month, index - previousMonthDays + 1);
      }
    });

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      mainAxisSpacing: HabitUiConstants.gridSpacing,
      crossAxisSpacing: HabitUiConstants.gridSpacing,
      children: days.map((date) => _buildCalendarDay(date)).toList(),
    );
  }

  Widget _buildCalendarDay(DateTime date) {
    final maxDate = widget.archivedDate ?? DateTime.now();
    bool isFutureDate = date.isAfter(maxDate);
    bool isCurrentMonth = date.month == widget.currentMonth.month;

    // Get daily completion count for this specific date
    final int dailyCompletionCount = widget.records.where((record) => _isSameDay(record.date, date)).length;
    final bool hasRecords = dailyCompletionCount > 0;
    final bool isDailyGoalMet = widget.hasGoal ? (dailyCompletionCount >= widget.dailyTarget) : hasRecords;

    // Calculate period-based progress for period goals
    int periodCompletionCount = 0;
    bool isPeriodGoalMet = false;
    if (widget.hasGoal && widget.periodDays > 1) {
      // Calculate the period window that contains this date
      final periodStart = _getPeriodStart(date, widget.periodDays);
      final periodEnd = DateTime(date.year, date.month, date.day);

      // Count completed daily targets in this period window
      Map<String, int> dailyRecordCounts = {};

      // Group records by date and count them
      for (final record in widget.records) {
        final recordDate = DateTime(record.date.year, record.date.month, record.date.day);
        if ((recordDate.isAfter(periodStart.subtract(const Duration(days: 1))) ||
                recordDate.isAtSameMomentAs(periodStart)) &&
            (recordDate.isBefore(periodEnd.add(const Duration(days: 1))) || recordDate.isAtSameMomentAs(periodEnd))) {
          final dateKey = '${recordDate.year}-${recordDate.month}-${recordDate.day}';
          dailyRecordCounts[dateKey] = (dailyRecordCounts[dateKey] ?? 0) + 1;
        }
      }

      // Count how many days met the daily target
      periodCompletionCount = dailyRecordCounts.values.where((count) => count >= widget.dailyTarget).length;

      isPeriodGoalMet = periodCompletionCount >= widget.targetFrequency;
    }

    // Determine background color based on goal type and achievement
    final backgroundColor = _getBackgroundColorForDay(
      isCurrentMonth: isCurrentMonth,
      isFutureDate: isFutureDate,
      hasRecords: hasRecords,
      isDailyGoalMet: isDailyGoalMet,
      isPeriodGoalMet: isPeriodGoalMet,
      dailyCompletionCount: dailyCompletionCount,
      periodCompletionCount: periodCompletionCount,
    );

    // Determine border color based on state
    Color borderColor = AppTheme.dividerColor.withValues(alpha: 0.3);
    if (!isCurrentMonth) {
      borderColor = AppTheme.dividerColor.withValues(alpha: 0.1);
    }
    if (isFutureDate) {
      borderColor = AppTheme.dividerColor.withValues(alpha: 0.1);
    }

    return OutlinedButton(
      onPressed: isFutureDate
          ? null
          : () async {
              if (widget.hasGoal) {
                // Custom goal behavior - use daily target logic
                if (dailyCompletionCount > 0 && dailyCompletionCount >= widget.dailyTarget) {
                  // If daily goal is met, remove ALL records for this day (reset to 0)
                  await widget.onDeleteAllRecordsForDay(date);
                  _soundManagerService.playHabitCompletion();
                } else {
                  // Add a new record
                  await widget.onCreateRecord(widget.habitId, date);
                  _soundManagerService.playHabitCompletion();
                }
              } else {
                // Simple habit behavior - remove ALL records for this day
                // (handles case where multiple records exist from when custom goals were enabled)
                if (hasRecords) {
                  // Remove ALL records for this day
                  await widget.onDeleteAllRecordsForDay(date);
                } else {
                  // Add a new record
                  await widget.onCreateRecord(widget.habitId, date);
                  _soundManagerService.playHabitCompletion();
                }
              }
              widget.onRecordChanged?.call();
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor:
            isCurrentMonth ? AppTheme.surface2.withValues(alpha: 0.3) : AppTheme.surface2.withValues(alpha: 0.1),
        padding: EdgeInsets.zero,
        side: BorderSide(
          color: borderColor,
          width: 1.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Stack(
        children: [
          // Main icon in center
          Center(
            child: isFutureDate
                ? Icon(
                    Icons.close,
                    color: Colors.grey.withValues(alpha: 0.3),
                    size: 16,
                  )
                : widget.hasGoal
                    ? _buildGoalIcon(
                        isDailyGoalMet, isPeriodGoalMet, dailyCompletionCount, periodCompletionCount, hasRecords)
                    : (hasRecords
                        ? const Icon(Icons.link, color: Colors.green, size: 20)
                        : const Icon(Icons.close, color: Colors.red, size: 16)),
          ),
          // Count badge for goals (daily targets or period frequency)
          if (widget.hasGoal &&
              _shouldShowBadge() &&
              _shouldShowBadgeForThisDay(hasRecords, isPeriodGoalMet, dailyCompletionCount) &&
              isCurrentMonth &&
              !isFutureDate)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _getBadgeColor(isDailyGoalMet, isPeriodGoalMet, hasRecords, periodCompletionCount),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getBadgeText(dailyCompletionCount, periodCompletionCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Day number
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              date.day.toString(),
              style: TextStyle(
                color: AppTheme.textColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  /// Calculate the start date of the period that contains the given date
  DateTime _getPeriodStart(DateTime date, int periodDays) {
    // Use a simple rolling window: each day looks back periodDays-1 days
    // This ensures every day belongs to a period window
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: periodDays - 1));
  }

  /// Build appropriate icon based on goal type and completion status
  Widget _buildGoalIcon(
      bool isDailyGoalMet, bool isPeriodGoalMet, int dailyCompletionCount, int periodCompletionCount, bool hasRecords) {
    // Handle different goal types
    if (widget.periodDays > 1) {
      // Period-based frequency behavior
      if (widget.dailyTarget > 1) {
        // Both daily target AND period goal
        if (hasRecords) {
          if (isDailyGoalMet) {
            // Daily goal met - show green link
            return const Icon(Icons.link, color: Colors.green, size: 20);
          } else {
            // Has records but daily goal not met - show blue plus
            return const Icon(Icons.add, color: Colors.blue, size: 18);
          }
        } else if (isPeriodGoalMet) {
          // Period goal met but no records today - show gray link
          return Icon(Icons.link, color: Colors.grey.withValues(alpha: 0.6), size: 18);
        } else if (periodCompletionCount > 0) {
          // Period has progress - show orange link
          return const Icon(Icons.link, color: Colors.orange, size: 18);
        } else {
          return const Icon(Icons.close, color: Colors.red, size: 16);
        }
      } else {
        // Period-based goal with daily target = 1
        if (hasRecords) {
          // This day has records - show green link (actually completed)
          return const Icon(Icons.link, color: Colors.green, size: 20);
        } else if (isPeriodGoalMet) {
          // Period goal is met but this day has no records - show gray link icon
          return Icon(Icons.link, color: Colors.grey.withValues(alpha: 0.6), size: 18);
        } else if (periodCompletionCount > 0) {
          // Show partial progress in period (other days in period have records)
          return const Icon(Icons.link, color: Colors.orange, size: 18);
        } else {
          return const Icon(Icons.close, color: Colors.red, size: 16);
        }
      }
    } else if (widget.dailyTarget > 1) {
      // Daily target behavior only (no period goal)
      if (isDailyGoalMet) {
        return const Icon(Icons.link, color: Colors.green, size: 20);
      } else if (dailyCompletionCount > 0) {
        return const Icon(Icons.add, color: Colors.blue, size: 18);
      } else {
        return const Icon(Icons.close, color: Colors.red, size: 16);
      }
    } else {
      // Simple daily goal behavior (1 time per day)
      if (hasRecords) {
        return const Icon(Icons.link, color: Colors.green, size: 20);
      } else {
        return const Icon(Icons.close, color: Colors.red, size: 16);
      }
    }
  }

  /// Determine if badge should be shown
  bool _shouldShowBadge() {
    // Show badge for daily targets > 1 (multiple times per day)
    // Also show for period goals when there's meaningful progress to display
    return widget.dailyTarget > 1 || (widget.periodDays > 1 && widget.targetFrequency > 1);
  }

  /// Determine if badge should be shown for this specific day
  bool _shouldShowBadgeForThisDay(bool hasRecords, bool isPeriodGoalMet, int dailyCompletionCount) {
    // Don't show badge if there's no daily progress
    if (dailyCompletionCount == 0) {
      return false;
    }

    if (widget.periodDays > 1) {
      // Period-based goals
      if (widget.dailyTarget > 1) {
        // Both daily target AND period goal
        // Only show badge on days with records (not on "satisfied" period days)
        return hasRecords;
      } else {
        // Period-based frequency behavior only
        // Show badge when there's meaningful progress to display
        return true;
      }
    } else {
      // Daily target only - always show when applicable
      return true;
    }
  }

  /// Get appropriate badge color based on goal type and completion status
  Color _getBadgeColor(bool isDailyGoalMet, bool isPeriodGoalMet, bool hasRecords, int periodCompletionCount) {
    if (widget.periodDays > 1) {
      // Period-based goals
      if (widget.dailyTarget > 1) {
        // Both daily target AND period goal - prioritize daily target for badge color
        return isDailyGoalMet
            ? Colors.green
            : hasRecords
                ? Colors.orange
                : Colors.red.withValues(alpha: 0.7);
      } else {
        // Period-based frequency behavior only
        return isPeriodGoalMet
            ? Colors.green
            : periodCompletionCount > 0
                ? Colors.orange
                : Colors.red.withValues(alpha: 0.7);
      }
    } else if (widget.dailyTarget > 1) {
      // Daily target behavior only
      return isDailyGoalMet
          ? Colors.green
          : hasRecords
              ? Colors.orange
              : Colors.red.withValues(alpha: 0.7);
    }
    return Colors.grey;
  }

  /// Get appropriate badge text based on goal type
  String _getBadgeText(int dailyCompletionCount, int periodCompletionCount) {
    if (widget.periodDays > 1) {
      // Period-based goals
      if (widget.dailyTarget > 1) {
        // Both daily target AND period goal - show daily count (more immediate feedback)
        return '$dailyCompletionCount';
      } else {
        // Period-based frequency behavior only - show period count
        return '$periodCompletionCount';
      }
    } else if (widget.dailyTarget > 1) {
      // Daily target behavior only - show daily count
      return '$dailyCompletionCount';
    }
    return '0';
  }

  /// Get background color for calendar day based on goal type and achievement
  Color _getBackgroundColorForDay({
    required bool isCurrentMonth,
    required bool isFutureDate,
    required bool hasRecords,
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
  }) {
    if (isFutureDate) {
      return AppTheme.surface1;
    }

    if (!isCurrentMonth) {
      return AppTheme.surface1.withValues(alpha: 0.5);
    }

    if (widget.hasGoal) {
      return _getGoalBasedBackgroundColor(
        hasRecords: hasRecords,
        isDailyGoalMet: isDailyGoalMet,
        isPeriodGoalMet: isPeriodGoalMet,
        dailyCompletionCount: dailyCompletionCount,
        periodCompletionCount: periodCompletionCount,
      );
    } else {
      return _getSimpleHabitBackgroundColor(hasRecords);
    }
  }

  /// Get background color for habits with goals
  Color _getGoalBasedBackgroundColor({
    required bool hasRecords,
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
  }) {
    if (widget.periodDays > 1) {
      return _getPeriodGoalBackgroundColor(
        hasRecords: hasRecords,
        isDailyGoalMet: isDailyGoalMet,
        isPeriodGoalMet: isPeriodGoalMet,
        dailyCompletionCount: dailyCompletionCount,
        periodCompletionCount: periodCompletionCount,
      );
    } else if (widget.dailyTarget > 1) {
      return _getDailyTargetBackgroundColor(
        hasRecords: hasRecords,
        isDailyGoalMet: isDailyGoalMet,
        dailyCompletionCount: dailyCompletionCount,
      );
    } else {
      return _getSimpleDailyGoalBackgroundColor(hasRecords);
    }
  }

  /// Get background color for period-based goals
  Color _getPeriodGoalBackgroundColor({
    required bool hasRecords,
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
  }) {
    if (widget.dailyTarget > 1) {
      // Both daily target AND period goal
      if (isDailyGoalMet && isPeriodGoalMet) {
        return Colors.green.withValues(alpha: 0.2);
      } else if (isDailyGoalMet) {
        return Colors.green.withValues(alpha: 0.15);
      } else if (isPeriodGoalMet) {
        return Colors.green.withValues(alpha: 0.1);
      } else if (hasRecords) {
        final double dailyProgress = dailyCompletionCount / widget.dailyTarget;
        return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.2), dailyProgress) ??
            Colors.red.withValues(alpha: 0.1);
      } else if (periodCompletionCount > 0) {
        final double periodProgress = periodCompletionCount / widget.targetFrequency;
        return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.15), periodProgress) ??
            Colors.red.withValues(alpha: 0.1);
      } else {
        return Colors.red.withValues(alpha: 0.05);
      }
    } else {
      // Period-based goal with daily target = 1
      if (isPeriodGoalMet) {
        return Colors.green.withValues(alpha: 0.2);
      } else if (periodCompletionCount > 0) {
        final double periodProgress = periodCompletionCount / widget.targetFrequency;
        return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.15), periodProgress) ??
            Colors.red.withValues(alpha: 0.1);
      } else {
        return Colors.red.withValues(alpha: 0.05);
      }
    }
  }

  /// Get background color for daily target goals
  Color _getDailyTargetBackgroundColor({
    required bool hasRecords,
    required bool isDailyGoalMet,
    required int dailyCompletionCount,
  }) {
    if (isDailyGoalMet) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (hasRecords) {
      final double dailyProgress = dailyCompletionCount / widget.dailyTarget;
      return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.2), dailyProgress) ??
          Colors.red.withValues(alpha: 0.1);
    } else {
      return Colors.red.withValues(alpha: 0.05);
    }
  }

  /// Get background color for simple daily goals
  Color _getSimpleDailyGoalBackgroundColor(bool hasRecords) {
    return hasRecords ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.05);
  }

  /// Get background color for simple habits without goals
  Color _getSimpleHabitBackgroundColor(bool hasRecords) {
    return hasRecords ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.05);
  }
}
