import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/components/date_time_picker_field.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';

class TaskDetailsContent extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final TasksService _tasksService = container.resolve<TasksService>();

  final String taskId;

  TaskDetailsContent({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskDetailsContent> createState() => _TaskDetailsContentState();
}

class _TaskDetailsContentState extends State<TaskDetailsContent> {
  GetTaskQueryResponse? _task;
  GetListTaskTagsQueryResponse? _taskTags;
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<DropdownOption<EisenhowerPriority>> _priorityOptions = [
    DropdownOption(label: 'None', value: EisenhowerPriority.none),
    DropdownOption(label: 'Urgent & Important', value: EisenhowerPriority.urgentImportant),
    DropdownOption(label: 'Not Urgent & Important', value: EisenhowerPriority.notUrgentImportant),
    DropdownOption(label: 'Urgent & Not Important', value: EisenhowerPriority.urgentNotImportant),
    DropdownOption(label: 'Not Urgent & Not Important', value: EisenhowerPriority.notUrgentNotImportant),
  ];

  final List<int> _estimatedTimeOptions = [0, 15, 30, 45, 60, 90, 120, 180, 240];

  @override
  void initState() {
    _getInitialData();
    widget._tasksService.onTaskSaved.addListener(_getTask);
    super.initState();
  }

  @override
  void dispose() {
    widget._tasksService.onTaskSaved.removeListener(_getTask);
    super.dispose();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getTask(), _getTaskTags()]);
  }

  Future<void> _getTask() async {
    try {
      var query = GetTaskQuery(id: widget.taskId);
      var response = await widget._mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
      if (mounted) {
        setState(() {
          _task = response;
          _plannedDateController.text =
              _task!.plannedDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.plannedDate!) : '';
          _deadlineDateController.text =
              _task!.deadlineDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.deadlineDate!) : '';
          _descriptionController.text = _task!.description ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while getting task.");
      }
    }
  }

  Future<void> _getTaskTags() async {
    try {
      var query = GetListTaskTagsQuery(taskId: widget.taskId, pageIndex: 0, pageSize: 100);
      var response = await widget._mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(query);
      if (mounted) {
        setState(() {
          _taskTags = response;
        });
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while getting task tags.");
      }
    }
  }

  Future<void> _updateTask() async {
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
    try {
      var result = await widget._mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);
      widget._tasksService.onTaskSaved.value = result;
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while saving task.");
      }
    }
  }

  Future<void> _addTag(String tagId) async {
    try {
      var command = AddTaskTagCommand(taskId: _task!.id, tagId: tagId);
      await widget._mediator.send(command);
      await _getTaskTags();
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while adding tag.");
      }
    }
  }

  Future<void> _removeTag(String id) async {
    try {
      var command = RemoveTaskTagCommand(id: id);
      await widget._mediator.send(command);
      await _getTaskTags();
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Unexpected error occurred while removing tag.");
      }
    }
  }

  void _onTagsSelected(List<String> tags) {
    var tagsToAdd = tags.where((tagId) => !_taskTags!.items.any((taskTag) => taskTag.tagId == tagId)).toList();
    var tagsToRemove = _taskTags!.items.where((taskTag) => !tags.contains(taskTag.tagId)).toList();
    for (var tagId in tagsToAdd) {
      _addTag(tagId);
    }
    for (var taskTag in tagsToRemove) {
      _removeTag(taskTag.id);
    }
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
              // Tags
              DetailTableRowData(label: "Tags", icon: Icons.tag, widget: _buildTagSection()),

              // Priority
              DetailTableRowData(
                  label: "Priority",
                  icon: Icons.priority_high,
                  widget: DropdownMenu(
                    dropdownMenuEntries: _priorityOptions
                        .map((option) => DropdownMenuEntry(label: option.label, value: option.value))
                        .toList(),
                    initialSelection: _task!.priority ?? EisenhowerPriority.none,
                    onSelected: (value) {
                      if (!mounted) return;
                      setState(() {
                        _task!.priority = value;
                        _updateTask();
                      });
                    },
                  )),

              // Planned Date
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
                ),
              ),

              // Estimated Time
              DetailTableRowData(
                label: "Estimated Time",
                icon: Icons.question_mark,
                widget: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        int nextIndex = _estimatedTimeOptions.indexOf(_task!.estimatedTime ?? 0) - 1;
                        if (nextIndex < 0) nextIndex = _estimatedTimeOptions.length - 1;
                        if (!mounted) return;
                        setState(() {
                          _task!.estimatedTime = _estimatedTimeOptions[nextIndex];
                        });
                        _updateTask();
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _task!.estimatedTime != null ? '${_task!.estimatedTime!} min' : '0 min',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        int nextIndex = _estimatedTimeOptions.indexOf(_task!.estimatedTime ?? 0) + 1;
                        if (nextIndex >= _estimatedTimeOptions.length) nextIndex = 0;
                        if (!mounted) return;
                        setState(() {
                          _task!.estimatedTime = _estimatedTimeOptions[nextIndex];
                        });
                        _updateTask();
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),

              // Pomodoro Timer
              DetailTableRowData(
                label: "Timer",
                icon: Icons.timer,
                widget: PomodoroTimer(
                  onTimeUpdate: (value) {
                    _task!.elapsedTime = (_task!.elapsedTime ?? 0) + 1;
                    _updateTask();
                  },
                ),
              ),

              // Elapsed Time
              DetailTableRowData(
                label: "Elapsed Time",
                icon: Icons.timelapse_outlined,
                widget: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: Text(
                    '${_task!.elapsedTime != null ? _task!.elapsedTime! ~/ 60 : 0} min',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Deadline Date
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
            ]),

            // Description
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

                _updateTask();
              },
              hintText: 'Add a description...',
              toolbarBackground: AppTheme.surface1,
            ),
          ],
        ),
      ),
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
            // Select
            TagSelectDropdown(
              key: ValueKey(_taskTags!.items.length),
              isMultiSelect: true,
              onTagsSelected: _onTagsSelected,
              initialSelectedTags: _taskTags!.items
                  .map((tag) => Tag(id: tag.tagId, name: tag.tagName, createdDate: DateTime.now()))
                  .toList(),
              icon: Icons.add,
            ),

            // List
            ..._taskTags!.items.map((taskTag) {
              return Chip(
                label: Text(taskTag.tagName),
                onDeleted: () {
                  _removeTag(taskTag.id);
                },
              );
            })
          ],
        ),
      ],
    );
  }
}
