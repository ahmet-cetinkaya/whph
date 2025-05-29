import 'package:flutter/material.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/quick_task_bottom_sheet.dart';
import 'package:whph/presentation/features/tasks/models/task_data.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

/// A floating action button specifically designed for adding tasks.
/// This component provides a consistent way to add tasks across different pages.
class TaskAddFloatingButton extends StatelessWidget {
  /// Callback function called when a task is successfully created
  final Function(String taskId, TaskData taskData)? onTaskCreated;

  /// Initial tag IDs to pre-populate in the task creation form
  final List<String>? initialTagIds;

  /// Initial planned date for the task
  final DateTime? initialPlannedDate;

  /// Initial deadline date for the task
  final DateTime? initialDeadlineDate;

  /// Initial priority for the task
  final EisenhowerPriority? initialPriority;

  /// Initial estimated time for the task (in minutes)
  final int? initialEstimatedTime;

  /// Initial parent task ID for creating subtasks
  final String? initialParentTaskId;

  /// Initial title text for the task
  final String? initialTitle;

  /// Initial completed status for the task
  final bool? initialCompleted;

  /// Custom background color for the floating action button
  final Color? backgroundColor;

  /// Custom foreground color for the floating action button
  final Color? foregroundColor;

  /// Custom tooltip text for the floating action button
  final String? tooltip;

  /// Custom icon for the floating action button
  final IconData? icon;

  const TaskAddFloatingButton({
    super.key,
    this.onTaskCreated,
    this.initialTagIds,
    this.initialPlannedDate,
    this.initialDeadlineDate,
    this.initialPriority,
    this.initialEstimatedTime,
    this.initialParentTaskId,
    this.initialTitle,
    this.initialCompleted,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return FloatingActionButton(
      onPressed: () => _showTaskCreationDialog(context),
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      foregroundColor: foregroundColor ?? AppTheme.darkTextColor,
      tooltip: tooltip ?? translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
      child: Icon(icon ?? Icons.add),
    );
  }

  /// Shows the task creation dialog using ResponsiveDialogHelper
  Future<void> _showTaskCreationDialog(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.small,
      child: QuickTaskBottomSheet(
        initialTagIds: initialTagIds,
        initialPlannedDate: initialPlannedDate,
        initialDeadlineDate: initialDeadlineDate,
        initialPriority: initialPriority,
        initialEstimatedTime: initialEstimatedTime,
        initialParentTaskId: initialParentTaskId,
        initialTitle: initialTitle,
        initialCompleted: initialCompleted,
        onTaskCreated: onTaskCreated,
      ),
    );
  }
}
