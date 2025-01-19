import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

enum EisenhowerPriority {
  urgentImportant,
  notUrgentImportant,
  urgentNotImportant,
  notUrgentNotImportant,
}

@jsonSerializable
class Task extends BaseEntity<String> {
  String title;
  String? description;
  EisenhowerPriority? priority;
  DateTime? plannedDate;
  DateTime? deadlineDate;
  int? estimatedTime;
  bool isCompleted = false;

  Task(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.title,
      this.description,
      this.plannedDate,
      this.deadlineDate,
      this.priority,
      this.estimatedTime,
      required this.isCompleted});

  void mapFromInstance(Task instance) {
    title = instance.title;
    description = instance.description;
    priority = instance.priority;
    plannedDate = instance.plannedDate;
    deadlineDate = instance.deadlineDate;
    estimatedTime = instance.estimatedTime;
    isCompleted = instance.isCompleted;
  }
}
