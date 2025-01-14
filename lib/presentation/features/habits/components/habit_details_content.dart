import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart'; // For handling dates
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';

class HabitDetailsContent extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final HabitsService _habitsService = container.resolve<HabitsService>();

  final String habitId;

  HabitDetailsContent({super.key, required this.habitId});

  @override
  State<HabitDetailsContent> createState() => _HabitDetailsContentState();
}

class _HabitDetailsContentState extends State<HabitDetailsContent> {
  GetHabitQueryResponse? _habit;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  GetListHabitRecordsQueryResponse? _habitRecords;
  GetListHabitTagsQueryResponse? _habitTags;

  DateTime currentMonth = DateTime.now();

  @override
  void initState() {
    _getHabit();
    _getHabitRecordsForMonth(currentMonth);
    _getHabitTags();
    widget._habitsService.onHabitSaved.addListener(_getHabit);

    super.initState();
  }

  @override
  void dispose() {
    widget._habitsService.onHabitSaved.removeListener(_getHabit);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getHabit() async {
    var query = GetHabitQuery(id: widget.habitId);
    var result = await widget._mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);

    if (mounted) {
      setState(() {
        _habit = result;
        _nameController.text = _habit!.name;
        _descriptionController.text = _habit!.description;
      });
    }
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
    var result = await widget._mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
    _habitRecords = result;
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    var command = AddHabitRecordCommand(habitId: habitId, date: date);
    await widget._mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
    if (mounted) {
      setState(() {
        _getHabitRecordsForMonth(currentMonth);
      });
    }
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await widget._mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
    if (mounted) {
      setState(() {
        _getHabitRecordsForMonth(currentMonth);
      });
    }
  }

  Future<void> _getHabitTags() async {
    try {
      var query = GetListHabitTagsQuery(habitId: widget.habitId, pageIndex: 0, pageSize: 100);
      var response = await widget._mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query);
      if (mounted) {
        setState(() {
          _habitTags = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while getting habit tags.");
      }
    }
  }

  Future<void> _addTag(String tagId) async {
    try {
      var command = AddHabitTagCommand(habitId: widget.habitId, tagId: tagId);
      await widget._mediator.send(command);
      await _getHabitTags();
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while adding tag.");
      }
    }
  }

  Future<void> _removeTag(String id) async {
    try {
      var command = RemoveHabitTagCommand(id: id);
      await widget._mediator.send(command);
      await _getHabitTags();
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while removing tag.");
      }
    }
  }

  void _onTagsSelected(List<String> tags) {
    if (_habitTags == null) return;

    var tagsToAdd = tags.where((tagId) => !_habitTags!.items.any((habitTag) => habitTag.tagId == tagId)).toList();
    var tagsToRemove = _habitTags!.items.where((habitTag) => !tags.contains(habitTag.tagId)).toList();

    for (var tagId in tagsToAdd) {
      _addTag(tagId);
    }
    for (var habitTag in tagsToRemove) {
      _removeTag(habitTag.id);
    }
  }

  Future<void> _saveHabit() async {
    var command = SaveHabitCommand(
      id: widget.habitId,
      name: _nameController.text,
      description: _descriptionController.text,
    );
    var result = await widget._mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

    widget._habitsService.onHabitSaved.value = result;
  }

  void _previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);

    if (nextMonth.isAfter(now)) return; // Don't allow navigation to future months

    setState(() {
      currentMonth = nextMonth;
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_habit == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags
          DetailTable(rowData: [
            DetailTableRowData(
              label: "Tags",
              icon: Icons.tag,
              widget: _buildTagSection(),
            ),
          ]),

          // Description
          Padding(
            padding: const EdgeInsets.only(bottom: 32, top: 16),
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

          // Records
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: const Icon(Icons.link),
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

        return ElevatedButton(
          onPressed: isFutureDate || isDisabled
              ? null
              : () async {
                  if (hasRecord) {
                    await _deleteHabitRecord(recordForDay!.id);
                  } else {
                    await _createHabitRecord(widget.habitId, date);
                  }
                },
          style: ElevatedButton.styleFrom(
            foregroundColor: AppTheme.textColor,
            disabledBackgroundColor: AppTheme.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            side: BorderSide(color: AppTheme.surface1),
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
        );
      }).toList(),
    );
  }

  Widget _buildTagSection() {
    if (_habitTags == null) {
      return const SizedBox.shrink();
    }

    if (_habitTags!.items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TagSelectDropdown(
            key: ValueKey(_habitTags!.items.length),
            isMultiSelect: true,
            onTagsSelected: _onTagsSelected,
            initialSelectedTags: _habitTags!.items
                .map((tag) => Tag(id: tag.tagId, name: tag.tagName, createdDate: DateTime.now()))
                .toList(),
            icon: Icons.add,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            TagSelectDropdown(
              key: ValueKey(_habitTags!.items.length),
              isMultiSelect: true,
              onTagsSelected: _onTagsSelected,
              initialSelectedTags: _habitTags!.items
                  .map((tag) => Tag(id: tag.tagId, name: tag.tagName, createdDate: DateTime.now()))
                  .toList(),
              icon: Icons.add,
            ),
            ..._habitTags!.items.map((habitTag) {
              return Chip(
                label: Text(habitTag.tagName),
                onDeleted: () {
                  _removeTag(habitTag.id);
                },
              );
            })
          ],
        ),
      ],
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}
