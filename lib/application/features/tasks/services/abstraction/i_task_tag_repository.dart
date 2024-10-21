import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

abstract class ITaskTagRepository extends IRepository<TaskTag, String> {
  Future<PaginatedList<TaskTag>> getListByTaskId(String taskId, int pageIndex, int pageSize);

  Future<bool> anyByTaskIdAndTagId(String taskId, String tagId);
}
