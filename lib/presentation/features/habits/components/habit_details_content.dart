import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/header.dart';
import 'package:intl/intl.dart'; // For handling dates

class HabitDetailsContent extends StatefulWidget {
  final String habitId;
  final bool isNameFieldVisible;

  const HabitDetailsContent({super.key, required this.habitId, this.isNameFieldVisible = true});

  @override
  State<HabitDetailsContent> createState() => _HabitDetailsContentState();
}

class _HabitDetailsContentState extends State<HabitDetailsContent> {
  final Mediator mediator = container.resolve<Mediator>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late Future<List<HabitRecordListItem>> habitRecords;

  bool isLoading = false;
  DateTime currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _getHabit();
    habitRecords = Future.value([]); // Initialize with an empty list
    habitRecords = _getHabitRecordsForMonth(currentMonth); // Fetch actual records
  }

  Future<void> _getHabit() async {
    setState(() {
      isLoading = true;
    });

    var query = GetHabitQuery(id: widget.habitId);
    var response = await mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
    _nameController.text = response.name;
    _descriptionController.text = response.description;

    setState(() {
      isLoading = false;
    });
  }

  Future<List<HabitRecordListItem>> _getHabitRecordsForMonth(DateTime month) async {
    var firstDayOfMonth = DateTime(month.year, month.month, 1);
    var lastDayOfMonth = DateTime(month.year, month.month + 1, 0); // Last day of the month

    var query = GetListHabitRecordsQuery(
      pageIndex: 0,
      pageSize: 31,
      habitId: widget.habitId,
      startDate: firstDayOfMonth,
      endDate: lastDayOfMonth,
    );
    var queryResponse = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
    return queryResponse.items;
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    var command = AddHabitRecordCommand(habitId: habitId, date: date);
    await mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
    setState(() {
      habitRecords = _getHabitRecordsForMonth(currentMonth); // Update habit records
    });
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
    setState(() {
      habitRecords = _getHabitRecordsForMonth(currentMonth); // Update habit records
    });
  }

  void _previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
      habitRecords = _getHabitRecordsForMonth(currentMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      habitRecords = _getHabitRecordsForMonth(currentMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isNameFieldVisible) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Habit Name'),
                    onChanged: (value) => _saveHabit(),
                  ),
                  const SizedBox(height: 8.0),
                ],
                const Header(text: 'Description'),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (value) => _saveHabit(),
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _previousMonth,
                    ),
                    Text(
                      DateFormat.yMMMM().format(currentMonth),
                      style: const TextStyle(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                _buildWeekdayLabels(), // Added week day labels
                const SizedBox(height: 4.0),
                FutureBuilder<List<HabitRecordListItem>>(
                  future: habitRecords,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    return _buildMonthlyCalendar(snapshot.data!);
                  },
                ),
              ],
            ),
    );
  }

  // Widget for Weekday labels
  Widget _buildWeekdayLabels() {
    const List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: daysOfWeek
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMonthlyCalendar(List<HabitRecordListItem> records) {
    int daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    List<DateTime> days =
        List.generate(daysInMonth, (index) => DateTime(currentMonth.year, currentMonth.month, index + 1));

    return GridView.count(
      crossAxisCount: 7, // 7 columns for each day of the week
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      padding: EdgeInsets.zero,
      children: days.map((date) {
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
              await _createHabitRecord(widget.habitId, date);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300), // Light border around each day
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${date.day}', style: const TextStyle(fontSize: 12)), // Increased text size for better readability
                Icon(
                  hasRecord ? Icons.link : Icons.close,
                  color: hasRecord ? Colors.green : Colors.red,
                  size: 16, // Adjusted icon size to be more compact
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  Future<void> _saveHabit() async {
    var command = SaveHabitCommand(
      id: widget.habitId,
      name: _nameController.text,
      description: _descriptionController.text,
    );
    await mediator.send(command);
  }
}
