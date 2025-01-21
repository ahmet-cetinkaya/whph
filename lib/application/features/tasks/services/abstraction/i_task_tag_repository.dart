import 'package:whph/application/shared/services/i_repository.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

abstract class ITaskTagRepository extends IRepository<TaskTag, String> {
  Future<bool> anyByTaskIdAndTagId(String taskId, String tagId);
}
