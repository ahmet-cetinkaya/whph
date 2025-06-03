import 'package:flutter/material.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/quick_add_task_dialog.dart';
import 'package:whph/src/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class TaskAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String taskId, TaskData taskData)? onTaskCreated;
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final DateTime? initialDeadlineDate;
  final EisenhowerPriority? initialPriority;
  final int? initialEstimatedTime;
  final String? initialParentTaskId;
  final String? initialTitle;
  final bool? initialCompleted;

  const TaskAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTaskCreated,
    this.initialTagIds,
    this.initialPlannedDate,
    this.initialDeadlineDate,
    this.initialPriority,
    this.initialEstimatedTime,
    this.initialParentTaskId,
    this.initialTitle,
    this.initialCompleted,
  });

  @override
  State<TaskAddButton> createState() => _TaskAddButtonState();
}

class _TaskAddButtonState extends State<TaskAddButton> {
  final _translationService = container.resolve<ITranslationService>();
  bool isLoading = false;

  Future<void> _createTask(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: QuickAddTaskDialog(
        initialTagIds: widget.initialTagIds,
        initialPlannedDate: widget.initialPlannedDate,
        initialDeadlineDate: widget.initialDeadlineDate,
        initialPriority: widget.initialPriority,
        initialEstimatedTime: widget.initialEstimatedTime,
        initialParentTaskId: widget.initialParentTaskId,
        initialTitle: widget.initialTitle,
        initialCompleted: widget.initialCompleted,
        onTaskCreated: (taskId, taskData) {
          if (widget.onTaskCreated != null) {
            widget.onTaskCreated!(taskId, taskData);
          }
        },
      ),
      size: DialogSize.small,
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
