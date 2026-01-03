import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class HabitGroupingHelper {
  static String? getGroupName(HabitListItem habit, HabitSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case HabitSortFields.name:
        return GroupingUtils.getTitleGroup(habit.name);
      case HabitSortFields.createdDate:
        // Habits usually don't have createdDate in list item but if we add it:
        // return GroupingUtils.getBackwardDateGroup(habit.createdDate, now: now);
        return null;
      case HabitSortFields.modifiedDate:
        // return GroupingUtils.getBackwardDateGroup(habit.modifiedDate, now: now);
        return null;
      case HabitSortFields.estimatedTime:
        return GroupingUtils.getDurationGroup(habit.estimatedTime);
      case HabitSortFields.actualTime:
        return GroupingUtils.getDurationGroup(habit.actualTime); // actualTime is in minutes
      case HabitSortFields.archivedDate:
        return GroupingUtils.getBackwardDateGroup(habit.archivedDate, now: now);
    }
  }
}
