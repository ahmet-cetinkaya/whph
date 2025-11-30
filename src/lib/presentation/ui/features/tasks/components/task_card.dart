import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/tag_list_widget.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/extensions/widget_extensions.dart';
import 'package:whph/presentation/ui/features/tasks/components/schedule_button.dart';

class TaskCard extends StatelessWidget {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  final TaskListItem taskItem;

  final List<Widget>? trailingButtons;
  final bool transparent;
  final bool showSubTasks;
  final bool showScheduleButton;
  final bool isDense;

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
    this.showScheduleButton = true,
    this.isDense = false,
  });

  Future<void> _handleSchedule(DateTime date) async {
    final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: taskItem.id));
    final taskService = container.resolve<TasksService>();

    // The date parameter comes from ScheduleButton in local time
    // toUtcDateTime will properly convert it to UTC for storage
    final command = SaveTaskCommand(
      id: task.id,
      title: task.title,
      priority: task.priority,
      plannedDate: DateTimeHelper.toUtcDateTime(date),
      deadlineDate: task.deadlineDate,
      estimatedTime: task.estimatedTime,
      completedAt: task.completedAt,
      description: task.description,
    );

    await _mediator.send(command);

    taskService.notifyTaskUpdated(task.id);
    onScheduled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentReminder = _hasReminder;

    return ListTile(
      tileColor: transparent ? Colors.transparent : AppTheme.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      visualDensity: isDense ? VisualDensity.compact : VisualDensity.standard,
      dense: isDense,
      onTap: onOpenDetails,
      leading: TaskCompleteButton(
        taskId: taskItem.id,
        isCompleted: taskItem.isCompleted,
        onToggleCompleted: onCompleted,
        color: taskItem.priority != null ? _getPriorityColor(taskItem.priority!) : null,
        subTasksCompletionPercentage: taskItem.subTasksCompletionPercentage,
        size: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
      ),
      title: _buildTitleAndMetadata(context),
      subtitle: showSubTasks && taskItem.subTasks.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSubTasks(context),
            )
          : null,
      contentPadding: EdgeInsets.only(left: AppTheme.sizeMedium, right: 0),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reminder icon
          if (hasCurrentReminder)
            Icon(
              Icons.notifications,
              size: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
              color: Theme.of(context).colorScheme.primary,
            ).wrapWithTooltip(
              enabled: hasCurrentReminder,
              message: _getReminderTooltip(),
            ),
          // Schedule button
          if (showScheduleButton)
            ScheduleButton(
              translationService: _translationService,
              onScheduleSelected: _handleSchedule,
              isDense: isDense,
              currentPlannedDate: taskItem.plannedDate,
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
      ),
    );
  }

  Widget _buildTitleAndMetadata(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            taskItem.title.isEmpty ? _translationService.translate(SharedTranslationKeys.untitled) : taskItem.title,
            style: (isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isDense ? 1 : 2),
          _buildMetadataRow(context),
        ],
      );

  Widget _buildMetadataRow(BuildContext context) {
    final spacing = isDense ? 4.0 : 8.0;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tags section
        if (taskItem.tags.isNotEmpty) _buildTaskTagsWidget(),

        // Date/Time elements
        if (_hasDateTimeOrMetadata) ..._buildDateTimeElements(context),

        // Completion percentage for subtasks
        if (taskItem.subTasks.isNotEmpty && taskItem.subTasksCompletionPercentage > 0)
          _buildInfoRow(
            Icons.check_circle_outline,
            '${taskItem.subTasksCompletionPercentage.toStringAsFixed(0)}%',
            Colors.green,
          ),

        // Estimated time if available
        if (taskItem.estimatedTime != null && taskItem.estimatedTime! > 0)
          _buildInfoRow(
            Icons.timer_outlined,
            '${taskItem.estimatedTime}m',
            TaskUiConstants.estimatedTimeColor,
          ),
      ],
    );
  }

  String _formatDate(DateTime date, BuildContext context) {
    return DateFormatService.formatForDisplay(date, context, type: DateFormatType.dateTime);
  }

  Color _getDateColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isBefore(today)) {
      return Colors.red;
    } else if (dateOnly == today) {
      return Colors.orange;
    } else if (dateOnly == tomorrow) {
      return Colors.green;
    }
    return Colors.grey;
  }

  List<Widget> _buildDateTimeElements(BuildContext context) {
    final List<Widget> elements = [];

    // Planned date
    if (taskItem.plannedDate != null) {
      elements.add(Label.single(
        icon: Icons.event,
        text: _formatDate(taskItem.plannedDate!, context),
        color: _getDateColor(taskItem.plannedDate!),
        mini: isDense,
      ));
    }

    // Deadline date
    if (taskItem.deadlineDate != null) {
      elements.add(Label.single(
        icon: Icons.event_available,
        text: _formatDate(taskItem.deadlineDate!, context),
        color: _getDateColor(taskItem.deadlineDate!),
        mini: isDense,
      ));
    }

    return elements;
  }

  List<Widget> _buildSubTasks(BuildContext context) {
    return taskItem.subTasks.map((subTask) {
      return Padding(
        padding: EdgeInsets.only(left: isDense ? 12.0 : 16.0, top: isDense ? 4.0 : 8.0),
        child: TaskCard(
          taskItem: subTask,
          onOpenDetails: () => onOpenDetails(),
          onCompleted: onCompleted,
          trailingButtons: trailingButtons,
          transparent: true,
          showSubTasks: showSubTasks,
          isDense: isDense, // Pass isDense to subtasks
        ),
      );
    }).toList();
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppTheme.fontSizeMedium),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  bool get _hasDateTimeOrMetadata =>
      taskItem.plannedDate != null ||
      taskItem.deadlineDate != null ||
      (taskItem.estimatedTime != null && taskItem.estimatedTime! > 0) ||
      (taskItem.subTasks.isNotEmpty && taskItem.subTasksCompletionPercentage > 0);

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
      reminderTexts.add(reminderType);
    }

    if (taskItem.deadlineDate != null && taskItem.deadlineDateReminderTime != ReminderTime.none) {
      // Use the helper method to get the standardized translation key
      final reminderTypeKey = TaskTranslationKeys.getReminderTypeKey(taskItem.deadlineDateReminderTime);
      final reminderType = _translationService.translate(reminderTypeKey);
      reminderTexts.add(reminderType);
    }

    return reminderTexts.join('\n');
  }

  Widget _buildTaskTagsWidget() {
    final items = TagDisplayUtils.objectsToDisplayItems(taskItem.tags, _translationService);
    return TagListWidget(items: items, mini: isDense);
  }

  Color _getPriorityColor(EisenhowerPriority? priority) {
    return TaskUiConstants.getPriorityColor(priority);
  }
}
