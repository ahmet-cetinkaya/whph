import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/application/features/tags/models/tag_time_data.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';

abstract class IHabitTagsRepository extends app.IRepository<HabitTag, String> {
  Future<bool> anyByHabitIdAndTagId(String habitId, String tagId);

  Future<PaginatedList<HabitTag>> getListByHabitId(String habitId, int pageIndex, int pageSize);

  Future<List<HabitTag>> getByHabitId(String habitId);

  Future<List<HabitTag>> getByTagId(String tagId);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  });

  Future<Map<String, List<TagListItem>>> getTagsForHabitIds(List<String> habitIds);
}
