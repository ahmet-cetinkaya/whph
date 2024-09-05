import 'package:whph/core/acore/repository/models/base_entity.dart';

class TaskTag extends BaseEntity<int> {
  int taskId;
  int tagId;

  TaskTag(
      {required super.id, required super.createdDate, super.modifiedDate, required this.taskId, required this.tagId});
}
