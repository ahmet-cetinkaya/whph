import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:whph/core/domain/features/habits/habit_time_record.dart';

abstract class IHabitTimeRecordRepository extends app.IRepository<HabitTimeRecord, String> {
  Future<int> getTotalDurationByHabitId(String habitId, {DateTime? startDate, DateTime? endDate});
  Future<List<HabitTimeRecord>> getByHabitId(String habitId);
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end);
}
