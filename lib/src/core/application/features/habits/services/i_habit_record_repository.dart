import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/src/core/domain/features/habits/habit_record.dart';

abstract class IHabitRecordRepository extends app.IRepository<HabitRecord, String> {
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize);
}
