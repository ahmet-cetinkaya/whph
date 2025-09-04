import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:whph/core/domain/features/habits/habit.dart';

abstract class IHabitRepository extends app.IRepository<Habit, String> {
  Future<String> getReminderDaysById(String id);
  Future<void> updateAll(List<Habit> habits);
}
