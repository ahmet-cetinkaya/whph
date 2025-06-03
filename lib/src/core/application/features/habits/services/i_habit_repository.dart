import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';

abstract class IHabitRepository extends IRepository<Habit, String> {
  Future<String> getReminderDaysById(String id);
}
