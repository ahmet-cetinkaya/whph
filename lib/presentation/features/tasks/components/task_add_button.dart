import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class TaskAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String taskId)? onTaskCreated;
  final List<String>? initialTagIds;

  const TaskAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTaskCreated,
    this.initialTagIds,
  });

  @override
  State<TaskAddButton> createState() => _TaskAddButtonState();
}

class _TaskAddButtonState extends State<TaskAddButton> {
  final Mediator mediator = container.resolve<Mediator>();
  bool isLoading = false;

  Future<void> _createTask(BuildContext context) async {
    if (isLoading) return;

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      var command = SaveTaskCommand(
        title: "New Task",
        description: "# Steps\n - [ ] Step 1\n - [ ] Step 2\n# Notes\n",
        tagIds: widget.initialTagIds,
      );
      var response = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      if (widget.onTaskCreated != null) widget.onTaskCreated!(response.id);
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: 'Unexpected error occurred while saving task.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _createTask(context),
      icon: const Icon(Icons.add),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
