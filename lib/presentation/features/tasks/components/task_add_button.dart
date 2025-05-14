import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/quick_task_bottom_sheet.dart';
import 'package:whph/presentation/features/tasks/models/task_data.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String taskId, TaskData taskData)? onTaskCreated;
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final String? initialParentTaskId;

  const TaskAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTaskCreated,
    this.initialTagIds,
    this.initialPlannedDate,
    this.initialParentTaskId,
  });

  @override
  State<TaskAddButton> createState() => _TaskAddButtonState();
}

class _TaskAddButtonState extends State<TaskAddButton> {
  final _translationService = container.resolve<ITranslationService>();
  bool isLoading = false;

  Future<void> _createTask(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => QuickTaskBottomSheet(
        initialTagIds: widget.initialTagIds,
        initialPlannedDate: widget.initialPlannedDate,
        initialParentTaskId: widget.initialParentTaskId,
        onTaskCreated: (taskId, taskData) {
          if (widget.onTaskCreated != null) {
            widget.onTaskCreated!(taskId, taskData);
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
      tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
