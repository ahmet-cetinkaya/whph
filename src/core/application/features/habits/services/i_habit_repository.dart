import 'package:application/shared/services/abstraction/i_repository.dart' as app;
import 'package:domain/features/habits/habit.dart';
import 'package:application/features/habits/models/habit_list_item.dart';
import 'package:acore/acore.dart' as acore;

abstract class IHabitRepository extends app.IRepository<Habit, String> {
  Future<String> getReminderDaysById(String id);
  Future<void> updateAll(List<Habit> habits);
  Future<acore.PaginatedList<HabitListItem>> getHabitListItems(
    int pageIndex,
    int pageSize, {
    bool includeDeleted = false,
    acore.CustomWhereFilter? customWhereFilter,
    List<acore.CustomOrder>? customOrder,
  });
}
