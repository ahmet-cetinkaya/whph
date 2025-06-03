import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/corePackages/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_sounds.dart';
import 'package:whph/src/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/habits/constants/habit_translation_keys.dart';

class HabitCalendarView extends StatefulWidget {
  final String habitId;
  final DateTime currentMonth;
  final List<HabitRecordListItem> records;
  final Function(String) onDeleteRecord;
  final Function(String, DateTime) onCreateRecord;
  final Function() onPreviousMonth;
  final Function() onNextMonth;
  final VoidCallback? onRecordChanged;
  final DateTime? archivedDate;
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;

  const HabitCalendarView({
    super.key,
    required this.habitId,
    required this.currentMonth,
    required this.records,
    required this.onDeleteRecord,
    required this.onCreateRecord,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onRecordChanged,
    this.archivedDate,
    this.hasGoal = false,
    this.targetFrequency = 1,
    this.periodDays = 7,
  });

  @override
  State<HabitCalendarView> createState() => _HabitCalendarViewState();
}

class _HabitCalendarViewState extends State<HabitCalendarView> {
  final _soundPlayer = container.resolve<ISoundPlayer>();
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
    bool hasRecord = widget.records.any((record) => _isSameDay(record.date, date));
    final maxDate = widget.archivedDate ?? DateTime.now();
    bool isFutureDate = date.isAfter(maxDate);
    bool isCurrentMonth = date.month == widget.currentMonth.month;

    // Get goal-related information
    final bool isGoalMet = _isGoalMet(date);
    final double goalCompletion = _getGoalCompletionPercentage(date);

    // Determine background color based on goal achievement (only for current month dates)
    Color backgroundColor = AppTheme.surface1;
    if (widget.hasGoal && isCurrentMonth && !isFutureDate) {
      if (isGoalMet) {
        backgroundColor = Colors.green.withValues(alpha: 0.2);
      } else if (goalCompletion > 0) {
        // Show a gradient from red to green based on completion percentage
        backgroundColor =
            Color.lerp(Colors.red.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.2), goalCompletion) ??
                Colors.red.withValues(alpha: 0.2);
      } else {
        backgroundColor = Colors.red.withValues(alpha: 0.1);
      }
    }

    // If it's not the current month, use a faded background
    if (!isCurrentMonth) {
      backgroundColor = AppTheme.surface1.withValues(alpha: 0.5);
    }

    HabitRecordListItem? recordForDay;
    if (hasRecord) {
      recordForDay = widget.records.firstWhere((record) => _isSameDay(record.date, date));
    }

    return ElevatedButton(
      onPressed: isFutureDate
          ? null
          : () async {
              if (hasRecord) {
                await widget.onDeleteRecord(recordForDay!.id);
                _soundPlayer.play(SharedSounds.done);
              } else {
                await widget.onCreateRecord(widget.habitId, date);
                _soundPlayer.play(SharedSounds.done);
              }
              widget.onRecordChanged?.call();
            },
      style: ElevatedButton.styleFrom(
        foregroundColor: AppTheme.textColor,
        backgroundColor: backgroundColor,
        disabledBackgroundColor:
            isCurrentMonth ? AppTheme.surface2.withValues(alpha: 0.3) : AppTheme.surface2.withValues(alpha: 0.1),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: hasRecord
                ? const Icon(Icons.check, color: Colors.green)
                : Icon(
                    widget.hasGoal && isGoalMet ? Icons.check : Icons.close,
                    color: isFutureDate
                        ? Colors.grey.withValues(alpha: 0.3)
                        : widget.hasGoal && isGoalMet
                            ? Colors.grey.withValues(alpha: 0.5)
                            : Colors.red,
                  ),
          ),
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              date.day.toString(),
              style: TextStyle(
                color: AppTheme.textColor.withValues(alpha: 0.5),
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

  // Calculate goal achievement for a specific date window
  int _getCompletedCountForPeriod(DateTime date) {
    if (!widget.hasGoal) return 0;

    // Calculate start and end dates for the period
    final DateTime periodEnd = date;
    final DateTime periodStart = date.subtract(Duration(days: widget.periodDays - 1));

    // Count records within the period
    return widget.records
        .where((record) =>
            record.date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
            record.date.isBefore(periodEnd.add(const Duration(days: 1))))
        .length;
  }

  // Check if goal is met for a given date
  bool _isGoalMet(DateTime date) {
    if (!widget.hasGoal) return true;
    final completedCount = _getCompletedCountForPeriod(date);
    return completedCount >= widget.targetFrequency;
  }

  // Get goal completion percentage for a given date
  double _getGoalCompletionPercentage(DateTime date) {
    if (!widget.hasGoal || widget.targetFrequency <= 0) return 1.0;

    final completedCount = _getCompletedCountForPeriod(date);
    final percentage = completedCount / widget.targetFrequency;

    // Cap at 100% even if overachieved
    return percentage > 1.0 ? 1.0 : percentage;
  }
}
