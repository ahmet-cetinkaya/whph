import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class TaskTimeRecord extends BaseEntity<String> {
  String taskId;
  int duration;

  TaskTimeRecord({
    required super.id,
    required this.taskId,
    required this.duration,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });

  void mapFromInstance(TaskTimeRecord record) {
    super.id = record.id;
    super.createdDate = record.createdDate;
    super.modifiedDate = record.modifiedDate;
    super.deletedDate = record.deletedDate;
    taskId = record.taskId;
    duration = record.duration;
  }
}
