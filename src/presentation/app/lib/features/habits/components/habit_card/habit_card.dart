import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/habits/commands/toggle_habit_completion_command.dart';

import 'package:application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:application/features/habits/queries/get_list_habits_query.dart';

import 'package:acore/acore.dart' as acore;

import 'package:whph/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/main.dart';
import 'package:whph/features/habits/services/habits_service.dart';
import 'package:whph/features/tags/services/time_data_service.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/utils/app_theme_helper.dart';
import 'package:whph/shared/utils/async_error_handler.dart';
import 'package:whph/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/features/habits/models/habit_list_style.dart';

// Extracted Components
import 'package:whph/features/habits/components/habit_card/habit_card_header.dart';
import 'package:whph/features/habits/components/habit_card/habit_card_calendar.dart';
import 'package:whph/features/habits/components/habit_card/habit_checkbox.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final HabitListStyle style;
  final bool isDateLabelShowing;
  final int dateRange;
  final bool isDense;
  final bool showDragHandle;
  final int? dragIndex;
  final bool isThreeStateEnabled;
  final bool isReverseDayOrder;

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
    this.isThreeStateEnabled = false,
    this.isReverseDayOrder = false,
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

    return Semantics(
      button: true,
      label: '${widget.habit.name} ${_translationService.translate(HabitTranslationKeys.detailsHint)}',
      hint: _translationService.translate(HabitTranslationKeys.openDetailsHint),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onOpenDetails,
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            child: Padding(
              padding: EdgeInsets.only(
                left: (widget.style == HabitListStyle.grid)
                    ? AppTheme.sizeMedium
                    : (isCompactView || isMobileCalendar
                        ? HabitUiConstants.calendarPaddingMobile
                        : HabitUiConstants.calendarPaddingDesktop),
                right: isCompactView || isMobileCalendar
                    ? HabitUiConstants.calendarPaddingMobile
                    : (widget.style == HabitListStyle.calendar ? HabitUiConstants.calendarPaddingDesktop : 0),
                // Add vertical padding to ensure content doesn't touch edges if height is small
                top: widget.isDense ? AppTheme.sizeXSmall : AppTheme.sizeSmall,
                bottom: widget.isDense ? AppTheme.sizeXSmall : AppTheme.sizeSmall,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: HabitCardHeader(
                        habit: widget.habit,
                        isDense: widget.isDense,
                        style: widget.style,
                        translationService: _translationService,
                      ),
                    ),
                  ),
                  if (_buildTrailing(isCompactView) != null) ...[
                    const SizedBox(width: AppTheme.sizeSmall),
                    _buildTrailing(isCompactView)!,
                  ],
                ],
              ),
            ),
          ),
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
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            clipBehavior: Clip.antiAlias,
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
                    Expanded(
                      child: HabitCardHeader(
                          habit: widget.habit,
                          isDense: widget.isDense,
                          style: widget.style,
                          translationService: _translationService),
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                    _buildTrailingForList()!,
                  ],
                ),
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
        HabitCheckbox(
          habit: widget.habit,
          habitRecords: _habitRecords?.items,
          style: widget.style,
          onTap: _onCheckboxTap,
          archivedDate: _archivedDate,
          isThreeStateEnabled: widget.isThreeStateEnabled,
        ),
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

  // Helper method to build the trailing widget (reminder icon, calendar, or checkbox)
  Widget? _buildTrailing(bool isCompactView) {
    if (isCompactView) {
      return _buildCompactTrailing();
    }
    return _buildStandardTrailing();
  }

  Widget _buildCompactTrailing() {
    final compactWidgets = <Widget>[];

    // Always add the checkbox first
    compactWidgets.add(
      HabitCheckbox(
        habit: widget.habit,
        habitRecords: _habitRecords?.items,
        style: widget.style,
        onTap: _onCheckboxTap,
        archivedDate: _archivedDate,
        isThreeStateEnabled: widget.isThreeStateEnabled,
      ),
    );

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: compactWidgets,
    );
  }

  Widget? _buildStandardTrailing() {
    // For full view, show reminder icon, calendar, and optionally drag handle
    final trailingWidgets = <Widget>[];

    // Add reminder icon if applicable
    if (widget.habit.hasReminder && !widget.habit.isArchived) {
      trailingWidgets.add(_buildReminderIcon());
    }

    // Add calendar if not archived
    if (!widget.habit.isArchived) {
      if (trailingWidgets.isNotEmpty) {
        trailingWidgets.add(const SizedBox(width: HabitUiConstants.dragHandleSpacer));
      }
      trailingWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: HabitUiConstants.calendarTrailingSpacer),
          child: HabitCardCalendar(
            habit: widget.habit,
            habitRecords: _habitRecords?.items,
            dateRange: widget.dateRange,
            isDense: widget.isDense,
            isDateLabelShowing: widget.isDateLabelShowing,
            onDayTap: _onCalendarDayTap,
            themeService: _themeService,
            archivedDate: _archivedDate,
            isThreeStateEnabled: widget.isThreeStateEnabled,
            isReverseDayOrder: widget.isReverseDayOrder,
          ),
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
              height: HabitUiConstants.calendarDaySize,
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
              height: HabitUiConstants.calendarDaySize,
            ),
          ),
        );
      }
    }

    return trailingWidgets.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: trailingWidgets,
          );
  }

  Widget _buildReminderIcon() {
    return SizedBox(
      height: HabitUiConstants.calendarDaySize,
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
}
