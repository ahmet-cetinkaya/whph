import 'package:whph/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';

abstract class IHabitRepository extends IRepository<Habit, String> {
  Future<String> getReminderDaysById(String id);
}
