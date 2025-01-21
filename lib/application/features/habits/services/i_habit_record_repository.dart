import 'package:whph/application/shared/services/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit_record.dart';

abstract class IHabitRecordRepository extends IRepository<HabitRecord, String> {
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize);
}
