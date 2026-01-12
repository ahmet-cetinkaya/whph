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
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_calendar_view/habit_calendar_color_helper.dart';

class HabitCalendarView extends StatefulWidget {
  final String habitId;
  final DateTime currentMonth;
  final List<HabitRecordListItem> records;
  final Function(DateTime) onToggle;
  final Function() onPreviousMonth;
  final Function() onNextMonth;
  final VoidCallback? onRecordChanged;
  final DateTime? archivedDate;
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final int dailyTarget;
  final bool isThreeStateEnabled;

  const HabitCalendarView({
    super.key,
    required this.habitId,
    required this.currentMonth,
    required this.records,
    required this.onToggle,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onRecordChanged,
    this.archivedDate,
    this.hasGoal = false,
    this.targetFrequency = 1,
    this.periodDays = 7,
    this.dailyTarget = 1,
    this.isThreeStateEnabled = false,
  });

  @override
  State<HabitCalendarView> createState() => _HabitCalendarViewState();
}

class _HabitCalendarViewState extends State<HabitCalendarView> {
  final _soundManagerService = container.resolve<ISoundManagerService>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  late HabitCalendarColorHelper _colorHelper;

  @override
  void initState() {
    super.initState();
    _habitsService.onHabitRecordAdded.addListener(_handleRecordChange);
    _habitsService.onHabitRecordRemoved.addListener(_handleRecordChange);
    _updateColorHelper();
  }

  @override
  void didUpdateWidget(HabitCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasGoal != widget.hasGoal ||
        oldWidget.targetFrequency != widget.targetFrequency ||
        oldWidget.periodDays != widget.periodDays ||
        oldWidget.dailyTarget != widget.dailyTarget) {
      _updateColorHelper();
    }
  }

  void _updateColorHelper() {
    _colorHelper = HabitCalendarColorHelper(
      hasGoal: widget.hasGoal,
      targetFrequency: widget.targetFrequency,
      periodDays: widget.periodDays,
      dailyTarget: widget.dailyTarget,
    );
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
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: AppTheme.sizeLarge),
                _buildMonthNavigation(),
                const SizedBox(height: AppTheme.sizeMedium),
                _buildWeekdayLabels(),
                const SizedBox(height: AppTheme.sizeSmall),
                _buildMonthlyCalendar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
          ),
          child: Icon(
            Icons.calendar_month,
            size: AppTheme.iconSizeMedium,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppTheme.sizeMedium),
        Text(
          _translationService.translate(HabitTranslationKeys.recordsLabel),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
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
    int daysInMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0).day;
    int firstWeekdayOfMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month, 1).weekday;
    int previousMonthDays = firstWeekdayOfMonth - 1;

    DateTime firstDayOfPreviousMonth = DateTime(widget.currentMonth.year, widget.currentMonth.month - 1, 1);
    int daysInPreviousMonth = DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month + 1, 0).day;

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

    // Get daily records
    final dailyRecords = widget.records.where((record) => _isSameDay(record.date, date)).toList();

    // Status (use first record's status or Skipped)
    final HabitRecordStatus status = dailyRecords.firstOrNull?.status ?? HabitRecordStatus.skipped;

    // Only Complete counts towards goal
    final int dailyCompletionCount = dailyRecords.where((r) => r.status == HabitRecordStatus.complete).length;

    // hasRecords implies visually there is something.
    final bool hasRecords = dailyRecords.isNotEmpty;

    final bool isDailyGoalMet =
        widget.hasGoal ? (dailyCompletionCount >= widget.dailyTarget) : (status == HabitRecordStatus.complete);

    int periodCompletionCount = 0;
    bool isPeriodGoalMet = false;
    if (widget.hasGoal && widget.periodDays > 1) {
      final periodStart = _getPeriodStart(date, widget.periodDays);
      final periodEnd = DateTime(date.year, date.month, date.day);

      Map<String, int> dailyRecordCounts = {};
      for (final record in widget.records) {
        if (record.status != HabitRecordStatus.complete) continue;

        final recordDate = DateTime(record.date.year, record.date.month, record.date.day);
        if ((recordDate.isAfter(periodStart.subtract(const Duration(days: 1))) ||
                recordDate.isAtSameMomentAs(periodStart)) &&
            (recordDate.isBefore(periodEnd.add(const Duration(days: 1))) || recordDate.isAtSameMomentAs(periodEnd))) {
          final dateKey = '${recordDate.year}-${recordDate.month}-${recordDate.day}';
          dailyRecordCounts[dateKey] = (dailyRecordCounts[dateKey] ?? 0) + 1;
        }
      }
      periodCompletionCount = dailyRecordCounts.values.where((count) => count >= widget.dailyTarget).length;
      isPeriodGoalMet = periodCompletionCount >= widget.targetFrequency;
    }

    final backgroundColor = _colorHelper.getBackgroundColorForDay(
      isCurrentMonth: isCurrentMonth,
      isFutureDate: isFutureDate,
      hasRecords: hasRecords,
      isDailyGoalMet: isDailyGoalMet,
      isPeriodGoalMet: isPeriodGoalMet,
      dailyCompletionCount: dailyCompletionCount,
      periodCompletionCount: periodCompletionCount,
      status: status,
    );

    Color borderColor = AppTheme.dividerColor.withValues(alpha: 0.3);
    if (!isCurrentMonth) borderColor = AppTheme.dividerColor.withValues(alpha: 0.1);
    if (isFutureDate) borderColor = AppTheme.dividerColor.withValues(alpha: 0.1);

    return OutlinedButton(
      onPressed: isFutureDate ? null : () => _handleDayTap(date),
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor:
            isCurrentMonth ? AppTheme.surface2.withValues(alpha: 0.3) : AppTheme.surface2.withValues(alpha: 0.1),
        padding: EdgeInsets.zero,
        side: BorderSide(color: borderColor, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      child: Stack(
        children: [
          Center(
            child: isFutureDate
                ? Icon(Icons.close, color: Colors.grey.withValues(alpha: 0.3), size: 16)
                : widget.hasGoal
                    ? _colorHelper.buildGoalIcon(
                        isDailyGoalMet: isDailyGoalMet,
                        isPeriodGoalMet: isPeriodGoalMet,
                        dailyCompletionCount: dailyCompletionCount,
                        periodCompletionCount: periodCompletionCount,
                        hasRecords: hasRecords,
                        status: status,
                        isThreeStateEnabled: widget.isThreeStateEnabled,
                      )
                    : (status == HabitRecordStatus.complete
                        ? const Icon(Icons.link, color: Colors.green, size: 20)
                        : status == HabitRecordStatus.notDone
                            ? const Icon(Icons.close, color: Colors.red, size: 16)
                            : widget.isThreeStateEnabled
                                ? const Icon(Icons.question_mark, color: Colors.grey, size: 16) // Show ? if enabled
                                : const Icon(Icons.close, color: Colors.red, size: 16)), // Show X if disabled
          ),
          if (widget.hasGoal &&
              _colorHelper.shouldShowBadge() &&
              _colorHelper.shouldShowBadgeForThisDay(
                hasRecords: hasRecords,
                isPeriodGoalMet: isPeriodGoalMet,
                dailyCompletionCount: dailyCompletionCount,
              ) &&
              isCurrentMonth &&
              !isFutureDate)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _colorHelper.getBadgeColor(
                    isDailyGoalMet: isDailyGoalMet,
                    isPeriodGoalMet: isPeriodGoalMet,
                    hasRecords: hasRecords,
                    periodCompletionCount: periodCompletionCount,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _colorHelper.getBadgeText(
                    dailyCompletionCount: dailyCompletionCount,
                    periodCompletionCount: periodCompletionCount,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              date.day.toString(),
              style: TextStyle(color: AppTheme.textColor.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDayTap(DateTime date) async {
    await widget.onToggle(date);
    widget.onRecordChanged?.call();
    _soundManagerService.playHabitCompletion();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  DateTime _getPeriodStart(DateTime date, int periodDays) {
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: periodDays - 1));
  }
}
