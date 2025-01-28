import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';

class TaskTitleInputField extends StatefulWidget {
  final _mediator = container.resolve<Mediator>();
  final _tasksService = container.resolve<TasksService>();
  final _translationService = container.resolve<ITranslationService>();

  final String taskId;
  final VoidCallback? onTaskUpdated;

  TaskTitleInputField({
    super.key,
    required this.taskId,
    this.onTaskUpdated,
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
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getTask() async {
    try {
      var query = GetTaskQuery(id: widget.taskId);
      var result = await widget._mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
      if (mounted) {
        setState(() {
          _task = result;
          _titleController.text = _task!.title;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget._translationService.translate(TaskTranslationKeys.getTaskError),
        );
      }
    }
  }

  void _onTitleChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateTask();
    });
  }

  Future<void> _updateTask() async {
    try {
      var command = SaveTaskCommand(
        id: widget.taskId,
        title: _titleController.text,
        deadlineDate: _task!.deadlineDate,
        description: _task!.description,
        estimatedTime: _task!.estimatedTime,
        isCompleted: _task!.isCompleted,
        plannedDate: _task!.plannedDate,
        priority: _task!.priority,
      );
      var result = await widget._mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      widget._tasksService.onTaskSaved.value = result;
      widget.onTaskUpdated?.call();
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget._translationService.translate(TaskTranslationKeys.saveTaskError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return const SizedBox.shrink();
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
            decoration: InputDecoration(
              suffixIcon: Tooltip(
                message: widget._translationService.translate(TaskTranslationKeys.editTitleTooltip),
                child: const Icon(Icons.edit, size: AppTheme.iconSizeSmall),
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
