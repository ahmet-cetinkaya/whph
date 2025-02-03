import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

enum EisenhowerPriority {
  notUrgentNotImportant,
  urgentNotImportant,
  notUrgentImportant,
  urgentImportant,
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
  String? parentTaskId;

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
      required this.isCompleted,
      this.parentTaskId});
}
