import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/components/date_time_picker_field.dart';
import 'package:whph/core/acore/components/numeric_input.dart';
import 'package:whph/main.dart';
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

  final List<DropdownOption<EisenhowerPriority>> priorityOptions = [
    DropdownOption(label: 'None', value: EisenhowerPriority.none),
    DropdownOption(label: 'Urgent & Important', value: EisenhowerPriority.urgentImportant),
    DropdownOption(label: 'Not Urgent & Important', value: EisenhowerPriority.notUrgentImportant),
    DropdownOption(label: 'Urgent & Not Important', value: EisenhowerPriority.urgentNotImportant),
    DropdownOption(label: 'Not Urgent & Not Important', value: EisenhowerPriority.notUrgentNotImportant),
  ];
  final List<DropdownOption<int?>> _tagOptions = [
    DropdownOption(label: 'Add new', value: null),
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();
  final TextEditingController _estimatedTimeController = TextEditingController();
  final TextEditingController _elapsedTimeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTask();
    _fetchTaskTags().then((_) => _fetchTagOptions());
  }

  Future<void> _fetchTask() async {
    var query = GetTaskQuery(id: widget.taskId);
    var response = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
    setState(() {
      _task = response;
      _titleController.text = _task!.title;
      _descriptionController.text = _task!.description ?? '';
      _plannedDateController.text = _task!.plannedDate?.toString() ?? '';
      _deadlineDateController.text = _task!.deadlineDate?.toString() ?? '';
      _estimatedTimeController.text = _task!.estimatedTime?.toString() ?? '';
      _elapsedTimeController.text = _task!.elapsedTime?.toString() ?? '';
    });
  }

  Future<void> _fetchTaskTags() async {
    var query = GetListTaskTagsQuery(taskId: widget.taskId, pageIndex: 0, pageSize: 100); //TODO: Add lazy loading
    var response = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(query);
    setState(() {
      _taskTags = response;
    });
  }

  Future<void> _fetchTagOptions() async {
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100); // TODO: Add lazy loading
    var response = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
    setState(() {
      _tagOptions.removeRange(1, _tagOptions.length);
      _tagOptions.addAll(response.items
          .where((tag) => !_taskTags!.items.any((taskTag) => taskTag.tagId == tag.id))
          .map((tag) => DropdownOption(label: tag.name, value: tag.id)));
    });
  }

  Future<void> _updateTask() async {
    if (_task == null) return;

    var saveCommand = SaveTaskCommand(
      id: _task!.id,
      title: _titleController.text,
      description: _descriptionController.text,
      plannedDate: DateTime.tryParse(_plannedDateController.text),
      deadlineDate: DateTime.tryParse(_deadlineDateController.text),
      priority: (priorityOptions.firstWhere((option) => option.value == _task?.priority,
          orElse: () => priorityOptions.first)).value,
      estimatedTime: int.tryParse(_estimatedTimeController.text),
      elapsedTime: int.tryParse(_elapsedTimeController.text),
      isCompleted: _task!.isCompleted,
    );

    await _mediator.send<SaveTaskCommand, void>(saveCommand);
  }

  Future<void> _addTag(int tagId) async {
    var command = AddTaskTagCommand(taskId: _task!.id, tagId: tagId);
    await _mediator.send(command);
    setState(() {
      _tagOptions.removeWhere((element) => element.value == tagId);
    });
    _fetchTaskTags();
  }

  Future<void> _removeTag(int id) async {
    var command = RemoveTaskTagCommand(id: id);
    await _mediator.send(command);
    setState(() {
      _taskTags!.items.removeWhere((element) => element.id == id);
    });
    _fetchTagOptions();
  }

  @override
  Widget build(BuildContext context) {
    return _task == null || _taskTags == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PRIORITY
              const Text(
                'Priority:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<DropdownOption<EisenhowerPriority>>(
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
                items: priorityOptions.map<DropdownMenuItem<DropdownOption<EisenhowerPriority>>>(
                  (DropdownOption<EisenhowerPriority> priority) {
                    return DropdownMenuItem<DropdownOption<EisenhowerPriority>>(
                      value: priority,
                      child: Text(priority.label),
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 16.0),

              // PLANNED DATE
              const Text(
                'Planned Date:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DateTimePickerField(
                controller: _plannedDateController,
                hintText: '',
                onConfirm: (date) {
                  setState(() {
                    _task?.plannedDate = date;
                  });
                  _updateTask();
                },
              ),
              const SizedBox(height: 16.0),

              // DEADLINE DATE
              const Text(
                'Deadline Date:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DateTimePickerField(
                controller: _deadlineDateController,
                hintText: '',
                onConfirm: (date) {
                  setState(() {
                    _task?.deadlineDate = date;
                  });
                  _updateTask();
                },
              ),
              const SizedBox(height: 16.0),

              // ESTIMATED TIME
              const Text(
                'Estimated Time:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              NumericInput(
                initialValue: _task?.estimatedTime ?? 0,
                minValue: 0,
                maxValue: 1000,
                incrementValue: 5,
                decrementValue: 5,
                onValueChanged: (value) {
                  setState(() {
                    _task?.estimatedTime = value;
                  });
                  _updateTask();
                },
              ),

              // ELAPSED TIME
              Text(
                'Elapsed Time: ${_task?.elapsedTime != null ? (_task!.elapsedTime! / 60.0).roundToDouble() : '0'} min',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              PomodoroTimer(onTimeUpdate: (duration) {
                setState(() {
                  _task!.elapsedTime = (_task!.elapsedTime ?? 0) + 1;
                });
                _updateTask();
              }),
              const SizedBox(height: 16.0),

              // TAGS
              const Text(
                'Tags:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<DropdownOption<int?>>(
                value: _tagOptions.first,
                onChanged: (DropdownOption<int?>? newValue) {
                  if (newValue?.value == null) return;
                  _addTag(newValue!.value!);
                },
                items: _tagOptions.map<DropdownMenuItem<DropdownOption<int?>>>(
                  (DropdownOption<int?> tag) {
                    return DropdownMenuItem<DropdownOption<int?>>(
                      value: tag,
                      child: Text(tag.label),
                    );
                  },
                ).toList(),
              ),
              Wrap(
                children: _taskTags!.items.map((tag) {
                  return Chip(
                    label: Text(tag.tagName),
                    onDeleted: () {
                      _removeTag(tag.id);
                    },
                  );
                }).toList(),
              ),

              // DESCRIPTION
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              MarkdownAutoPreview(
                controller: _descriptionController,
                emojiConvert: true,
                onChanged: (value) {
                  setState(() {
                    _task?.description = value;
                  });
                  _updateTask();
                },
              ),
              const SizedBox(height: 15.0),
            ],
          );
  }
}
