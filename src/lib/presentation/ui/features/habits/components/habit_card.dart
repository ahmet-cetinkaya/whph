import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/services/habit_completion_service.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final void Function(AddHabitRecordCommandResponse)? onRecordCreated;
  final void Function(DeleteHabitRecordCommandResponse)? onRecordDeleted;
  final bool isMiniLayout;
  final bool isDateLabelShowing;
  final int dateRange;
  final bool isDense;
  final bool showDragHandle;
  final int? dragIndex;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onOpenDetails,
    this.onRecordCreated,
    this.onRecordDeleted,
    this.isMiniLayout = false,
    this.isDateLabelShowing = true,
    this.dateRange = 7,
    this.isDense = false,
    this.showDragHandle = false,
    this.dragIndex,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  final _mediator = container.resolve<Mediator>();
  final _soundPlayer = container.resolve<acore.ISoundPlayer>();
  final _habitsService = container.resolve<HabitsService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _completionService = container.resolve<HabitCompletionService>();
  GetListHabitRecordsQueryResponse? _habitRecords;

  @override
  void initState() {
    super.initState();
    _getHabitRecords();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChange);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChange);
  }

  void _removeEventListeners() {
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChange);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChange);
  }

  void _handleHabitRecordChange() {
    if (!mounted) return;

    // Check if the event is for this specific habit
    final addedHabitId = _habitsService.onHabitRecordAdded.value;
    final removedHabitId = _habitsService.onHabitRecordRemoved.value;

    if (addedHabitId == widget.habit.id || removedHabitId == widget.habit.id) {
      _refreshHabitRecords();
    }
  }

  Future<void> _getHabitRecords() async {
    await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        final endDate = widget.habit.archivedDate ?? DateTime.now();
        // Calculate appropriate page size to handle multiple daily occurrences
        final dailyTarget = widget.habit.hasGoal ? (widget.habit.dailyTarget ?? 1) : 1;
        final daysToShow = widget.isMiniLayout ? 1 : widget.dateRange;

        // For period-based habits, we need to fetch enough data to calculate period completion
        // This ensures we have data for the full period window that might affect the displayed days
        final periodDays = widget.habit.hasGoal ? widget.habit.periodDays : 1;
        final daysToFetch = daysToShow + (periodDays > 1 ? periodDays - 1 : 0);

        final pageSize =
            daysToFetch * (dailyTarget > 1 ? dailyTarget * 2 : 10); // Allow for more records than the target

        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: pageSize,
          habitId: widget.habit.id,
          startDate: acore.DateTimeHelper.toUtcDateTime(endDate.subtract(Duration(days: daysToFetch))),
          endDate: acore.DateTimeHelper.toLocalDateTime(endDate),
        );
        return await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
      },
      onSuccess: (response) {
        if (mounted) {
          setState(() {
            _habitRecords = response;
          });
        }
      },
    );
  }

  // Helper method to refresh habit records state
  Future<void> _refreshHabitRecords() async {
    if (mounted) {
      await _getHabitRecords();
    }
  }

  // Helper method to check if a date is disabled for habit recording
  bool _isDateDisabled(DateTime date) {
    return date.isAfter(DateTime.now()) ||
        (widget.habit.archivedDate != null &&
            date.isAfter(acore.DateTimeHelper.toLocalDateTime(widget.habit.archivedDate!)));
  }

  // Helper method to check if there's a record for a specific date
  bool _hasRecordForDate(DateTime date) {
    if (_habitRecords == null) return false;
    return _habitRecords!.items.any((record) => acore.DateTimeHelper.isSameDay(
        acore.DateTimeHelper.toLocalDateTime(record.occurredAt), acore.DateTimeHelper.toLocalDateTime(date)));
  }

  // Helper method to count records for a specific date
  int _countRecordsForDate(DateTime date) {
    if (_habitRecords == null) return 0;
    return _habitRecords!.items
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

  // Event handler for calendar day tap
  Future<void> _onCalendarDayTap(DateTime date) async {
    if (_habitRecords == null) return;

    await _completionService.toggleHabitCompletion(
      habit: widget.habit,
      date: date,
      habitRecords: _habitRecords!,
      deleteRecord: _deleteHabitRecord,
      createRecord: _createHabitRecord,
    );
  }

  // Event handler for checkbox tap with smart logic for multiple occurrences
  Future<void> _onCheckboxTap() async {
    if (_habitRecords == null) return;

    final today = DateTime.now();
    await _completionService.toggleHabitCompletion(
      habit: widget.habit,
      date: today,
      habitRecords: _habitRecords!,
      deleteRecord: _deleteHabitRecord,
      createRecord: _createHabitRecord,
      useIncrementalBehavior: true, // Checkbox uses incremental behavior
    );
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = AddHabitRecordCommand(habitId: habitId, occurredAt: acore.DateTimeHelper.toUtcDateTime(date));
        final response = await _mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);

        await _refreshHabitRecords();

        // Notify service that a record was added
        _habitsService.notifyHabitRecordAdded(habitId);
        widget.onRecordCreated?.call(response);
        _soundPlayer.play(SharedSounds.done, volume: 1.0);
      },
    );
  }

  Future<void> _deleteHabitRecord(String id) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.deletingRecordError),
      operation: () async {
        final command = DeleteHabitRecordCommand(id: id);
        final response = await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);

        await _refreshHabitRecords();

        // Notify service that a record was removed
        _habitsService.notifyHabitRecordRemoved(widget.habit.id);
        widget.onRecordDeleted?.call(response);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactView = widget.isMiniLayout ||
        (widget.isMiniLayout == false && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall));

    return ListTile(
      visualDensity: widget.isDense ? VisualDensity.compact : VisualDensity.standard,
      tileColor: AppTheme.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      contentPadding: EdgeInsets.only(
        left: isCompactView ? AppTheme.sizeSmall : AppTheme.sizeMedium,
        right: isCompactView ? AppTheme.sizeSmall : (widget.isMiniLayout ? AppTheme.sizeMedium : 0),
      ),
      onTap: widget.onOpenDetails,
      dense: widget.isDense,
      leading: _buildLeading(isCompactView),
      title: _buildTitle(),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(isCompactView),
    );
  }

  // Helper method to build the leading widget (habit icon)
  Widget _buildLeading(bool isCompactView) {
    return Icon(
      HabitUiConstants.habitIcon,
      size: widget.isDense
          ? AppTheme.iconSizeSmall
          : isCompactView
              ? AppTheme.iconSizeSmall // Smaller icon in compact view (16.0 instead of 20.0)
              : AppTheme.fontSizeXLarge,
    );
  }

  // Helper method to build the title widget (habit name)
  Widget _buildTitle() {
    final displayName =
        widget.habit.name.isEmpty ? _translationService.translate(SharedTranslationKeys.untitled) : widget.habit.name;

    return Text(
      displayName,
      style: widget.isDense ? AppTheme.bodySmall : AppTheme.bodyMedium,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  // Helper method to build the subtitle widget (tags and metadata)
  Widget? _buildSubtitle() {
    if (widget.isMiniLayout || (widget.habit.tags.isEmpty && widget.habit.estimatedTime == null)) {
      return null;
    }

    return Padding(
      padding: EdgeInsets.only(top: widget.isDense ? AppTheme.size2XSmall : AppTheme.sizeSmall),
      child: Wrap(
        spacing: AppTheme.sizeSmall,
        runSpacing: AppTheme.sizeSmall / 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildTagsWidget(),
          _buildEstimatedTimeWidget(),
        ],
      ),
    );
  }

  // Helper method to build the trailing widget (reminder icon, calendar, or checkbox)
  Widget? _buildTrailing(bool isCompactView) {
    if (isCompactView) {
      // For compact view, show checkbox first, then drag handle
      final compactWidgets = <Widget>[];

      // Always add the checkbox first
      compactWidgets.add(_buildCheckbox(context));

      // Add consistent spacing when custom sort is enabled (even for spacer alignment)
      if (widget.showDragHandle) {
        compactWidgets.add(const SizedBox(width: AppTheme.size3XSmall));

        if (widget.dragIndex != null) {
          // Add actual drag handle after checkbox
          compactWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.size2XSmall),
              child: ReorderableDragStartListener(
                index: widget.dragIndex!,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
          );
        } else {
          // Add spacer for archived habits to maintain alignment
          compactWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.size2XSmall),
              child: SizedBox(
                width: AppTheme.iconSizeMedium,
              ),
            ),
          );
        }
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: compactWidgets,
      );
    } else {
      // For full view, show reminder icon, calendar, and optionally drag handle
      final List<Widget> trailingWidgets = [];

      // Add reminder icon if applicable
      if (widget.habit.hasReminder && !widget.habit.isArchived()) {
        trailingWidgets.add(
          SizedBox(
            height: widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2,
            child: Center(
              child: Tooltip(
                message: _getReminderTooltip(),
                child: Icon(
                  Icons.notifications,
                  size: widget.isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }

      // Add calendar if not archived
      if (!widget.habit.isArchived()) {
        if (trailingWidgets.isNotEmpty) {
          trailingWidgets.add(const SizedBox(width: AppTheme.sizeSmall));
        }
        trailingWidgets.add(
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.size3XSmall),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildCalendar(),
            ),
          ),
        );
      }

      // Always add drag handle space when custom sort is enabled for consistent alignment
      if (widget.showDragHandle) {
        // Add spacing before drag handle/spacer area
        trailingWidgets.add(const SizedBox(width: AppTheme.sizeSmall));

        if (widget.dragIndex != null) {
          // Add actual drag handle
          trailingWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.size2XSmall),
              child: SizedBox(
                height: widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2,
                child: Center(
                  child: ReorderableDragStartListener(
                    index: widget.dragIndex!,
                    child: const Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                ),
              ),
            ),
          );
        } else {
          // Add spacer for alignment (archived habits, etc.)
          trailingWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.size2XSmall),
              child: SizedBox(
                width: AppTheme.iconSizeMedium,
                height: widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2,
              ),
            ),
          );
        }
      }

      // If we have custom sort enabled but no other trailing widgets, still show the drag handle space
      if (trailingWidgets.isEmpty && widget.showDragHandle) {
        if (widget.dragIndex != null) {
          trailingWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.size2XSmall),
              child: SizedBox(
                height: widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2,
                child: Center(
                  child: ReorderableDragStartListener(
                    index: widget.dragIndex!,
                    child: const Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                ),
              ),
            ),
          );
        } else {
          // Add spacer for archived habits to maintain alignment
          trailingWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.size2XSmall),
              child: SizedBox(
                width: AppTheme.iconSizeMedium,
                height: widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2,
              ),
            ),
          );
        }
      }

      return trailingWidgets.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: trailingWidgets,
            );
    }
  }

  // Helper method to build estimated time widget
  Widget _buildEstimatedTimeWidget() {
    if (widget.habit.estimatedTime == null || widget.isMiniLayout) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HabitUiConstants.estimatedTimeIcon,
          size: AppTheme.iconSizeSmall,
          color: HabitUiConstants.estimatedTimeColor,
        ),
        Text(
          SharedUiConstants.formatMinutes(widget.habit.estimatedTime),
          style: AppTheme.bodySmall.copyWith(
            color: HabitUiConstants.estimatedTimeColor,
          ),
        ),
      ],
    );
  }

  // Helper method to build tags widget
  Widget _buildTagsWidget() {
    if (widget.habit.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Label.multipleColored(
      icon: TagUiConstants.tagIcon,
      color: Colors.grey, // Default color for icon and commas
      values: widget.habit.tags
          .map((tag) => tag.name.isNotEmpty ? tag.name : _translationService.translate(SharedTranslationKeys.untitled))
          .toList(),
      colors: widget.habit.tags
          .map((tag) => tag.color != null ? Color(int.parse('FF${tag.color}', radix: 16)) : Colors.grey)
          .toList(),
      mini: true,
    );
  }

  String _getReminderTooltip() {
    if (!widget.habit.hasReminder || widget.habit.reminderTime == null) {
      return _translationService.translate(HabitTranslationKeys.noReminder);
    }

    final parts = widget.habit.reminderTime!.split(':');
    if (parts.length != 2) return _translationService.translate(HabitTranslationKeys.noReminder);

    final time = '${parts[0]}:${parts[1]}';

    final List<String> reminderInfo = [];

    reminderInfo.add('${_translationService.translate(HabitTranslationKeys.reminderTime)}: $time');

    reminderInfo.add(
        '${_translationService.translate(HabitTranslationKeys.reminderDays)}: ${_translationService.translate(HabitTranslationKeys.everyDay)}');

    return reminderInfo.join('\n');
  }

  Widget _buildCalendar() {
    if (_habitRecords == null) {
      return const SizedBox(
        width: AppTheme.calendarDayWidth,
        height: AppTheme.calendarDayHeight,
        child: SizedBox.shrink(),
      );
    }

    final referenceDate = widget.habit.archivedDate != null
        ? acore.DateTimeHelper.toLocalDateTime(widget.habit.archivedDate!)
        : DateTime.now();
    final days = List.generate(
      widget.dateRange,
      (index) => referenceDate.subtract(Duration(days: index)),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: days.map((date) => _buildCalendarDay(date, referenceDate)).toList(),
    );
  }

  Widget _buildCalendarDay(DateTime date, DateTime referenceDate) {
    final isDisabled = _isDateDisabled(date);
    final localDate = acore.DateTimeHelper.toLocalDateTime(date);
    final isToday = acore.DateTimeHelper.isSameDay(localDate, DateTime.now());
    final hasRecord = _hasRecordForDate(date);

    // Support for daily targets
    final dailyCompletionCount = _countRecordsForDate(date);
    final hasCustomGoals = widget.habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (widget.habit.dailyTarget ?? 1) : 1;
    final isDailyGoalMet = hasCustomGoals ? (dailyCompletionCount >= dailyTarget) : hasRecord;

    // Calculate period-based progress for period goals
    int periodCompletionCount = 0;
    bool isPeriodGoalMet = false;
    if (hasCustomGoals && widget.habit.periodDays > 1) {
      // Calculate the period window that contains this date
      final periodStart = _getPeriodStart(date, widget.habit.periodDays);
      final periodEnd = DateTime(date.year, date.month, date.day);

      // Count completed daily targets in this period window
      Map<String, int> dailyRecordCounts = {};

      // Group records by date and count them
      if (_habitRecords != null) {
        for (final record in _habitRecords!.items) {
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

      isPeriodGoalMet = periodCompletionCount >= widget.habit.targetFrequency;
    }

    // Determine icon based on completion state
    IconData icon;
    Color iconColor;

    if (isDisabled) {
      icon = HabitUiConstants.noRecordIcon;
      iconColor = AppTheme.textColor.withValues(alpha: 0.3);
    } else if (hasCustomGoals && widget.habit.periodDays > 1) {
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

    return SizedBox(
      width: HabitUiConstants.calendarDaySize,
      height: widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isDateLabelShowing) ...[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  acore.DateTimeHelper.getWeekday(localDate.weekday),
                  style: AppTheme.bodySmall.copyWith(
                    color: isToday
                        ? _themeService.primaryColor
                        : AppTheme.textColor.withValues(alpha: isDisabled ? 0.5 : 1),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.isDense ? 1 : 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  localDate.day.toString(),
                  style: AppTheme.bodySmall.copyWith(
                    color: isToday
                        ? _themeService.primaryColor
                        : AppTheme.textColor.withValues(alpha: isDisabled ? 0.5 : 1),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.isDense ? 1 : 2),
          ],
          Flexible(
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.standard,
                  constraints: BoxConstraints(
                    minWidth: widget.isDense ? 24 : 32,
                    minHeight: widget.isDense ? 24 : 32,
                  ),
                  onPressed: isDisabled ? null : () => _onCalendarDayTap(date),
                  icon: Icon(
                    icon,
                    size: widget.isDense ? AppTheme.iconSizeSmall : HabitUiConstants.calendarIconSize,
                    color: iconColor,
                  ),
                ),
                // Count badge for multiple daily targets
                if (hasCustomGoals && dailyTarget > 1 && !isDisabled && dailyCompletionCount > 0)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDailyGoalMet
                            ? Colors.green
                            : dailyCompletionCount > 0
                                ? Colors.orange
                                : Colors.red.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$dailyCompletionCount',
                        style: TextStyle(
                          fontSize: widget.isDense ? 8 : 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    if (_habitRecords == null) {
      return const SizedBox(
        width: AppTheme.buttonSizeSmall,
        height: AppTheme.buttonSizeSmall,
      );
    }

    final today = DateTime.now();
    final isDisabled = _isDateDisabled(today);
    final hasRecordToday = _hasRecordForDate(today);
    final todayCount = _countRecordsForDate(today);
    final hasCustomGoals = widget.habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (widget.habit.dailyTarget ?? 1) : 1;
    final isCompactView = widget.isMiniLayout ||
        (widget.isMiniLayout == false && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall));

    // For habits with custom goals and dailyTarget > 1, show completion badge
    if (hasCustomGoals && dailyTarget > 1) {
      final isComplete = todayCount >= dailyTarget;
      return SizedBox(
        width: isCompactView ? 32 : 40,
        height: isCompactView ? 24 : 30,
        child: InkWell(
          onTap: isDisabled ? null : _onCheckboxTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main icon in center
                Icon(
                  isDisabled
                      ? Icons.close
                      : isComplete
                          ? Icons.link
                          : todayCount > 0
                              ? Icons.add
                              : Icons.close,
                  size: isCompactView ? 14 : 16,
                  color: isDisabled
                      ? AppTheme.textColor.withValues(alpha: 0.3)
                      : isComplete
                          ? Colors.green
                          : todayCount > 0
                              ? Colors.blue
                              : Colors.red.withValues(alpha: 0.7),
                ),
                // Count badge in bottom right
                if (todayCount > 0)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? AppTheme.textColor.withValues(alpha: 0.3)
                            : isComplete
                                ? Colors.green
                                : todayCount > 0
                                    ? Colors.orange
                                    : Colors.red.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$todayCount',
                        style: TextStyle(
                          fontSize: isCompactView ? 8 : 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // For habits without custom goals, show traditional icon
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
          minWidth: isCompactView ? AppTheme.buttonSizeXSmall : AppTheme.buttonSizeSmall,
          minHeight: isCompactView ? AppTheme.buttonSizeXSmall : AppTheme.buttonSizeSmall),
      onPressed: isDisabled ? null : _onCheckboxTap,
      icon: Icon(
        hasRecordToday ? Icons.link : Icons.close,
        size: isCompactView ? AppTheme.fontSizeMedium : AppTheme.fontSizeLarge,
        color: isDisabled
            ? AppTheme.textColor.withValues(alpha: 0.3)
            : hasRecordToday
                ? Colors.green
                : Colors.red.withValues(alpha: 0.7),
      ),
    );
  }
}
