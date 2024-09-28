import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/main.dart';

class TaskTitleInputField extends StatefulWidget {
  final int taskId;

  const TaskTitleInputField({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskTitleInputField> createState() => _TaskTitleInputFieldState();
}

class _TaskTitleInputFieldState extends State<TaskTitleInputField> {
  final Mediator _mediator = container.resolve<Mediator>();

  final TextEditingController _titleController = TextEditingController();
  GetTaskQueryResponse? _task;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchTask();
  }

  Future<void> _fetchTask() async {
    var response = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: widget.taskId),
    );
    setState(() {
      _task = response;
      _titleController.text = _task!.title;
    });
  }

  void _onTitleChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateTask();
    });
  }

  void _updateTask() {
    if (_task == null) return;

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

    _mediator.send(command);
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
          onToggleCompleted: _fetchTask,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: TextField(
            controller: _titleController,
            onChanged: _onTitleChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
