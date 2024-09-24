import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';

abstract class IHabitRepository extends IRepository<Habit, int> {}
