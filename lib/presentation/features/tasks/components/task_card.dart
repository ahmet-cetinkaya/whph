import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';

class TaskCard extends StatelessWidget {
  final TaskListItem task;
  final VoidCallback onOpenDetails;
  final VoidCallback onCompleted;

  final Mediator mediator = container.resolve<Mediator>();

  TaskCard({super.key, required this.task, required this.onOpenDetails, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: TaskCompleteButton(
            taskId: task.id,
            isCompleted: task.isCompleted,
            onToggleCompleted: onCompleted,
          ),
        ),
        title: Text(task.title),
        subtitle: Row(
          children: [
            if (task.topicName != null) Text(task.topicName!),
            if (task.plannedDate != null) Text(task.plannedDate!.toIso8601String()),
            if (task.deadlineDate != null) Text(task.deadlineDate!.toIso8601String()),
          ],
        ),
        trailing: task.priority != null ? Icon(Icons.priority_high, color: _getPriorityColor(task.priority!)) : null,
        onTap: onOpenDetails,
      ),
    );
  }

  Color _getPriorityColor(EisenhowerPriority priority) {
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return Colors.red;
      case EisenhowerPriority.urgentNotImportant:
        return Colors.orange;
      case EisenhowerPriority.notUrgentImportant:
        return Colors.green;
      case EisenhowerPriority.notUrgentNotImportant:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
