import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';

class TaskCard extends StatelessWidget {
  final TaskListItem task;
  final VoidCallback onOpenDetails;
  final VoidCallback onCompleted;

  const TaskCard({
    super.key,
    required this.task,
    required this.onOpenDetails,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(4.0),
        leading: _buildCompleteButton(),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: _buildSubtitle(context),
        onTap: onOpenDetails,
      ),
    );
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: TaskCompleteButton(
        taskId: task.id,
        isCompleted: task.isCompleted,
        onToggleCompleted: onCompleted,
        color: task.priority != null ? _getPriorityColor(task.priority!) : null,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final DateFormat dateFormat = DateFormat('dd.MM.yy');
    List<Widget> subtitleWidgets = [];

    // Add estimated time if exists
    if (task.estimatedTime != null) {
      subtitleWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer, color: Colors.blue, size: 16),
            const SizedBox(width: 4),
            Text(
              '${task.estimatedTime}m',
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Add planned date if exists
    if (task.plannedDate != null) {
      if (subtitleWidgets.isNotEmpty) {
        subtitleWidgets.add(const SizedBox(width: 8));
      }
      subtitleWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.blue, size: 16),
            const SizedBox(width: 4),
            Text(
              dateFormat.format(task.plannedDate!),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Add deadline date if exists
    if (task.deadlineDate != null) {
      if (subtitleWidgets.isNotEmpty) {
        subtitleWidgets.add(const SizedBox(width: 8));
      }
      subtitleWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Text(
              dateFormat.format(task.deadlineDate!),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    var topRow = Row(
      children: subtitleWidgets,
    );

    // Add tags in a separate row if they exist
    if (task.tags.isEmpty) {
      return topRow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topRow,
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.label,
              color: Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                task.tags.map((tag) => tag.name).join(", "),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getPriorityColor(EisenhowerPriority priority) {
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return Colors.red;
      case EisenhowerPriority.notUrgentImportant:
        return Colors.green;
      case EisenhowerPriority.urgentNotImportant:
        return Colors.blue;
      case EisenhowerPriority.notUrgentNotImportant:
        return Colors.grey;
      default:
        return Colors.white;
    }
  }
}
