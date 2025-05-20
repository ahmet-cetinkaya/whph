import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

/// Model class for task data used when creating or updating tasks
class TaskData {
  final String title;
  final EisenhowerPriority? priority;
  final int? estimatedTime;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final List<TaskDataTag> tags;
  final bool isCompleted;
  final String? parentTaskId;
  final double order;
  final DateTime createdDate;

  TaskData(
      {required this.title,
      this.priority,
      this.estimatedTime,
      this.plannedDate,
      this.deadlineDate,
      this.tags = const [],
      this.isCompleted = false,
      this.parentTaskId,
      this.order = 0.0,
      DateTime? createdDate})
      : createdDate = createdDate ?? DateTimeHelper.toUtcDateTime(DateTime.now());

  factory TaskData.fromMap(Map<String, dynamic> map) => TaskData(
        title: map['title'] as String,
        priority: map['priority'] as EisenhowerPriority?,
        estimatedTime: map['estimatedTime'] as int?,
        plannedDate: map['plannedDate'] as DateTime?,
        deadlineDate: map['deadlineDate'] as DateTime?,
        tags:
            (map['tags'] as List<dynamic>?)?.map((tag) => TaskDataTag.fromMap(tag as Map<String, dynamic>)).toList() ??
                [],
        isCompleted: map['isCompleted'] as bool? ?? false,
        parentTaskId: map['parentTaskId'] as String?,
        order: (map['order'] as num?)?.toDouble() ?? 0.0,
        createdDate: map['createdDate'] as DateTime? ?? DateTimeHelper.toUtcDateTime(DateTime.now()),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'priority': priority,
        'estimatedTime': estimatedTime,
        'plannedDate': plannedDate,
        'deadlineDate': deadlineDate,
        'tags': tags.map((tag) => tag.toMap()).toList(),
        'isCompleted': isCompleted,
        'parentTaskId': parentTaskId,
        'order': order,
        'createdDate': createdDate,
      };

  TaskData copyWith(
          {String? title,
          EisenhowerPriority? priority,
          int? estimatedTime,
          DateTime? plannedDate,
          DateTime? deadlineDate,
          List<TaskDataTag>? tags,
          bool? isCompleted,
          String? parentTaskId,
          double? order,
          DateTime? createdDate}) =>
      TaskData(
        title: title ?? this.title,
        priority: priority ?? this.priority,
        estimatedTime: estimatedTime ?? this.estimatedTime,
        plannedDate: plannedDate ?? this.plannedDate,
        deadlineDate: deadlineDate ?? this.deadlineDate,
        tags: tags ?? this.tags,
        isCompleted: isCompleted ?? this.isCompleted,
        parentTaskId: parentTaskId ?? this.parentTaskId,
        order: order ?? this.order,
        createdDate: createdDate ?? this.createdDate,
      );
}

/// Model class for tag data used in TaskData
class TaskDataTag {
  final String id;
  final String name;
  final String? color;

  TaskDataTag({required this.id, required this.name, this.color});
  factory TaskDataTag.fromMap(Map<String, dynamic> map) => TaskDataTag(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as String?,
      );
  factory TaskDataTag.fromTagListItem(TagListItem tag) => TaskDataTag(
        id: tag.id,
        name: tag.name,
        color: tag.color,
      );
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'color': color};
  TaskDataTag copyWith({String? id, String? name, String? color}) => TaskDataTag(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );
}
