import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';

abstract class IHabitRecordRepository extends app.IRepository<HabitRecord, String> {
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize);

  Future<List<HabitRecord>> getByHabitId(String habitId);

  /// Count occurrences for a habit on a specific date
  Future<int> countByHabitIdAndDate(String habitId, DateTime date);

  Future<List<HabitRecord>> getByHabitIdAndStatus(String habitId, HabitRecordStatus status);
}
