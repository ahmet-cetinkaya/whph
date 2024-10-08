import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit_record.dart';

abstract class IHabitRecordRepository extends IRepository<HabitRecord, String> {
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      int habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize);
}