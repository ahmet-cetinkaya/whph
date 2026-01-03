import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

class HabitGroupingHelper {
  static String? getGroupName(HabitListItem habit, HabitSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case HabitSortFields.name:
        return _getTitleGroup(habit.name);
      case HabitSortFields.createdDate:
        // Habits usually don't have createdDate in list item but if we add it:
        // return _getDateGroup(habit.createdDate, now: now);
        return null;
      case HabitSortFields.modifiedDate:
        // return _getDateGroup(habit.modifiedDate, now: now);
        return null;
      case HabitSortFields.estimatedTime:
        return _getDurationGroup(habit.estimatedTime);
      case HabitSortFields.actualTime:
        return _getDurationGroup(habit.actualTime); // actualTime is in minutes
      case HabitSortFields.archivedDate:
        return _getDateGroup(habit.archivedDate, now: now);
    }
  }

  static String _getTitleGroup(String? title) {
    if (title == null || title.isEmpty) return "#";
    final firstChar = title[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(firstChar)) {
      return firstChar;
    }
    return "#";
  }

  static String _getDateGroup(DateTime? date, {DateTime? now}) {
    if (date == null) return SharedTranslationKeys.noDate;

    final nowValue = now ?? DateTime.now();
    final today = DateTime(nowValue.year, nowValue.month, nowValue.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    // Normalize input date to start of day
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isAtSameMomentAs(today)) {
      return SharedTranslationKeys.today;
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return SharedTranslationKeys.yesterday;
    } else if (dateToCheck.isAfter(lastWeek)) {
      return SharedTranslationKeys.last7Days;
    } else {
      return SharedTranslationKeys.older;
    }
  }

  static String _getDurationGroup(int? minutes) {
    if (minutes == null || minutes == 0) return SharedTranslationKeys.none;
    if (minutes < 15) return SharedTranslationKeys.durationLessThan15Min;
    if (minutes < 30) return SharedTranslationKeys.duration15To30Min;
    if (minutes < 60) return SharedTranslationKeys.duration30To60Min;
    if (minutes < 120) return SharedTranslationKeys.duration1To2Hours;
    return SharedTranslationKeys.durationMoreThan2Hours;
  }
}
