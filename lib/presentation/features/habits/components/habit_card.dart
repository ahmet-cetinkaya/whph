import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';

class HabitCard extends StatefulWidget {
  final HabitListItem habit;
  final VoidCallback onOpenDetails;

  const HabitCard({super.key, required this.habit, required this.onOpenDetails});

  @override
  _HabitCardState createState() => _HabitCardState();
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
      startDate: DateTime.now().subtract(const Duration(days: 7)),
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
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: DetailTable(rowData: [
              DetailTableRowData(
                  label: widget.habit.name,
                  icon: Icons.loop,
                  widget: FutureBuilder<List<HabitRecordListItem>>(
                    future: habitRecords,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      return _buildCalendar(snapshot.data!);
                    },
                  )),
            ]),
            onTap: widget.onOpenDetails,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<HabitRecordListItem> records) {
    DateTime today = DateTime.now();
    List<DateTime> last7Days = List.generate(7, (index) => today.subtract(Duration(days: index)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: last7Days.map((date) {
        bool hasRecord = records.any((record) => isSameDay(record.date, date));

        HabitRecordListItem? recordForDay;
        if (hasRecord) {
          recordForDay = records.firstWhere((record) => isSameDay(record.date, date));
        }
        return GestureDetector(
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
        );
      }).toList(),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}
