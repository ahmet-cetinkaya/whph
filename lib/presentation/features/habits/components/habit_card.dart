import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;
  final bool mini;

  const HabitCard({super.key, required this.habit, required this.onOpenDetails, this.mini = false});

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  final Mediator mediator = container.resolve<Mediator>();
  late Future<List<HabitRecordListItem>> habitRecords;

  @override
  void initState() {
    super.initState();
    habitRecords = _getHabitRecords(widget.habit.id);
  }

  Future<List<HabitRecordListItem>> _getHabitRecords(String habitId) async {
    var query = GetListHabitRecordsQuery(
      pageIndex: 0,
      pageSize: 7,
      habitId: habitId,
      startDate: DateTime.now().subtract(Duration(days: widget.mini ? 1 : 7)),
      endDate: DateTime.now(),
    );
    var queryResponse = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
    return queryResponse.items;
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    var command = AddHabitRecordCommand(habitId: habitId, date: date);
    await mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
    setState(() {
      habitRecords = _getHabitRecords(habitId);
    });
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
    setState(() {
      habitRecords = _getHabitRecords(widget.habit.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenDetails,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                widget.habit.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              FutureBuilder<List<HabitRecordListItem>>(
                future: habitRecords,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (widget.mini) {
                    return _buildCheckbox(snapshot);
                  } else {
                    return _buildCalendar(snapshot.data!);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(AsyncSnapshot<List<HabitRecordListItem>> snapshot) {
    bool hasRecordToday = snapshot.data!.any((record) => isSameDay(record.date, DateTime.now()));
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Checkbox(
        value: hasRecordToday,
        onChanged: (bool? value) async {
          if (value == true) {
            await _createHabitRecord(widget.habit.id, DateTime.now());
          } else {
            HabitRecordListItem? recordToday =
                snapshot.data!.firstWhere((record) => isSameDay(record.date, DateTime.now()));
            print(recordToday.id);
            await _deleteHabitRecord(recordToday.id);
          }
        },
      ),
    );
  }

  Widget _buildCalendar(List<HabitRecordListItem> records) {
    DateTime today = DateTime.now();
    List<DateTime> last7Days = List.generate(7, (index) => today.subtract(Duration(days: index)));

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: last7Days.map((date) {
            bool hasRecord = records.any((record) => isSameDay(record.date, date));

            HabitRecordListItem? recordForDay;
            if (hasRecord) {
              recordForDay = records.firstWhere((record) => isSameDay(record.date, date));
            }
            return Container(
              margin: const EdgeInsets.only(right: 36),
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
                    Text('${date.month}/${date.day}'),
                    Icon(
                      hasRecord ? Icons.link : Icons.close,
                      color: hasRecord ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ));
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}
