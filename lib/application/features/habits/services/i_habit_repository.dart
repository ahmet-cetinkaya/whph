import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';

abstract class IHabitRepository extends IRepository<Habit, String> {}
