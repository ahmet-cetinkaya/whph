import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';

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
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          _buildMetadataRow(),
        ],
      );

  Widget _buildMetadataRow() {
    final List<Widget> metadata = [];

    // Add tags if exist
    if (task.tags.isNotEmpty) {
      metadata.add(Icon(TaskUiConstants.tagsIcon, size: 12, color: TaskUiConstants.tagsColor));
      metadata.add(const SizedBox(width: 2));

      for (var i = 0; i < task.tags.length; i++) {
        if (i > 0) {
          metadata.add(Text(", ", style: AppTheme.bodySmall.copyWith(color: Colors.grey)));
        }

        metadata.add(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            task.tags[i].name,
            style: AppTheme.bodySmall.copyWith(
                color:
                    task.tags[i].color != null ? Color(int.parse('FF${task.tags[i].color}', radix: 16)) : Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ));
      }
    }

    // Add separator if needed
    if (metadata.isNotEmpty && _hasDateOrTime) {
      metadata.add(const SizedBox(width: 8));
    }

    // Add date/time info
    if (_hasDateOrTime) {
      final dateTimeWidgets = _buildDateTimeElements();
      metadata.addAll(dateTimeWidgets);
    }

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadata,
    );
  }

  List<Widget> _buildDateTimeElements() {
    final dateFormat = DateFormat(SharedUiConstants.defaultDateFormat);
    final elements = <Widget>[];
    void addElement(Widget element) {
      if (elements.isNotEmpty) {
        elements.add(const SizedBox(width: 8));
      }
      elements.add(element);
    }

    if (task.estimatedTime != null) {
      addElement(_buildInfoRow(
        TaskUiConstants.estimatedTimeIcon,
        SharedUiConstants.formatMinutes(task.estimatedTime),
        TaskUiConstants.estimatedTimeColor,
      ));
    }
    if (task.plannedDate != null) {
      addElement(_buildInfoRow(
        TaskUiConstants.plannedDateIcon,
        dateFormat.format(task.plannedDate!),
        TaskUiConstants.plannedDateColor,
      ));
    }
    if (task.deadlineDate != null) {
      addElement(_buildInfoRow(
        TaskUiConstants.deadlineDateIcon,
        dateFormat.format(task.deadlineDate!),
        TaskUiConstants.deadlineDateColor,
      ));
    }

    return elements;
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 2),
          Text(text, style: AppTheme.bodySmall.copyWith(color: color)),
        ],
      );

  bool get _hasDateOrTime => task.estimatedTime != null || task.plannedDate != null || task.deadlineDate != null;

  Color _getPriorityColor(EisenhowerPriority? priority) {
    return TaskUiConstants.getPriorityColor(priority);
  }
}
