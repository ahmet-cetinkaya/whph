import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

abstract class ITaskTagRepository extends IRepository<TaskTag, int> {
  Future<PaginatedList<TaskTag>> getListByTaskId(int taskId, int pageIndex, int pageSize);

  Future<bool> anyByTaskIdAndTagId(int taskId, int tagId);
}
