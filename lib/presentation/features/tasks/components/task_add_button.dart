import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tasks/components/quick_task_bottom_sheet.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickTaskBottomSheet(
        initialTagIds: widget.initialTagIds,
        onTaskCreated: (taskId) {
          if (widget.onTaskCreated != null) {
            widget.onTaskCreated!(taskId);
          }
        },
      ),
    );
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
