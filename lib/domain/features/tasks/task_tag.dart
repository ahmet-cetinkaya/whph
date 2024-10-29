import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class TaskTag extends BaseEntity<String> {
  String taskId;
  String tagId;

  TaskTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.taskId,
      required this.tagId});

  void mapFromInstance(TaskTag instance) {
    taskId = instance.taskId;
    tagId = instance.tagId;
  }
}
