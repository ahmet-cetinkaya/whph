import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/quick_task_bottom_sheet.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';

class TaskAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String taskId)? onTaskCreated;
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;

  const TaskAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTaskCreated,
    this.initialTagIds,
    this.initialPlannedDate,
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
        initialPlannedDate: widget.initialPlannedDate,
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
      icon: Icon(SharedUiConstants.addIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
