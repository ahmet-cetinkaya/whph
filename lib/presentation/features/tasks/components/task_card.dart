import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';

class TaskCard extends StatelessWidget {
  final TaskListItem task;
  final VoidCallback onOpenDetails;
  final VoidCallback? onCompleted;
  final List<Widget>? trailingButtons;
  final bool transparent;

  const TaskCard({
    super.key,
    required this.task,
    required this.onOpenDetails,
    this.onCompleted,
    this.trailingButtons,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: transparent ? Colors.transparent : null,
      elevation: transparent ? 0 : null,
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _buildMainContent(context),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: TaskCompleteButton(
              taskId: task.id,
              isCompleted: task.isCompleted,
              onToggleCompleted: onCompleted ?? () {},
              color: task.priority != null ? _getPriorityColor(task.priority!) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildTitleAndMetadata(context)),
          if (trailingButtons != null) ...trailingButtons!,
        ],
      );

  Widget _buildTitleAndMetadata(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 2),
          _buildMetadataRow(),
        ],
      );

  Widget _buildMetadataRow() {
    final List<Widget> metadata = [];

    // Add tags if exist
    if (task.tags.isNotEmpty) {
      metadata.addAll([
        const Icon(Icons.label_outline, size: 12, color: Colors.grey),
        const SizedBox(width: 2),
        Text(
          task.tags.map((tag) => tag.name).join(", "),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ]);
    }

    // Add separator if needed
    if (metadata.isNotEmpty && _hasDateOrTime) {
      metadata.add(const SizedBox(width: 8));
      metadata.add(const Text("•", style: TextStyle(color: Colors.grey, fontSize: 10)));
      metadata.add(const SizedBox(width: 8));
    }

    // Add date/time info
    if (_hasDateOrTime) {
      final dateTimeWidgets = _buildDateTimeElements();
      metadata.addAll(dateTimeWidgets);
    }

    return Row(
      children: metadata,
    );
  }

  List<Widget> _buildDateTimeElements() {
    final dateFormat = DateFormat('dd.MM.yy');
    final elements = <Widget>[];
    void addElement(Widget element) {
      if (elements.isNotEmpty) {
        elements.add(const SizedBox(width: 8));
      }
      elements.add(element);
    }

    if (task.estimatedTime != null) {
      addElement(_buildInfoRow(Icons.timer, '${task.estimatedTime}m', Colors.blue));
    }
    if (task.plannedDate != null) {
      addElement(_buildInfoRow(Icons.calendar_today, dateFormat.format(task.plannedDate!), Colors.blue));
    }
    if (task.deadlineDate != null) {
      addElement(_buildInfoRow(Icons.access_time, dateFormat.format(task.deadlineDate!), Colors.red));
    }

    return elements;
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      );

  bool get _hasDateOrTime => task.estimatedTime != null || task.plannedDate != null || task.deadlineDate != null;

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
