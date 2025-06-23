import 'package:whph/src/core/domain/features/habits/habit_tag.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/src/core/application/features/tags/models/tag_time_data.dart';

abstract class IHabitTagsRepository extends app.IRepository<HabitTag, String> {
  Future<bool> anyByHabitIdAndTagId(String habitId, String tagId);

  Future<PaginatedList<HabitTag>> getListByHabitId(String habitId, int pageIndex, int pageSize);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  });
}
