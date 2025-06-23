import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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
}
