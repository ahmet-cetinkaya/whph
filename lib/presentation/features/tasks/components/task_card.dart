import 'package:flutter/material.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/shared/components/label.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/presentation/shared/extensions/widget_extensions.dart';

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
      plannedDate: DateTimeHelper.toUtcDateTime(date),
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

  Widget _buildMainContent(BuildContext context) {
    // Re-check hasReminder state in case it changed during reordering
    final hasCurrentReminder = _hasReminder;

    return Row(
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
        // Show reminder icon if task has reminders, using the latest state
        if (hasCurrentReminder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(
              Icons.notifications,
              size: AppTheme.iconSizeSmall,
              color: Theme.of(context).colorScheme.primary,
            ).wrapWithTooltip(
              enabled: hasCurrentReminder,
              message: _getReminderTooltip(),
            ),
          ),
        if (onScheduled != null)
          StatefulBuilder(
            builder: (context, setState) => IconButton(
              icon: const Icon(Icons.schedule, color: Colors.grey),
              tooltip: _translationService.translate(TaskTranslationKeys.taskScheduleTooltip),
              onPressed: () {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final tomorrow = today.add(const Duration(days: 1));

                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
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
                );
              },
            ),
          ),
        if (trailingButtons != null)
          ...trailingButtons!.map((widget) {
            if (widget is IconButton) {
              return IconButton(
                icon: widget.icon,
                onPressed: widget.onPressed,
                color: widget.color,
                tooltip: widget.tooltip,
              );
            }
            return widget;
          }),
      ],
    );
  }

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
          Flexible(
            child: Label.multipleColored(
              icon: TagUiConstants.tagIcon,
              color: Colors.grey, // Default color for icon and commas
              values: taskItem.tags.map((tag) => tag.name).toList(),
              colors: taskItem.tags
                  .map((tag) => tag.color != null ? Color(int.parse('FF${tag.color}', radix: 16)) : Colors.grey)
                  .toList(),
              mini: true,
            ),
          ),

        // Add a small spacer between tags and date/time elements
        if (taskItem.tags.isNotEmpty && _hasDateOrTime) const SizedBox(width: 8),

        // Date/time section (now in-line with tags)
        if (_hasDateOrTime)
          Expanded(
            child: Wrap(
              spacing: AppTheme.sizeXSmall,
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
    final elements = <Widget>[];
    void addElement(Widget element) {
      if (elements.isNotEmpty) {
        elements.add(const SizedBox(width: AppTheme.sizeSmall));
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

    if (taskItem.totalElapsedTime > 0) {
      addElement(_buildInfoRow(
        TaskUiConstants.totalElapsedTimeIcon,
        SharedUiConstants.formatMinutes(taskItem.totalElapsedTime ~/ 60),
        TaskUiConstants.totalElapsedTimeColor,
      ));
    }

    // Handle plannedDate with DateTimeHelper directly in presentation layer
    if (taskItem.plannedDate != null) {
      final localFormattedDate = DateTimeHelper.formatDate(taskItem.plannedDate);
      addElement(_buildInfoRow(
        TaskUiConstants.plannedDateIcon,
        localFormattedDate,
        TaskUiConstants.plannedDateColor,
      ));
    }

    // Handle deadlineDate with DateTimeHelper directly in presentation layer
    if (taskItem.deadlineDate != null) {
      final localFormattedDate = DateTimeHelper.formatDate(taskItem.deadlineDate);
      addElement(_buildInfoRow(
        TaskUiConstants.deadlineDateIcon,
        localFormattedDate,
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

  /// Check if the task has any reminders enabled
  bool get _hasReminder =>
      (taskItem.plannedDate != null && taskItem.plannedDateReminderTime != ReminderTime.none) ||
      (taskItem.deadlineDate != null && taskItem.deadlineDateReminderTime != ReminderTime.none);

  /// Get tooltip text for the reminder icon
  String _getReminderTooltip() {
    final List<String> reminderTexts = [];

    if (taskItem.plannedDate != null && taskItem.plannedDateReminderTime != ReminderTime.none) {
      // Use the helper method to get the standardized translation key
      final reminderTypeKey = TaskTranslationKeys.getReminderTypeKey(taskItem.plannedDateReminderTime);
      final reminderType = _translationService.translate(reminderTypeKey);
      final dateText = DateTimeHelper.formatDate(taskItem.plannedDate!);
      reminderTexts
          .add('${_translationService.translate(TaskTranslationKeys.reminderPlannedLabel)}: $dateText ($reminderType)');
    }

    if (taskItem.deadlineDate != null && taskItem.deadlineDateReminderTime != ReminderTime.none) {
      // Use the helper method to get the standardized translation key
      final reminderTypeKey = TaskTranslationKeys.getReminderTypeKey(taskItem.deadlineDateReminderTime);
      final reminderType = _translationService.translate(reminderTypeKey);
      final dateText = DateTimeHelper.formatDate(taskItem.deadlineDate!);
      reminderTexts.add(
          '${_translationService.translate(TaskTranslationKeys.reminderDeadlineLabel)}: $dateText ($reminderType)');
    }

    return reminderTexts.join('\n');
  }

  Color _getPriorityColor(EisenhowerPriority? priority) {
    return TaskUiConstants.getPriorityColor(priority);
  }
}
