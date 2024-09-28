import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/components/date_time_picker_field.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';
import 'package:whph/presentation/features/shared/components/header.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/domain/features/tasks/task.dart';

class TaskDetailsContent extends StatefulWidget {
  final int taskId;

  const TaskDetailsContent({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskDetailsContent> createState() => _TaskDetailsContentState();
}

class _TaskDetailsContentState extends State<TaskDetailsContent> {
  final Mediator _mediator = container.resolve<Mediator>();

  GetTaskQueryResponse? _task;
  GetListTaskTagsQueryResponse? _taskTags;
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<DropdownOption<EisenhowerPriority>> priorityOptions = [
    DropdownOption(label: 'None', value: EisenhowerPriority.none),
    DropdownOption(label: 'Urgent & Important', value: EisenhowerPriority.urgentImportant),
    DropdownOption(label: 'Not Urgent & Important', value: EisenhowerPriority.notUrgentImportant),
    DropdownOption(label: 'Urgent & Not Important', value: EisenhowerPriority.urgentNotImportant),
    DropdownOption(label: 'Not Urgent & Not Important', value: EisenhowerPriority.notUrgentNotImportant),
  ];

  final List<DropdownOption<int>> _tagOptions = [];
  final List<int> _estimatedTimeOptions = [0, 15, 30, 45, 60, 90, 120, 180, 240];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchTask(), _fetchTaskTags()]);
    await _fetchTagOptions();
  }

  Future<void> _fetchTask() async {
    var query = GetTaskQuery(id: widget.taskId);
    var response = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
    setState(() {
      _task = response;
      _plannedDateController.text =
          _task!.plannedDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.plannedDate!) : '';
      _deadlineDateController.text =
          _task!.deadlineDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.deadlineDate!) : '';
      _descriptionController.text = _task!.description ?? '';
    });
  }

  Future<void> _fetchTaskTags() async {
    var query = GetListTaskTagsQuery(taskId: widget.taskId, pageIndex: 0, pageSize: 100);
    var response = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(query);
    setState(() {
      _taskTags = response;
    });
  }

  Future<void> _fetchTagOptions() async {
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100);
    var response = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
    setState(() {
      _tagOptions
        ..clear()
        ..add(DropdownOption(label: 'Add Tag', value: 0))
        ..addAll(response.items
            .where((tag) => !_taskTags!.items.any((taskTag) => taskTag.tagId == tag.id))
            .map((tag) => DropdownOption(label: tag.name, value: tag.id)));
    });
  }

  Future<void> _updateTask() async {
    if (_task == null) return;

    var saveCommand = SaveTaskCommand(
      id: _task!.id,
      title: _task!.title,
      description: _descriptionController.text,
      plannedDate: DateTime.tryParse(_plannedDateController.text),
      deadlineDate: DateTime.tryParse(_deadlineDateController.text),
      priority: _task!.priority,
      estimatedTime: _task!.estimatedTime,
      elapsedTime: _task!.elapsedTime,
      isCompleted: _task!.isCompleted,
    );

    await _mediator.send<SaveTaskCommand, void>(saveCommand);
  }

  Future<void> _addTag(int tagId) async {
    if (tagId == 0) return; // Skip if the user selects the "Add Tag" option

    var command = AddTaskTagCommand(taskId: _task!.id, tagId: tagId);
    await _mediator.send(command);
    await _fetchTaskTags();
    await _fetchTagOptions();
  }

  Future<void> _removeTag(int id) async {
    var command = RemoveTaskTagCommand(id: id);
    await _mediator.send(command);
    await _fetchTaskTags();
    await _fetchTagOptions();
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null || _taskTags == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailTable(rowData: [
              DetailTableRowData(label: "Priority", icon: Icons.priority_high, widget: _buildPriorityDropdown()),
              DetailTableRowData(
                  label: "Planned Date",
                  icon: Icons.calendar_today,
                  widget: DateTimePickerField(
                    controller: _plannedDateController,
                    hintText: '',
                    onConfirm: (date) {
                      _task?.plannedDate = date;
                      _updateTask();
                    },
                  )),
              DetailTableRowData(
                label: "Time",
                icon: Icons.timer,
                widget: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobile = MediaQuery.of(context).size.width < 600;

                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildTimeWidgets(),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildTimeWidgets(spacing: 64.0),
                          );
                  },
                ),
              ),
              DetailTableRowData(
                  label: "Deadline Date",
                  icon: Icons.calendar_today,
                  widget: DateTimePickerField(
                    controller: _deadlineDateController,
                    hintText: '',
                    onConfirm: (date) {
                      _task?.deadlineDate = date;
                      _updateTask();
                    },
                  )),
              DetailTableRowData(label: "Tags", icon: Icons.tag, widget: _buildTagSection()),
            ]),
            const Header(text: 'Description', level: 1),
            MarkdownAutoPreview(
              controller: _descriptionController,
              onChanged: (value) {
                _task?.description = value;
                _updateTask();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return DropdownButton<DropdownOption<EisenhowerPriority>>(
      value: priorityOptions.firstWhere(
        (priority) => priority.value == _task?.priority,
        orElse: () => priorityOptions.first,
      ),
      onChanged: (value) {
        setState(() {
          _task?.priority = value?.value;
        });
        _updateTask();
      },
      items: priorityOptions
          .map((priority) => DropdownMenuItem(
                value: priority,
                child: Text(priority.label),
              ))
          .toList(),
    );
  }

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            DropdownButton<DropdownOption<int?>>(
              value: _tagOptions.first,
              onChanged: (DropdownOption<int?>? newValue) {
                if (newValue?.value != null) _addTag(newValue!.value!);
              },
              items: _tagOptions
                  .map((tag) => DropdownMenuItem(
                        value: tag,
                        child: Text(tag.label),
                      ))
                  .toList(),
            ),
            ..._taskTags!.items.map((tag) {
              return Chip(
                label: Text(tag.tagName),
                onDeleted: () {
                  _removeTag(tag.id);
                },
              );
            })
          ],
        ),
      ],
    );
  }

  List<Widget> _buildTimeWidgets({double spacing = 0.0}) {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimated Time'),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  int nextIndex = _estimatedTimeOptions.indexOf(_task!.estimatedTime ?? 0) - 1;
                  if (nextIndex < 0) nextIndex = _estimatedTimeOptions.length - 1;
                  setState(() {
                    _task!.estimatedTime = _estimatedTimeOptions[nextIndex];
                  });
                  _updateTask();
                },
                child: const Icon(Icons.remove),
              ),
              Text(
                _task!.estimatedTime != null ? '${_task!.estimatedTime!} min' : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  int nextIndex = _estimatedTimeOptions.indexOf(_task!.estimatedTime ?? 0) + 1;
                  if (nextIndex >= _estimatedTimeOptions.length) nextIndex = 0;
                  setState(() {
                    _task!.estimatedTime = _estimatedTimeOptions[nextIndex];
                  });
                  _updateTask();
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      SizedBox(width: spacing),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PomodoroTimer(
            onTimeUpdate: (value) {
              _task!.elapsedTime = (_task!.elapsedTime ?? 0) + 1;
              _updateTask();
            },
          ),
        ],
      ),
      SizedBox(width: spacing),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Elapsed Time'),
          Text(
            '${_task!.elapsedTime != null ? _task!.elapsedTime! ~/ 60 : 0} min',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ];
  }
}
