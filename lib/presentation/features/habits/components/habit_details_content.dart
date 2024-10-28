import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:intl/intl.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart'; // For handling dates

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

  GetListHabitRecordsQueryResponse? _habitRecords;

  bool _isLoading = false;
  DateTime currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _getHabit();
    _getHabitRecordsForMonth(currentMonth);
  }

  Future<void> _getHabit() async {
    setState(() {
      _isLoading = true;
    });

    var query = GetHabitQuery(id: widget.habitId);
    var response = await mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
    _nameController.text = response.name;
    _descriptionController.text = response.description;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getHabitRecordsForMonth(DateTime month) async {
    var firstDayOfMonth = DateTime(month.year, month.month - 1, 23);
    var lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    var query = GetListHabitRecordsQuery(
      pageIndex: 0,
      pageSize: 37,
      habitId: widget.habitId,
      startDate: firstDayOfMonth,
      endDate: lastDayOfMonth,
    );
    var result = await mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
    _habitRecords = result;
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    var command = AddHabitRecordCommand(habitId: habitId, date: date);
    await mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
    setState(() {
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
    setState(() {
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  void _previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: _isLoading
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

                // Description
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: const Icon(Icons.description),
                            ),
                            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      MarkdownAutoPreview(
                        controller: _descriptionController,
                        onChanged: (value) {
                          var isEmptyWhitespace = value.trim().isEmpty;
                          if (isEmptyWhitespace) {
                            _descriptionController.clear();
                          }

                          _saveHabit();
                        },
                        hintText: 'Add a description...',
                        toolbarBackground: AppTheme.surface1,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: const Icon(Icons.description),
                      ),
                      const Text('Records', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                Center(
                  child: SizedBox(
                    width: 600,
                    child: Column(
                      children: [
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
                        _buildWeekdayLabels(),
                        const SizedBox(height: 4.0),
                        if (_habitRecords == null) const Center(child: CircularProgressIndicator()),
                        if (_habitRecords != null) _buildMonthlyCalendar(_habitRecords!.items)
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

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
    // Calculate the days of the month
    int daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    int firstWeekdayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    int previousMonthDays = firstWeekdayOfMonth - 1;

    // Calculate the days of the previous month
    DateTime firstDayOfPreviousMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    int daysInPreviousMonth = DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month + 1, 0).day;

    // Calculate the days of the next month
    int lastWeekdayOfMonth = DateTime(currentMonth.year, currentMonth.month, daysInMonth).weekday;
    int nextMonthDays = 7 - lastWeekdayOfMonth;

    List<DateTime> days = List.generate(daysInMonth + previousMonthDays + nextMonthDays, (index) {
      if (index < previousMonthDays) {
        return DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month,
            daysInPreviousMonth - previousMonthDays + index + 1);
      } else if (index >= previousMonthDays + daysInMonth) {
        return DateTime(currentMonth.year, currentMonth.month + 1, index - (previousMonthDays + daysInMonth) + 1);
      } else {
        return DateTime(currentMonth.year, currentMonth.month, index - previousMonthDays + 1);
      }
    });

    return GridView.count(
      crossAxisCount: 7, // 7 columns for each day of the week
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: days.map((date) {
        bool isCurrentMonth = date.month == currentMonth.month;
        bool hasRecord = records.any((record) => isSameDay(record.date, date));
        bool isFutureDate = date.isAfter(DateTime.now());
        bool isDisabled = date.day > 10 && isCurrentMonth;

        HabitRecordListItem? recordForDay;
        if (hasRecord) {
          recordForDay = records.firstWhere((record) => isSameDay(record.date, date));
        }
        return GestureDetector(
          onTap: isFutureDate || isDisabled
              ? null
              : () async {
                  if (hasRecord) {
                    await _deleteHabitRecord(recordForDay!.id);
                  } else {
                    await _createHabitRecord(widget.habitId, date);
                  }
                },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.surface1),
              borderRadius: BorderRadius.circular(8.0),
              color: isFutureDate ? AppTheme.surface2 : AppTheme.surface1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Day of the month
                Text(
                  '${date.day}',
                  style: TextStyle(fontSize: 12),
                ),

                // Icon
                if (date.isAfter(DateTime.now())) const Icon(Icons.lock, size: 16, color: Colors.grey),
                if (date.isBefore(DateTime.now()))
                  Icon(hasRecord ? Icons.link : Icons.close, color: hasRecord ? Colors.green : Colors.red, size: 20),
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
