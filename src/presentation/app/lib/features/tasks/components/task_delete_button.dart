import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/tasks/commands/delete_task_command.dart';
import 'package:whph/main.dart';
import 'package:whph/features/tasks/services/tasks_service.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/constants/shared_ui_constants.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/shared/utils/async_error_handler.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';

class TaskDeleteButton extends StatefulWidget {
  final String taskId;
  final VoidCallback? onDeleteSuccess;
  final Color? buttonColor;
  final Color? buttonBackgroundColor;

  const TaskDeleteButton({
    super.key,
    required this.taskId,
    this.onDeleteSuccess,
    this.buttonColor,
    this.buttonBackgroundColor,
  });

  @override
  State<TaskDeleteButton> createState() => _TaskDeleteButtonState();
}

class _TaskDeleteButtonState extends State<TaskDeleteButton> {
  final Mediator _mediator = container.resolve<Mediator>();
  final TasksService _tasksService = container.resolve<TasksService>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  Future<void> _deleteTask(BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.taskDeleteError),
      operation: () async {
        final command = DeleteTaskCommand(id: widget.taskId);
        await _mediator.send(command);
      },
      onSuccess: () {
        // Notify task deleted with task ID as non-nullable parameter
        _tasksService.notifyTaskDeleted(widget.taskId);

        if (widget.onDeleteSuccess != null) {
          widget.onDeleteSuccess!();
        }
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(TaskTranslationKeys.taskDeleteTitle)),
        content: Text(_translationService.translate(TaskTranslationKeys.taskDeleteMessage)),
        actions: [
          TextButton(
            onPressed: () => _cancelDelete(context),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => _confirmDeleteAction(context),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) _deleteTask(context);
  }

  void _cancelDelete(BuildContext context) {
    Navigator.of(context).pop(false);
  }

  void _confirmDeleteAction(BuildContext context) {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _confirmDelete(context),
      icon: Icon(SharedUiConstants.deleteIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
      tooltip: _translationService.translate(SharedTranslationKeys.deleteButton),
    );
  }
}
