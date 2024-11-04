import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';

class TaskTitleInputField extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final TasksService _tasksService = container.resolve<TasksService>();

  final String taskId;

  TaskTitleInputField({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskTitleInputField> createState() => _TaskTitleInputFieldState();
}

class _TaskTitleInputFieldState extends State<TaskTitleInputField> {
  GetTaskQueryResponse? _task;
  final TextEditingController _titleController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    _getTask();
    widget._tasksService.onTaskSaved.addListener(_getTask);
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debounce?.cancel();
    widget._tasksService.onTaskSaved.removeListener(_getTask);
    super.dispose();
  }

  Future<void> _getTask() async {
    var query = GetTaskQuery(id: widget.taskId);
    var result = await widget._mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
    setState(() {
      _task = result;
      _titleController.text = _task!.title;
    });
  }

  void _onTitleChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateTask();
    });
  }

  Future<void> _updateTask() async {
    var command = SaveTaskCommand(
      id: widget.taskId,
      title: _titleController.text,
      deadlineDate: _task!.deadlineDate,
      description: _task!.description,
      elapsedTime: _task!.elapsedTime,
      estimatedTime: _task!.estimatedTime,
      isCompleted: _task!.isCompleted,
      plannedDate: _task!.plannedDate,
      priority: _task!.priority,
    );
    var result = await widget._mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

    widget._tasksService.onTaskSaved.value = result;
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        TaskCompleteButton(
          taskId: widget.taskId,
          isCompleted: _task!.isCompleted,
          onToggleCompleted: _getTask,
        ),
        Expanded(
          child: TextField(
            controller: _titleController,
            onChanged: _onTitleChanged,
            decoration: const InputDecoration(border: InputBorder.none, filled: false),
          ),
        ),
      ],
    );
  }
}
