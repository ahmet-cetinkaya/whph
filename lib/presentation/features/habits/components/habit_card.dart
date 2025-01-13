import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/features/shared/utils/date_time_helper.dart';

class HabitCard extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final ISoundPlayer _soundPlayer = container.resolve<ISoundPlayer>();

  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final void Function(AddHabitRecordCommandResponse)? onRecordCreated;
  final void Function(DeleteHabitRecordCommandResponse)? onRecordDeleted;
  final bool isMiniLayout;
  final bool isDateLabelShowing;
  final int dateRange;

  HabitCard(
      {super.key,
      required this.habit,
      required this.onOpenDetails,
      this.onRecordCreated,
      this.onRecordDeleted,
      this.isMiniLayout = false,
      this.isDateLabelShowing = true,
      this.dateRange = 7});

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  GetListHabitRecordsQueryResponse? _habitRecords;

  @override
  void initState() {
    _getHabitRecords();

    super.initState();
  }

  Future<void> _getHabitRecords() async {
    var query = GetListHabitRecordsQuery(
      pageIndex: 0,
      pageSize: widget.dateRange,
      habitId: widget.habit.id,
      startDate: DateTime.now().subtract(Duration(days: widget.isMiniLayout ? 1 : 7)),
      endDate: DateTime.now(),
    );
    var response = await widget._mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);

    if (mounted) {
      setState(() {
        _habitRecords = response;
      });
    }
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    var command = AddHabitRecordCommand(habitId: habitId, date: date);
    await widget._mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);

    if (mounted) {
      setState(() {
        _habitRecords = null;
        _getHabitRecords();
      });
    }
    widget.onRecordCreated?.call(AddHabitRecordCommandResponse());
    widget._soundPlayer.play(SharedSounds.done);
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await widget._mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);

    if (mounted) {
      setState(() {
        _habitRecords = null;
        _getHabitRecords();
      });
    }
    widget.onRecordDeleted?.call(DeleteHabitRecordCommandResponse());
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
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHabitName(),
                    _buildCheckbox(context),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHabitName(),
                    Flexible(
                      // Added Flexible
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildCalendar(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHabitName() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.refresh),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    widget.habit.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (!widget.isMiniLayout && widget.habit.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.label,
                    color: Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.habit.tags.map((tag) => tag.name).join(", "),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    if (_habitRecords == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    bool hasRecordToday = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, DateTime.now()));
    return Checkbox(
      value: hasRecordToday,
      onChanged: (bool? value) async {
        if (value == true) {
          await _createHabitRecord(widget.habit.id, DateTime.now());
        } else {
          HabitRecordListItem? recordToday =
              _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, DateTime.now()));
          await _deleteHabitRecord(recordToday.id);
        }
      },
    );
  }

  Widget _buildCalendar() {
    if (_habitRecords == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    DateTime today = DateTime.now();
    List<DateTime> lastDays = List.generate(widget.dateRange, (index) => today.subtract(Duration(days: index)));

    return Container(
      width: widget.dateRange * 48.0, // Match header width (48px per day)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: lastDays.map((date) {
          bool hasRecord = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, date));

          HabitRecordListItem? recordForDay;
          if (hasRecord) {
            recordForDay = _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, date));
          }

          return SizedBox(
            width: 46, // Fixed width for each date column
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.isDateLabelShowing)
                  Column(
                    children: [
                      Text(
                        DateTimeHelper.getWeekday(date.weekday),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: DateTimeHelper.isSameDay(date, today) ? AppTheme.primaryColor : AppTheme.textColor,
                          fontSize: AppTheme.fontSizeSmall,
                        ),
                      ),
                      Text(
                        date.day.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: DateTimeHelper.isSameDay(date, today) ? AppTheme.primaryColor : AppTheme.textColor,
                          fontSize: AppTheme.fontSizeMedium,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () async {
                    if (hasRecord) {
                      await _deleteHabitRecord(recordForDay!.id);
                    } else {
                      await _createHabitRecord(widget.habit.id, date);
                    }
                  },
                  icon: Icon(
                    hasRecord ? Icons.link : Icons.close,
                    size: 20,
                  ),
                  color: hasRecord ? Colors.green : Colors.red,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
