import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class HabitGroupInfo {
  final String? name;
  final bool isTranslatable;

  const HabitGroupInfo({this.name, this.isTranslatable = false});
}

class HabitGroupingHelper {
  static String? getGroupName(HabitListItem habit, HabitSortFields? sortField, {DateTime? now}) {
    return getGroupInfo(habit, sortField, now: now)?.name;
  }

  static HabitGroupInfo? getGroupInfo(HabitListItem habit, HabitSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case HabitSortFields.name:
        return HabitGroupInfo(name: GroupingUtils.getTitleGroup(habit.name), isTranslatable: false);
      case HabitSortFields.createdDate:
        return HabitGroupInfo(
            name: GroupingUtils.getBackwardDateGroup(habit.createdDate, now: now), isTranslatable: true);
      case HabitSortFields.modifiedDate:
        return HabitGroupInfo(
            name: GroupingUtils.getBackwardDateGroup(habit.modifiedDate, now: now), isTranslatable: true);
      case HabitSortFields.estimatedTime:
        return HabitGroupInfo(name: GroupingUtils.getDurationGroup(habit.estimatedTime), isTranslatable: true);
      case HabitSortFields.actualTime:
        return HabitGroupInfo(name: GroupingUtils.getDurationGroup(habit.actualTime), isTranslatable: true);
      case HabitSortFields.archivedDate:
        return HabitGroupInfo(
            name: GroupingUtils.getBackwardDateGroup(habit.archivedDate, now: now), isTranslatable: true);
      case HabitSortFields.tag:
        return HabitGroupInfo(name: GroupingUtils.getTagGroup(habit.tags), isTranslatable: false);
    }
  }
}
