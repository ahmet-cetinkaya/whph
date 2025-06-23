import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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
}
