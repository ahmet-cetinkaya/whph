import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';

class TaskCalendarEventData {
  final String taskId;
  final String title;
  final bool isCompleted;
  final EisenhowerPriority? priority;

  const TaskCalendarEventData({
    required this.taskId,
    required this.title,
    required this.isCompleted,
    this.priority,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCalendarEventData &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId &&
          title == other.title &&
          isCompleted == other.isCompleted &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(taskId, title, isCompleted, priority);
}

class TaskCalendarEvent {
  static CalendarEvent<TaskCalendarEventData> fromTaskListItem(TaskListItem task) {
    if (task.plannedDate == null) {
      throw ArgumentError('Task must have a plannedDate to be displayed on calendar');
    }

    final start = task.plannedDate!;
    final end = task.estimatedTime != null && task.estimatedTime! > 0
        ? start.add(Duration(minutes: task.estimatedTime!))
        : start.add(const Duration(days: 1));

    return CalendarEvent<TaskCalendarEventData>(
      dateTimeRange: DateTimeRange(start: start, end: end),
      data: TaskCalendarEventData(
        taskId: task.id,
        title: task.title,
        isCompleted: task.isCompleted,
        priority: task.priority,
      ),
      interaction: task.isCompleted
          ? EventInteraction(allowStartResize: false, allowEndResize: false, allowRescheduling: false)
          : EventInteraction.allowAll(),
    );
  }

  static Color getEventColor(TaskCalendarEventData data) {
    return TaskUiConstants.getPriorityColor(data.priority);
  }
}
