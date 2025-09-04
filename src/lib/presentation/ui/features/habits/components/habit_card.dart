import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:acore/acore.dart';
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
  final _soundPlayer = container.resolve<ISoundPlayer>();
  final _habitsService = container.resolve<HabitsService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
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
        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: widget.dateRange,
          habitId: widget.habit.id,
          startDate: DateTimeHelper.toUtcDateTime(
              endDate.subtract(Duration(days: widget.isMiniLayout ? 1 : widget.dateRange))),
          endDate: DateTimeHelper.toLocalDateTime(endDate),
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
  void _refreshHabitRecords() {
    if (mounted) {
      setState(() {
        _habitRecords = null;
        _getHabitRecords();
      });
    }
  }

  // Helper method to check if a date is disabled for habit recording
  bool _isDateDisabled(DateTime date) {
    return date.isAfter(DateTime.now()) ||
        (widget.habit.archivedDate != null && date.isAfter(DateTimeHelper.toLocalDateTime(widget.habit.archivedDate!)));
  }

  // Helper method to check if there's a record for a specific date
  bool _hasRecordForDate(DateTime date) {
    if (_habitRecords == null) return false;
    return _habitRecords!.items.any((record) =>
        DateTimeHelper.isSameDay(DateTimeHelper.toLocalDateTime(record.date), DateTimeHelper.toLocalDateTime(date)));
  }

  // Helper method to get a record for a specific date
  HabitRecordListItem? _getRecordForDate(DateTime date) {
    if (_habitRecords == null || !_hasRecordForDate(date)) return null;
    return _habitRecords!.items.firstWhere((record) =>
        DateTimeHelper.isSameDay(DateTimeHelper.toLocalDateTime(record.date), DateTimeHelper.toLocalDateTime(date)));
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
    final hasRecord = _hasRecordForDate(date);
    if (hasRecord) {
      final record = _getRecordForDate(date);
      if (record != null) {
        await _deleteHabitRecord(record.id);
      }
    } else {
      await _createHabitRecord(widget.habit.id, date);
    }
  }

  // Event handler for checkbox tap
  Future<void> _onCheckboxTap() async {
    final today = DateTime.now();
    final hasRecordToday = _hasRecordForDate(today);

    if (hasRecordToday) {
      final recordToday = _getRecordForDate(today);
      if (recordToday != null) {
        await _deleteHabitRecord(recordToday.id);
      }
    } else {
      await _createHabitRecord(widget.habit.id, today);
    }
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = AddHabitRecordCommand(habitId: habitId, date: DateTimeHelper.toUtcDateTime(date));
        final response = await _mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);

        _refreshHabitRecords();

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

        _refreshHabitRecords();

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
    return Text(
      widget.habit.name,
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
      values: widget.habit.tags.map((tag) => tag.name).toList(),
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

    final referenceDate =
        widget.habit.archivedDate != null ? DateTimeHelper.toLocalDateTime(widget.habit.archivedDate!) : DateTime.now();
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
    final localDate = DateTimeHelper.toLocalDateTime(date);
    final isToday = DateTimeHelper.isSameDay(localDate, DateTime.now());
    final hasRecord = _hasRecordForDate(date);

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
                  DateTimeHelper.getWeekday(localDate.weekday),
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
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.standard,
              constraints: BoxConstraints(
                minWidth: widget.isDense ? 24 : 32,
                minHeight: widget.isDense ? 24 : 32,
              ),
              onPressed: isDisabled ? null : () => _onCalendarDayTap(date),
              icon: Icon(
                hasRecord ? HabitUiConstants.recordIcon : HabitUiConstants.noRecordIcon,
                size: widget.isDense ? AppTheme.iconSizeSmall : HabitUiConstants.calendarIconSize,
                color: _getRecordStateColor(hasRecord, isDisabled),
              ),
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
    final isCompactView = widget.isMiniLayout ||
        (widget.isMiniLayout == false && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall));

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
                : Colors.red,
      ),
    );
  }
}
