import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';
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
        trailing: _buildPriorityWidget(),
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
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final DateFormat dateFormat = DateFormat('EEEE, d MMMM y');
    List<Widget> subtitleWidgets = [];

    if (task.plannedDate != null) {
      subtitleWidgets.add(
        Row(
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
    if (task.deadlineDate != null) {
      if (subtitleWidgets.isNotEmpty) {
        subtitleWidgets.add(const SizedBox(width: 8));
      }

      subtitleWidgets.add(
        Row(
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

    if (subtitleWidgets.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenLarge)
        ? Row(
            children: subtitleWidgets,
          )
        : Column(
            children: subtitleWidgets,
          );
  }

  Widget _buildPriorityWidget() {
    if (task.priority == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag,
            color: _getPriorityColor(task.priority!),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            _getPriorityText(task.priority!),
            style: TextStyle(
              color: _getPriorityColor(task.priority!),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  String _getPriorityText(EisenhowerPriority priority) {
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return 'Urgent & Important';
      case EisenhowerPriority.urgentNotImportant:
        return 'Urgent & Not Important';
      case EisenhowerPriority.notUrgentImportant:
        return 'Important & Not Urgent';
      case EisenhowerPriority.notUrgentNotImportant:
        return 'Not Urgent & Not Important';
      default:
        return 'Unknown';
    }
  }
}
