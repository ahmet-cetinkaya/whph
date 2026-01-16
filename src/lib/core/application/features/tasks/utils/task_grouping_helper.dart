import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class TaskGroupingHelper {
  static String? getGroupName(TaskListItem task, TaskSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case TaskSortFields.createdDate:
        return GroupingUtils.getForwardDateGroup(task.createdDate, now: now);
      case TaskSortFields.deadlineDate:
        return GroupingUtils.getForwardDateGroup(task.deadlineDate, now: now);
      case TaskSortFields.modifiedDate:
        return GroupingUtils.getForwardDateGroup(task.modifiedDate, now: now);
      case TaskSortFields.plannedDate:
        return GroupingUtils.getForwardDateGroup(task.plannedDate, now: now);
      case TaskSortFields.priority:
        return _getPriorityGroup(task.priority);
      case TaskSortFields.title:
        return GroupingUtils.getTitleGroup(task.title);
      case TaskSortFields.estimatedTime:
        return GroupingUtils.getDurationGroup(task.estimatedTime);
      case TaskSortFields.totalDuration:
        return GroupingUtils.getDurationGroup(task.totalElapsedTime);
      case TaskSortFields.tag:
        return task.tags.isNotEmpty ? task.tags.first.name : SharedTranslationKeys.none;
    }
  }

  static String _getPriorityGroup(EisenhowerPriority? priority) {
    if (priority == null) return SharedTranslationKeys.none;

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
}
