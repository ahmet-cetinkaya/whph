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
import 'package:whph/presentation/features/tags/components/tag_label.dart';

class TaskCard extends StatelessWidget {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  final TaskListItem taskItem;

  final List<Widget>? trailingButtons;
  final bool transparent;
  final bool showSubTasks;

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
    this.showSubTasks = false,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainContent(context),
              if (showSubTasks && taskItem.subTasks.isNotEmpty) ..._buildSubTasks(context),
            ],
          ),
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
          if (onScheduled != null)
            StatefulBuilder(
              builder: (context, setState) => IconButton(
                icon: const Icon(Icons.schedule, color: Colors.grey),
                onPressed: () {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final tomorrow = today.add(const Duration(days: 1));

                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text(_translationService.translate(TaskTranslationKeys.taskScheduleToday)),
                            onTap: () {
                              _handleSchedule(today);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: Text(_translationService.translate(TaskTranslationKeys.taskScheduleTomorrow)),
                            onTap: () {
                              _handleSchedule(tomorrow);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
    return Row(
      children: [
        // Tags section
        if (taskItem.tags.isNotEmpty)
          TagLabel(
            tagColor: taskItem.tags.firstOrNull?.color,
            tagName: taskItem.tags.map((tag) => tag.name).join(', '),
            mini: true,
          ),

        // Add a small spacer between tags and date/time elements
        if (taskItem.tags.isNotEmpty && _hasDateOrTime) const SizedBox(width: 8),

        // Date/time section (now in-line with tags)
        if (_hasDateOrTime)
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _buildDateTimeElements(),
            ),
          ),

        // Completion percentage for subtasks
        if (taskItem.subTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildInfoRow(
              Icons.check_circle_outline,
              '${taskItem.subTasksCompletionPercentage.toStringAsFixed(0)}%',
              Colors.green,
            ),
          ),
      ],
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

  List<Widget> _buildSubTasks(BuildContext context) {
    return taskItem.subTasks.map((subTask) {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0),
        child: TaskCard(
          taskItem: subTask,
          onOpenDetails: () => onOpenDetails(),
          onCompleted: onCompleted,
          trailingButtons: trailingButtons,
          transparent: true,
          showSubTasks: showSubTasks,
        ),
      );
    }).toList();
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
