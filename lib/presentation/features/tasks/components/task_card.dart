import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskCard extends StatelessWidget {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  final TaskListItem taskItem;

  final List<Widget>? trailingButtons;
  final bool transparent;

  final VoidCallback onOpenDetails;
  final VoidCallback? onCompleted;
  final VoidCallback? onScheduled;

  TaskCard({
    super.key,
    required this.taskItem,
    this.trailingButtons,
    this.transparent = false,
    this.onCompleted,
    required this.onOpenDetails,
    this.onScheduled,
  });

  Future<void> _handleSchedule(DateTime date) async {
    final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: taskItem.id));

    final command = SaveTaskCommand(
      id: task.id,
      title: task.title,
      priority: task.priority,
      plannedDate: date,
      deadlineDate: task.deadlineDate,
      estimatedTime: task.estimatedTime,
      isCompleted: task.isCompleted,
      description: task.description,
    );

    await _mediator.send(command);
    onScheduled?.call();
  }

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
              taskId: taskItem.id,
              isCompleted: taskItem.isCompleted,
              onToggleCompleted: onCompleted ?? () {},
              color: taskItem.priority != null ? _getPriorityColor(taskItem.priority!) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildTitleAndMetadata(context)),
          PopupMenuButton<DateTime>(
            icon: const Icon(Icons.schedule, color: Colors.grey),
            tooltip: _translationService.translate(TaskTranslationKeys.taskScheduleTooltip),
            itemBuilder: (context) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final tomorrow = today.add(const Duration(days: 1));

              return [
                PopupMenuItem(
                  value: today,
                  child: Text(_translationService.translate(TaskTranslationKeys.taskScheduleToday)),
                ),
                PopupMenuItem(
                  value: tomorrow,
                  child: Text(_translationService.translate(TaskTranslationKeys.taskScheduleTomorrow)),
                ),
              ];
            },
            onSelected: _handleSchedule,
          ),
          if (trailingButtons != null) ...trailingButtons!,
        ],
      );

  Widget _buildTitleAndMetadata(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            taskItem.title,
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
    if (taskItem.tags.isNotEmpty) {
      metadata.add(Icon(TaskUiConstants.tagsIcon, size: AppTheme.fontSizeSmall, color: TaskUiConstants.tagsColor));
      metadata.add(const SizedBox(width: 2));

      for (var i = 0; i < taskItem.tags.length; i++) {
        if (i > 0) {
          metadata.add(Text(", ", style: AppTheme.bodySmall.copyWith(color: Colors.grey)));
        }

        metadata.add(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            taskItem.tags[i].name,
            style: AppTheme.bodySmall.copyWith(
                color: taskItem.tags[i].color != null
                    ? Color(int.parse('FF${taskItem.tags[i].color}', radix: 16))
                    : Colors.grey),
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

    if (taskItem.estimatedTime != null) {
      addElement(_buildInfoRow(
        TaskUiConstants.estimatedTimeIcon,
        SharedUiConstants.formatMinutes(taskItem.estimatedTime),
        TaskUiConstants.estimatedTimeColor,
      ));
    }
    if (taskItem.plannedDate != null) {
      addElement(_buildInfoRow(
        TaskUiConstants.plannedDateIcon,
        dateFormat.format(taskItem.plannedDate!),
        TaskUiConstants.plannedDateColor,
      ));
    }
    if (taskItem.deadlineDate != null) {
      addElement(_buildInfoRow(
        TaskUiConstants.deadlineDateIcon,
        dateFormat.format(taskItem.deadlineDate!),
        TaskUiConstants.deadlineDateColor,
      ));
    }

    return elements;
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppTheme.fontSizeMedium),
          const SizedBox(width: 2),
          Text(text, style: AppTheme.bodySmall.copyWith(color: color)),
        ],
      );

  bool get _hasDateOrTime =>
      taskItem.estimatedTime != null || taskItem.plannedDate != null || taskItem.deadlineDate != null;

  Color _getPriorityColor(EisenhowerPriority? priority) {
    return TaskUiConstants.getPriorityColor(priority);
  }
}
