import 'package:flutter/material.dart';
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
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/habits/components/habit_calendar_view.dart';
import 'package:whph/presentation/features/habits/components/habit_statistics_view.dart';
import 'package:whph/presentation/features/habits/components/habit_tag_section.dart';

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
        _getHabit();
      });
    }
  }

  Future<void> _deleteHabitRecord(String id) async {
    var command = DeleteHabitRecordCommand(id: id);
    await widget._mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
    if (mounted) {
      setState(() {
        _getHabitRecordsForMonth(currentMonth);
        _getHabit();
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
          DetailTable(
            rowData: [
              DetailTableRowData(
                label: "Tags",
                icon: Icons.tag,
                widget: _habitTags == null
                    ? const SizedBox.shrink()
                    : HabitTagSection(
                        habitTags: _habitTags!,
                        onTagsSelected: _onTagsSelected,
                        onRemoveTag: _removeTag,
                      ),
              ),
            ],
          ),

          // Description
          _buildDescriptionSection(),

          const Divider(),

          // Calendar
          _buildRecordsHeader(),
          if (_habitRecords != null)
            HabitCalendarView(
              currentMonth: currentMonth,
              records: _habitRecords!.items,
              onDeleteRecord: _deleteHabitRecord,
              onCreateRecord: _createHabitRecord,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              habitId: widget.habitId,
            ),

          const Divider(),

          // Statistics
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: HabitStatisticsView(statistics: _habit!.statistics),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSectionHeader(Icons.description, 'Description'),
              const SizedBox(width: 8),
              Text(
                "Click to edit",
                style: TextStyle(fontSize: 12, color: AppTheme.disabledColor),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: MarkdownAutoPreview(
                controller: _descriptionController,
                onChanged: _onDescriptionChanged,
                hintText: 'Add a description...',
                toolbarBackground: AppTheme.surface1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildSectionHeader(Icons.link, 'Records'),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Icon(icon),
        ),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _onDescriptionChanged(String value) {
    if (value.trim().isEmpty) {
      _descriptionController.clear();
    }
    _saveHabit();
  }
}
