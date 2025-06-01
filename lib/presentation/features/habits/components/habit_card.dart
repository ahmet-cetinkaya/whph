import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/label.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final void Function(AddHabitRecordCommandResponse)? onRecordCreated;
  final void Function(DeleteHabitRecordCommandResponse)? onRecordDeleted;
  final bool isMiniLayout;
  final bool isDateLabelShowing;
  final int dateRange;
  final bool isDense;

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
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  final _mediator = container.resolve<Mediator>();
  final _soundPlayer = container.resolve<ISoundPlayer>();
  final _habitsService = container.resolve<HabitsService>();
  final _translationService = container.resolve<ITranslationService>();
  GetListHabitRecordsQueryResponse? _habitRecords;

  @override
  void initState() {
    super.initState();
    _getHabitRecords();
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

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = AddHabitRecordCommand(habitId: habitId, date: DateTimeHelper.toUtcDateTime(date));
        final response = await _mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);

        if (mounted) {
          setState(() {
            _habitRecords = null;
            _getHabitRecords();
          });
        }

        // Notify service that a record was added
        _habitsService.notifyHabitRecordAdded(habitId);
        widget.onRecordCreated?.call(response);
        _soundPlayer.play(SharedSounds.done);
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

        if (mounted) {
          setState(() {
            _habitRecords = null;
            _getHabitRecords();
          });
        }

        // Notify service that a record was removed
        _habitsService.notifyHabitRecordRemoved(widget.habit.id);
        widget.onRecordDeleted?.call(response);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardPadding = widget.isDense
        ? const EdgeInsets.symmetric(horizontal: AppTheme.size3XSmall, vertical: AppTheme.sizeXSmall)
        : const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: AppTheme.sizeXSmall);

    return GestureDetector(
      onTap: widget.onOpenDetails,
      child: Card(
        child: Padding(
          padding: cardPadding,
          child: widget.isMiniLayout ||
                  (widget.isMiniLayout == false && AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall))
              ? _buildCompactView()
              : _buildFullView(),
        ),
      ),
    );
  }

  Widget _buildCompactView() => Row(
        children: [
          _buildHabitInfo(),
          _buildCheckbox(context),
        ],
      );

  Widget _buildFullView() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHabitInfo(),
          if (!widget.habit.isArchived()) ...[
            const SizedBox(width: AppTheme.sizeSmall),
            Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildCalendar(),
              ),
            ),
          ]
        ],
      );

  Widget _buildHabitInfo() => Expanded(
        child: Row(
          children: [
            Icon(HabitUiConstants.habitIcon, size: widget.isDense ? AppTheme.iconSizeSmall : AppTheme.fontSizeXLarge),
            SizedBox(width: widget.isDense ? AppTheme.sizeXSmall : AppTheme.sizeSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.habit.name,
                          style: widget.isDense ? AppTheme.bodySmall : AppTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isMiniLayout && widget.habit.tags.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: widget.isDense ? AppTheme.size2XSmall : AppTheme.sizeXSmall),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: AppTheme.sizeXSmall,
                                children: [
                                  // Tags
                                  Label.multipleColored(
                                    icon: TagUiConstants.tagIcon,
                                    color: Colors.grey, // Default color for icon and commas
                                    values: widget.habit.tags.map((tag) => tag.name).toList(),
                                    colors: widget.habit.tags
                                        .map((tag) => tag.color != null
                                            ? Color(int.parse('FF${tag.color}', radix: 16))
                                            : Colors.grey)
                                        .toList(),
                                    mini: true,
                                  ),

                                  // Estimated time
                                  if (widget.habit.estimatedTime != null && !widget.isMiniLayout)
                                    Row(
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
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Estimated time and reminder icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.habit.hasReminder && !widget.isMiniLayout && !widget.habit.isArchived())
                  Padding(
                    padding: const EdgeInsets.only(left: AppTheme.sizeXSmall),
                    child: Tooltip(
                      message: _getReminderTooltip(),
                      child: Icon(
                        Icons.notifications,
                        size: AppTheme.iconSizeSmall,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

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
    final isDisabled = date.isAfter(DateTime.now()) ||
        (widget.habit.archivedDate != null && date.isAfter(DateTimeHelper.toLocalDateTime(widget.habit.archivedDate!)));

    final localDate = DateTimeHelper.toLocalDateTime(date);
    final isToday = DateTimeHelper.isSameDay(localDate, DateTime.now());

    bool hasRecord = _habitRecords!.items
        .any((record) => DateTimeHelper.isSameDay(DateTimeHelper.toLocalDateTime(record.date), localDate));
    HabitRecordListItem? recordForDay = hasRecord
        ? _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, localDate))
        : null;

    return SizedBox(
      width: HabitUiConstants.calendarDaySize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isDateLabelShowing) ...[
            Text(
              DateTimeHelper.getWeekday(localDate.weekday),
              style: AppTheme.bodySmall.copyWith(
                color: isToday ? AppTheme.primaryColor : AppTheme.textColor.withValues(alpha: isDisabled ? 0.5 : 1),
              ),
            ),
            Text(
              localDate.day.toString(),
              style: AppTheme.bodySmall.copyWith(
                color: isToday ? AppTheme.primaryColor : AppTheme.textColor.withValues(alpha: isDisabled ? 0.5 : 1),
              ),
            ),
          ],
          IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: AppTheme.calendarIconSize, minHeight: AppTheme.calendarIconSize),
            onPressed: isDisabled
                ? null
                : () async {
                    if (hasRecord) {
                      await _deleteHabitRecord(recordForDay!.id);
                    } else {
                      await _createHabitRecord(widget.habit.id, date);
                    }
                  },
            icon: Icon(
              hasRecord ? HabitUiConstants.recordIcon : HabitUiConstants.noRecordIcon,
              size: HabitUiConstants.calendarIconSize,
              color: isDisabled
                  ? AppTheme.textColor.withValues(alpha: 0.3)
                  : hasRecord
                      ? HabitUiConstants.completedColor
                      : HabitUiConstants.inCompletedColor,
            ),
          ),
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
    final isDisabled =
        widget.habit.archivedDate != null && today.isAfter(DateTimeHelper.toLocalDateTime(widget.habit.archivedDate!));

    bool hasRecordToday = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, today));

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: AppTheme.buttonSizeSmall, minHeight: AppTheme.buttonSizeSmall),
      onPressed: isDisabled
          ? null
          : () async {
              if (hasRecordToday) {
                HabitRecordListItem? recordToday =
                    _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, today));
                await _deleteHabitRecord(recordToday.id);
              } else {
                await _createHabitRecord(widget.habit.id, today);
                _soundPlayer.play(SharedSounds.done);
              }
            },
      icon: Icon(
        hasRecordToday ? Icons.link : Icons.close,
        size: AppTheme.fontSizeLarge,
        color: isDisabled
            ? AppTheme.textColor.withValues(alpha: 0.3)
            : hasRecordToday
                ? Colors.green
                : Colors.red,
      ),
    );
  }
}
