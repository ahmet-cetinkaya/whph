import 'package:whph/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/application/features/tags/models/tag_time_data.dart';

abstract class ITaskTagRepository extends IRepository<TaskTag, String> {
  Future<bool> anyByTaskIdAndTagId(String taskId, String tagId);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  });
}
