import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';

import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';

import 'package:acore/acore.dart' as acore;

import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/tag_list_widget.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final HabitListStyle style;
  final bool isDateLabelShowing;
  final int dateRange;
  final bool isDense;
  final bool showDragHandle;
  final int? dragIndex;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onOpenDetails,
    this.style = HabitListStyle.grid,
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
  final _soundManagerService = container.resolve<ISoundManagerService>();
  final _habitsService = container.resolve<HabitsService>();
  final _timeDataService = container.resolve<TimeDataService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  GetListHabitRecordsQueryResponse? _habitRecords;

  // Memoized values to prevent unnecessary recalculations
  late final String _habitId = widget.habit.id;
  late final bool _hasGoal = widget.habit.hasGoal;
  late final int? _dailyTarget = widget.habit.dailyTarget;
  late final int _periodDays = widget.habit.periodDays;
  late final DateTime? _archivedDate = widget.habit.archivedDate;

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

    // Check if the event is for this specific habit using memoized ID
    final addedHabitId = _habitsService.onHabitRecordAdded.value;
    final removedHabitId = _habitsService.onHabitRecordRemoved.value;

    if (addedHabitId == _habitId || removedHabitId == _habitId) {
      _refreshHabitRecords();
    }
  }

  Future<void> _getHabitRecords() async {
    await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        final endDate = _archivedDate ?? DateTime.now();
        // Calculate appropriate page size to handle multiple daily occurrences
        final dailyTarget = _hasGoal ? (_dailyTarget ?? 1) : 1;
        final daysToShow = widget.style == HabitListStyle.calendar ? widget.dateRange : 1;

        // For period-based habits, we need to fetch enough data to calculate period completion
        // This ensures we have data for the full period window that might affect the displayed days
        final periodDays = _periodDays;
        final daysToFetch = daysToShow + (periodDays > 1 ? periodDays - 1 : 0);

        final pageSize =
            daysToFetch * (dailyTarget > 1 ? dailyTarget * 2 : 10); // Allow for more records than the target

        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: pageSize,
          habitId: _habitId,
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
        (_archivedDate != null && date.isAfter(acore.DateTimeHelper.toLocalDateTime(_archivedDate)));
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
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(
          habitId: _habitId,
          date: date,
          useIncrementalBehavior: false, // Calendar uses toggle behavior
        );
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);

        await _refreshHabitRecords();
        _habitsService.notifyHabitRecordAdded(_habitId);
        _timeDataService.notifyTimeDataChanged();
        _soundManagerService.playHabitCompletion();
      },
    );
  }

  // Event handler for checkbox tap with smart logic for multiple occurrences
  Future<void> _onCheckboxTap() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final today = DateTime.now();
        final command = ToggleHabitCompletionCommand(
          habitId: _habitId,
          date: today,
          useIncrementalBehavior: true, // Checkbox uses incremental behavior
        );
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);

        await _refreshHabitRecords();
        _habitsService.notifyHabitRecordAdded(_habitId);
        _timeDataService.notifyTimeDataChanged();
        _soundManagerService.playHabitCompletion();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactView =
        widget.style != HabitListStyle.calendar || AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall);

    final isList = widget.style == HabitListStyle.list;

    final isMobileCalendar =
        widget.style == HabitListStyle.calendar && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);

    if (isList) {
      return _buildListLayout(context, isCompactView);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: widget.style == HabitListStyle.grid ? 0 : 60,
      ), // Ensure minimum height to prevent shrinking, except for grid
      child: Semantics(
        button: true,
        label: '${widget.habit.name} ${_translationService.translate(HabitTranslationKeys.detailsHint)}',
        hint: _translationService.translate(HabitTranslationKeys.openDetailsHint),
        child: ListTile(
          visualDensity: widget.isDense ? VisualDensity.compact : VisualDensity.standard,
          titleAlignment: ListTileTitleAlignment.center,
          tileColor: AppTheme.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
          ),
          contentPadding: EdgeInsets.only(
            left: (widget.style == HabitListStyle.grid)
                ? AppTheme.sizeMedium
                : (isCompactView || isMobileCalendar
                    ? HabitUiConstants.calendarPaddingMobile
                    : HabitUiConstants.calendarPaddingDesktop),
            right: isCompactView || isMobileCalendar
                ? HabitUiConstants.calendarPaddingMobile
                : (widget.style == HabitListStyle.calendar ? HabitUiConstants.calendarPaddingDesktop : 0),
          ),
          onTap: widget.onOpenDetails,
          dense: widget.isDense,
          leading: null,
          title: (widget.style == HabitListStyle.grid) ? _buildTitleAndMetadata() : _buildTitle(),
          subtitle: (widget.style == HabitListStyle.grid) ? null : _buildSubtitle(),
          trailing: _buildTrailing(isCompactView),
        ),
      ),
    );
  }

  Widget _buildListLayout(BuildContext context, bool isCompactView) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Semantics(
        button: true,
        label: '${widget.habit.name} ${_translationService.translate(HabitTranslationKeys.detailsHint)}',
        hint: _translationService.translate(HabitTranslationKeys.openDetailsHint),
        child: Material(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
          child: InkWell(
            onTap: widget.onOpenDetails,
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            child: Padding(
              padding: EdgeInsets.only(
                left: AppTheme.sizeMedium,
                right: isCompactView ? AppTheme.sizeSmall : 0,
                top: AppTheme.sizeSmall,
                bottom: AppTheme.sizeSmall,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildTitleAndMetadata()),
                  const SizedBox(width: AppTheme.sizeSmall),
                  _buildTrailingForList()!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildTrailingForList() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCheckbox(context),
        // Only show drag handle if enabled and index is present
        if (widget.showDragHandle && widget.dragIndex != null)
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
            child: ReorderableDragStartListener(
              index: widget.dragIndex!,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleAndMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.habit.name.isEmpty ? _translationService.translate(SharedTranslationKeys.untitled) : widget.habit.name,
          style: (widget.isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.style != HabitListStyle.grid) ...[
          if (widget.isDense) const SizedBox(height: 1) else const SizedBox(height: 2),
          _buildMetadataRow(),
        ],
      ],
    );
  }

  Widget _buildMetadataRow() {
    final spacing = widget.isDense ? 4.0 : 8.0;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tags section
        if (widget.habit.tags.isNotEmpty) _buildTagsWidget(mini: true),

        // Estimated Time
        if (widget.habit.estimatedTime != null || widget.habit.actualTime != null) _buildEstimatedTimeWidget(),
      ],
    );
  }

  // Helper method to build title
  Widget _buildTitle() {
    return Text(
      widget.habit.name.isEmpty ? _translationService.translate(SharedTranslationKeys.untitled) : widget.habit.name,
      style: (widget.isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
        fontWeight: FontWeight.bold,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // Helper method to build the subtitle widget (tags and metadata)
  Widget? _buildSubtitle() {
    if (widget.style == HabitListStyle.grid) {
      return null;
    }

    final timeToDisplay = widget.habit.actualTime ?? widget.habit.estimatedTime;
    if (widget.habit.tags.isEmpty && (timeToDisplay == null || timeToDisplay == 0)) {
      return null;
    }

    return Padding(
      padding: EdgeInsets.only(top: widget.isDense ? AppTheme.size2XSmall : AppTheme.sizeSmall),
      child: LimitedBox(
        maxHeight: 48.0, // Limit the height of the tags container
        child: Wrap(
          spacing: AppTheme.sizeSmall,
          runSpacing: AppTheme.sizeSmall / 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // For TodayList, we might want tags to start on a new line or consistent alignment?
            // Wrapped is fine.
            if (widget.habit.tags.isNotEmpty) _buildTagsWidget(),
            if (timeToDisplay != null) _buildEstimatedTimeWidget(),
          ],
        ),
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
          trailingWidgets.add(const SizedBox(width: HabitUiConstants.dragHandleSpacer));
        }
        trailingWidgets.add(
          Padding(
            padding: const EdgeInsets.only(right: HabitUiConstants.calendarTrailingSpacer),
            child: _buildCalendar(),
          ),
        );
      }

      // Always add drag handle space when custom sort is enabled for consistent alignment
      if (widget.showDragHandle) {
        // Add spacing before drag handle/spacer area
        trailingWidgets.add(const SizedBox(width: HabitUiConstants.dragHandleSpacer));

        if (widget.dragIndex != null) {
          // Add actual drag handle
          trailingWidgets.add(
            Padding(
              padding: const EdgeInsets.only(right: HabitUiConstants.dragHandlePadding),
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
              padding: const EdgeInsets.only(right: HabitUiConstants.dragHandlePadding),
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
    // Use actual time if available, otherwise fall back to estimated time
    final timeToDisplay = widget.habit.actualTime ?? widget.habit.estimatedTime;
    final isActualTime = widget.habit.actualTime != null;

    if (timeToDisplay == null || timeToDisplay == 0 || widget.style == HabitListStyle.grid) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HabitUiConstants.estimatedTimeIcon,
          size: AppTheme.iconSizeSmall,
          color: isActualTime ? Colors.green : HabitUiConstants.estimatedTimeColor,
        ),
        Text(
          SharedUiConstants.formatMinutes(timeToDisplay),
          style: AppTheme.bodySmall.copyWith(
            color: isActualTime ? Colors.green : HabitUiConstants.estimatedTimeColor,
          ),
        ),
      ],
    );
  }

  // Helper method to build tags widget
  Widget _buildTagsWidget({bool mini = false}) {
    final items = TagDisplayUtils.objectsToDisplayItems(widget.habit.tags, _translationService);
    return TagListWidget(items: items, mini: mini);
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
    // Generate days (Today, Yesterday, ...)
    final days = List.generate(
      widget.dateRange,
      (index) => referenceDate.subtract(Duration(days: index)),
    );

    // Reverse to show Oldest -> Newest (Left -> Right) to match typical calendar flow
    final orderedDays = days.reversed.toList();

    final dayWidgets = <Widget>[];
    for (int i = 0; i < orderedDays.length; i++) {
      if (i > 0) dayWidgets.add(const SizedBox(width: HabitUiConstants.calendarDaySpacing));
      dayWidgets.add(_buildCalendarDay(orderedDays[i], referenceDate));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: dayWidgets,
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

    final isMobileCalendar =
        widget.style == HabitListStyle.calendar && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);
    // If mobile calendar, we want LARGE icons/buttons, overriding isDense
    final useLargeSize = !widget.isDense || isMobileCalendar;

    // Day size should match HabitsPage header: 36.0 on Mobile, 46.0 (calendarDaySize) on Desktop
    final double daySize = isMobileCalendar ? 36.0 : HabitUiConstants.calendarDaySize;

    return SizedBox(
      width: daySize,
      height: useLargeSize
          ? daySize * 1.5
          : (widget.isDense ? HabitUiConstants.calendarDaySize * 1.5 : HabitUiConstants.calendarDaySize * 2),
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
                    minWidth: useLargeSize ? 36 : 24,
                    minHeight: useLargeSize ? 36 : 24,
                  ),
                  onPressed: isDisabled ? null : () => _onCalendarDayTap(date),
                  icon: Icon(
                    icon,
                    size: useLargeSize
                        ? 24
                        : (widget.isDense ? AppTheme.iconSizeSmall : HabitUiConstants.calendarIconSize),
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
                          fontSize: useLargeSize ? 10 : (widget.isDense ? 8 : 9),
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
        width: AppTheme.buttonSizeMedium,
        height: AppTheme.buttonSizeMedium,
      );
    }

    final today = DateTime.now();
    final isDisabled = _isDateDisabled(today);
    final hasRecordToday = _hasRecordForDate(today);
    final todayCount = _countRecordsForDate(today);
    final hasCustomGoals = widget.habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (widget.habit.dailyTarget ?? 1) : 1;
    final isMobileCalendar =
        widget.style == HabitListStyle.calendar && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);
    final isCompactView = widget.style != HabitListStyle.calendar || isMobileCalendar;

    // Increase touch target sizes to match TaskCard (approx 36-40px)
    // For mobile calendar view, we want larger buttons despite being in compact layout
    final useLargeSize = !isCompactView || isMobileCalendar;
    final double buttonSize = useLargeSize ? 36.0 : AppTheme.buttonSizeMedium;
    final double iconSize = useLargeSize ? 24.0 : AppTheme.iconSizeMedium;

    // For habits with custom goals and dailyTarget > 1, show completion badge
    if (hasCustomGoals && dailyTarget > 1) {
      final isComplete = todayCount >= dailyTarget;
      // Dimensions increased for better touch target
      return SizedBox(
        width: useLargeSize ? 36 : 36,
        height: useLargeSize ? 36 : 36,
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
                  size: iconSize,
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
                    bottom: 0,
                    right: 0,
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
                          fontSize: useLargeSize ? 10 : 9,
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
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
        onPressed: isDisabled ? null : _onCheckboxTap,
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
}
