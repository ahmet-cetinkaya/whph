import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/date_time_helper.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final void Function(AddHabitRecordCommandResponse)? onRecordCreated;
  final void Function(DeleteHabitRecordCommandResponse)? onRecordDeleted;
  final bool isMiniLayout;
  final bool isDateLabelShowing;
  final int dateRange;

  const HabitCard(
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
  final Mediator mediator = container.resolve<Mediator>();
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
    var response = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);

    setState(() {
      _habitRecords = response;
    });
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    var command = AddHabitRecordCommand(habitId: habitId, date: date);
    await mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);

    setState(() {
      _habitRecords = null;
      _getHabitRecords();
    });
    widget.onRecordCreated?.call(AddHabitRecordCommandResponse());
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);

    setState(() {
      _habitRecords = null;
      _getHabitRecords();
    });
    widget.onRecordDeleted?.call(DeleteHabitRecordCommandResponse());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: widget.onOpenDetails,
        leading: Icon(Icons.label),
        title: LayoutBuilder(builder: (context, constraints) {
          if (widget.isMiniLayout) {
            return Row(
              children: [
                Text(
                  widget.habit.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Spacer(),
                _buildCheckbox(context),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: (constraints.maxWidth) * 0.3,
                child: Text(
                  widget.habit.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  softWrap: true,
                ),
              ),
              _buildCalendar(),
            ],
          );
        }),
        contentPadding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    bool hasRecordToday = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, DateTime.now()));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Checkbox(
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
      ),
    );
  }

  Widget _buildCalendar() {
    DateTime today = DateTime.now();
    List<DateTime> lastDays = List.generate(widget.dateRange, (index) => today.subtract(Duration(days: index)));

    return _habitRecords == null
        ? Center(
            child: CircularProgressIndicator(),
          )
        : Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: lastDays.map((date) {
                bool hasRecord = _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, date));

                HabitRecordListItem? recordForDay;
                if (hasRecord) {
                  recordForDay =
                      _habitRecords!.items.firstWhere((record) => DateTimeHelper.isSameDay(record.date, date));
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () async {
                      if (hasRecord) {
                        await _deleteHabitRecord(recordForDay!.id);
                      } else {
                        await _createHabitRecord(widget.habit.id, date);
                      }
                    },
                    child: Column(
                      children: [
                        // Day of the week
                        if (widget.isDateLabelShowing)
                          Column(
                            children: [
                              Text(
                                DateTimeHelper.getWeekday(date.weekday),
                                style: TextStyle(
                                  color: DateTimeHelper.isSameDay(date, today)
                                      ? AppTheme.primaryColor
                                      : AppTheme.textColor,
                                  fontSize: AppTheme.fontSizeSmall,
                                ),
                              ),
                              Text(date.day.toString(),
                                  style: TextStyle(
                                    color: DateTimeHelper.isSameDay(date, today)
                                        ? AppTheme.primaryColor
                                        : AppTheme.textColor,
                                    fontSize: AppTheme.fontSizeMedium,
                                  ))
                            ],
                          ),

                        // Checkbox icon
                        Icon(
                          hasRecord ? Icons.link : Icons.close,
                          color: hasRecord ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
  }
}
