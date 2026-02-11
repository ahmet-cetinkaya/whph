import 'package:domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';

class TaskListItem {
  String id;
  String title;
  EisenhowerPriority? priority;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final DateTime? modifiedDate;
  final DateTime? createdDate;
  final bool isCompleted;
  final List<TagListItem> tags;
  final int? estimatedTime;
  final int totalElapsedTime;
  final String? parentTaskId;
  final double subTasksCompletionPercentage;
  final double order;
  final List<TaskListItem> subTasks;
  final ReminderTime plannedDateReminderTime;
  final ReminderTime deadlineDateReminderTime;
  final String? groupName;

  TaskListItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.isCompleted,
    this.plannedDate,
    this.deadlineDate,
    this.modifiedDate,
    this.createdDate,
    this.tags = const [],
    this.estimatedTime,
    this.parentTaskId,
    this.subTasksCompletionPercentage = 0,
    this.order = 0.0,
    this.subTasks = const [],
    this.totalElapsedTime = 0,
    this.plannedDateReminderTime = ReminderTime.none,
    this.deadlineDateReminderTime = ReminderTime.none,
    this.groupName,
  });

  TaskListItem copyWith({
    String? id,
    String? title,
    EisenhowerPriority? priority,
    DateTime? plannedDate,
    DateTime? deadlineDate,
    DateTime? modifiedDate,
    DateTime? createdDate,
    bool? isCompleted,
    List<TagListItem>? tags,
    int? estimatedTime,
    int? totalElapsedTime,
    String? parentTaskId,
    double? subTasksCompletionPercentage,
    double? order,
    List<TaskListItem>? subTasks,
    ReminderTime? plannedDateReminderTime,
    ReminderTime? deadlineDateReminderTime,
    String? groupName,
  }) {
    return TaskListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      plannedDate: plannedDate ?? this.plannedDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      createdDate: createdDate ?? this.createdDate,
      isCompleted: isCompleted ?? this.isCompleted,
      tags: tags ?? this.tags,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      totalElapsedTime: totalElapsedTime ?? this.totalElapsedTime,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      subTasksCompletionPercentage: subTasksCompletionPercentage ?? this.subTasksCompletionPercentage,
      order: order ?? this.order,
      subTasks: subTasks ?? this.subTasks,
      plannedDateReminderTime: plannedDateReminderTime ?? this.plannedDateReminderTime,
      deadlineDateReminderTime: deadlineDateReminderTime ?? this.deadlineDateReminderTime,
      groupName: groupName ?? this.groupName,
    );
  }
}
