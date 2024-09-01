import 'package:whph/core/acore/repository/models/base_entity.dart';

enum EisenhowerPriority { none, urgentImportant, notUrgentImportant, urgentNotImportant, notUrgentNotImportant }

class Task extends BaseEntity<int> {
  String title;
  String? description;
  int? topicId;
  EisenhowerPriority? priority;
  DateTime? plannedDate;
  DateTime? deadlineDate;
  int? estimatedTime;
  int? elapsedTime;
  bool isCompleted = false;

  Task(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      required this.title,
      this.description,
      this.topicId,
      this.plannedDate,
      this.deadlineDate,
      this.priority,
      this.estimatedTime,
      this.elapsedTime,
      required this.isCompleted});
}
