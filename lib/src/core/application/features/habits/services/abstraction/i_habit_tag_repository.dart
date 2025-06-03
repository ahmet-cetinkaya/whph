import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/habits/habit_tag.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_data.dart';

abstract class IHabitTagRepository extends IRepository<HabitTag, String> {
  Future<PaginatedList<HabitTag>> getListByHabitId(String habitId, int pageIndex, int pageSize);

  Future<bool> anyByHabitIdAndTagId(String habitId, String tagId);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  });
}
