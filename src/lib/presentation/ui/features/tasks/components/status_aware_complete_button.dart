import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/ui/features/tasks/utils/status_loader_mixin.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_status_display.dart';

/// A wrapper around TaskCompleteButton that automatically uses the status color
/// for the checkbox circle when a task has a custom status.
class StatusAwareCompleteButton extends StatefulWidget {
  final String taskId;
  final bool isCompleted;
  final String? statusId;
  final VoidCallback? onToggleCompleted;
  final double subTasksCompletionPercentage;
  final double size;

  const StatusAwareCompleteButton({
    super.key,
    required this.taskId,
    required this.isCompleted,
    this.statusId,
    this.onToggleCompleted,
    this.subTasksCompletionPercentage = 0.0,
    this.size = 24,
  });

  @override
  State<StatusAwareCompleteButton> createState() => _StatusAwareCompleteButtonState();
}

class _StatusAwareCompleteButtonState extends State<StatusAwareCompleteButton>
    with StatusLoaderMixin<StatusAwareCompleteButton> {
  Color? _resolveStatusColor() {
    final statusId = widget.statusId;

    if (statusId == null || statusId.isEmpty) {
      return null;
    }

    if (statusId == TaskStatusConstants.todoId) {
      return TaskStatusDisplay.parseColor(TaskStatusConstants.todoColor);
    }

    if (statusId == TaskStatusConstants.doneId) {
      return TaskStatusDisplay.parseColor(TaskStatusConstants.doneColor);
    }

    final match = statuses?.where((s) => s.id == statusId).toList();
    if (match != null && match.isNotEmpty) {
      return TaskStatusDisplay.parseColor(match.first.color);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TaskCompleteButton(
      taskId: widget.taskId,
      isCompleted: widget.isCompleted,
      onToggleCompleted: widget.onToggleCompleted,
      color: _resolveStatusColor(),
      subTasksCompletionPercentage: widget.subTasksCompletionPercentage,
      size: widget.size,
    );
  }
}
