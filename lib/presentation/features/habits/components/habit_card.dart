import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/date_time_helper.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/features/tags/components/tag_label.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final void Function(AddHabitRecordCommandResponse)? onRecordCreated;
  final void Function(DeleteHabitRecordCommandResponse)? onRecordDeleted;
  final bool isMiniLayout;
  final bool isDateLabelShowing;
  final int dateRange;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onOpenDetails,
    this.onRecordCreated,
    this.onRecordDeleted,
    this.isMiniLayout = false,
    this.isDateLabelShowing = true,
    this.dateRange = 7,
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
    try {
      final query = GetListHabitRecordsQuery(
        pageIndex: 0,
        pageSize: widget.dateRange,
        habitId: widget.habit.id,
        startDate: DateTime.now().subtract(Duration(days: widget.isMiniLayout ? 1 : 7)),
        endDate: DateTime.now(),
      );
      final response = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);

      if (mounted) {
        setState(() {
          _habitRecords = response;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.loadingRecordsError));
      }
    }
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    try {
      final command = AddHabitRecordCommand(habitId: habitId, date: date);
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
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.creatingRecordError));
      }
    }
  }

  Future<void> _deleteHabitRecord(String id) async {
    try {
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
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.deletingRecordError));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenDetails,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(width: 8),
          Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildCalendar(),
            ),
          ),
        ],
      );

  Widget _buildHabitInfo() => Expanded(
        child: Row(
          children: [
            Icon(HabitUiConstants.habitIcon, size: AppTheme.fontSizeXLarge),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.habit.name,
                    style: AppTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!widget.isMiniLayout && widget.habit.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var i = 0; i < widget.habit.tags.length; i++) ...[
                                    if (i > 0) Text(", ", style: AppTheme.bodySmall.copyWith(color: Colors.grey)),
                                    TagLabel(
                                      tagColor: widget.habit.tags[i].color,
                                      tagName: widget.habit.tags[i].name,
                                      mini: true,
                                    ),
                                  ],
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
          ],
        ),
      );

  Widget _buildCalendar() {
    if (_habitRecords == null) {
      // No loading indicator since local DB is fast
      return const SizedBox(
        width: 32,
        height: 32,
        child: SizedBox.shrink(),
      );
    }

    DateTime today = DateTime.now();
    List<DateTime> lastDays =
        List.generate(widget.dateRange, (index) => today.subtract(Duration(days: index))).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: lastDays.map((date) => _buildCalendarDay(date, today)).toList(),
    );
  }

  Widget _buildCalendarDay(DateTime date, DateTime today) {
    bool hasRecord = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, date));
    HabitRecordListItem? recordForDay =
        hasRecord ? _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, date)) : null;

    return SizedBox(
      width: HabitUiConstants.calendarDaySize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isDateLabelShowing) ...[
            Text(
              DateTimeHelper.getWeekday(date.weekday),
              style: AppTheme.bodySmall.copyWith(
                color: DateTimeHelper.isSameDay(date, today) ? AppTheme.primaryColor : AppTheme.textColor,
              ),
            ),
            Text(
              date.day.toString(),
              style: AppTheme.bodySmall.copyWith(
                color: DateTimeHelper.isSameDay(date, today) ? AppTheme.primaryColor : AppTheme.textColor,
              ),
            ),
          ],
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () async {
              if (hasRecord) {
                await _deleteHabitRecord(recordForDay!.id);
              } else {
                await _createHabitRecord(widget.habit.id, date);
              }
            },
            icon: Icon(
              hasRecord ? HabitUiConstants.recordIcon : HabitUiConstants.noRecordIcon,
              size: HabitUiConstants.calendarIconSize,
              color: hasRecord ? HabitUiConstants.completedColor : HabitUiConstants.inCompletedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    if (_habitRecords == null) {
      // No loading indicator since local DB is fast
      return const SizedBox(
        width: 28,
        height: 28,
      );
    }

    bool hasRecordToday = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, DateTime.now()));
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () async {
        if (hasRecordToday) {
          HabitRecordListItem? recordToday =
              _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, DateTime.now()));
          await _deleteHabitRecord(recordToday.id);
        } else {
          await _createHabitRecord(widget.habit.id, DateTime.now());
          _soundPlayer.play(SharedSounds.done);
        }
      },
      icon: Icon(
        hasRecordToday ? Icons.link : Icons.close,
        size: AppTheme.fontSizeLarge,
        color: hasRecordToday ? Colors.green : Colors.red,
      ),
    );
  }
}
