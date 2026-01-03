import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

class TaskGroupingHelper {
  static String? getGroupName(TaskListItem task, TaskSortFields? sortField) {
    if (sortField == null) return null;

    switch (sortField) {
      case TaskSortFields.createdDate:
        return _getDateGroup(task.createdDate);
      case TaskSortFields.deadlineDate:
        return _getDateGroup(task.deadlineDate);
      case TaskSortFields.modifiedDate:
        return _getDateGroup(task.modifiedDate);
      case TaskSortFields.plannedDate:
        return _getDateGroup(task.plannedDate);
      case TaskSortFields.priority:
        return _getPriorityGroup(task.priority);
      case TaskSortFields.title:
        return _getTitleGroup(task.title);
      case TaskSortFields.estimatedTime:
        return _getDurationGroup(task.estimatedTime);
      case TaskSortFields.totalDuration:
        return _getDurationGroup(task.totalElapsedTime); // Assuming totalDuration maps to totalElapsedTime
    }
  }

  static String _getDateGroup(DateTime? date) {
    if (date == null) return SharedTranslationKeys.noDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    // Normalize input date to start of day for accurate comparison
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isBefore(today)) {
      return SharedTranslationKeys.overdue;
    } else if (dateToCheck.isAtSameMomentAs(today)) {
      return SharedTranslationKeys.today;
    } else if (dateToCheck.isAtSameMomentAs(tomorrow)) {
      return SharedTranslationKeys.tomorrow;
    } else if (dateToCheck.isBefore(nextWeek)) {
      return SharedTranslationKeys.next7Days;
    } else {
      return SharedTranslationKeys.future;
    }
  }

  static String _getPriorityGroup(EisenhowerPriority? priority) {
    if (priority == null) return SharedTranslationKeys.none;

    // Assuming EisenhowerPriority enum has values. Mapping explicitly.
    // Adjust based on actual enum values if needed.
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return TaskTranslationKeys.priorityUrgentImportant;
      case EisenhowerPriority.urgentNotImportant:
        return TaskTranslationKeys.priorityUrgentNotImportant;
      case EisenhowerPriority.notUrgentImportant:
        return TaskTranslationKeys.priorityNotUrgentImportant;
      case EisenhowerPriority.notUrgentNotImportant:
        return TaskTranslationKeys.priorityNotUrgentNotImportant;
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

  static String _getDurationGroup(int? minutes) {
    if (minutes == null || minutes == 0) return SharedTranslationKeys.none;
    if (minutes < 15) return SharedTranslationKeys.durationLessThan15Min;
    if (minutes < 30) return SharedTranslationKeys.duration15To30Min;
    if (minutes < 60) return SharedTranslationKeys.duration30To60Min;
    if (minutes < 120) return SharedTranslationKeys.duration1To2Hours;
    return SharedTranslationKeys.durationMoreThan2Hours;
  }
}
