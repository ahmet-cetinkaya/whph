import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:whph/src/core/domain/features/habits/habit.dart';

abstract class IHabitRepository extends app.IRepository<Habit, String> {
  Future<String> getReminderDaysById(String id);
}
