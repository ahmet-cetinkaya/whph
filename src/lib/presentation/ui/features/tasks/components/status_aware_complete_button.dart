import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_complete_button.dart';

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

class _StatusAwareCompleteButtonState extends State<StatusAwareCompleteButton> {
  List<TaskStatusListItem>? _statuses;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final mediator = container.resolve<Mediator>();
    final response = await mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
      const GetListTaskStatusesQuery(),
    );
    if (mounted) {
      setState(() => _statuses = response.items);
    }
  }

  Color? _resolveStatusColor() {
    final statusId = widget.statusId;

    if (statusId == null || statusId.isEmpty) {
      return null;
    }

    try {
      if (statusId == TaskStatusConstants.todoId) {
        return Color(int.parse('FF${TaskStatusConstants.todoColor}', radix: 16));
      }

      if (statusId == TaskStatusConstants.doneId) {
        return Color(int.parse('FF${TaskStatusConstants.doneColor}', radix: 16));
      }

      final match = _statuses?.where((s) => s.id == statusId).toList();
      if (match != null && match.isNotEmpty) {
        final resolved = match.first;
        final colorHex = resolved.color;
        if (colorHex != null && colorHex.isNotEmpty) {
          String cleanHex = colorHex.replaceAll('#', '').replaceFirst('0x', '');
          if (cleanHex.length == 6) {
            cleanHex = 'FF$cleanHex';
          }
          return Color(int.parse(cleanHex, radix: 16));
        }
      }
    } catch (_) {}

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
