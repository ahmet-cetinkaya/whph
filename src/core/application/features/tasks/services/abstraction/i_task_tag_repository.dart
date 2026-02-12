import 'package:application/shared/services/abstraction/i_repository.dart' as app;
import 'package:domain/features/tasks/task_tag.dart';
import 'package:application/features/tags/models/tag_time_data.dart';

abstract class ITaskTagRepository extends app.IRepository<TaskTag, String> {
  Future<bool> anyByTaskIdAndTagId(String taskId, String tagId);

  Future<List<TaskTag>> getByTaskId(String taskId);

  Future<List<TaskTag>> getByTagId(String tagId);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  });

  Future<void> updateTagOrders(String taskId, Map<String, int> tagOrders);
}
