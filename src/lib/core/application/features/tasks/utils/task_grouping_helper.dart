import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';
import 'package:whph/core/application/shared/utils/group_key_result.dart';

class TaskGroupingHelper {
  static String? getGroupName(TaskListItem task, TaskSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case TaskSortFields.createdDate:
        return GroupingUtils.getForwardDateGroup(task.createdDate, now: now);
      case TaskSortFields.completedDate:
        return GroupingUtils.getForwardDateGroup(task.completedAt, now: now);
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

  /// Returns true if the group name should be translated based on the sort field
  static bool isGroupTranslatable(TaskSortFields? sortField) {
    if (sortField == null) return false;

    switch (sortField) {
      case TaskSortFields.priority:
      case TaskSortFields.createdDate:
      case TaskSortFields.completedDate:
      case TaskSortFields.deadlineDate:
      case TaskSortFields.modifiedDate:
      case TaskSortFields.plannedDate:
      case TaskSortFields.estimatedTime:
      case TaskSortFields.totalDuration:
        return true;
      case TaskSortFields.title:
      case TaskSortFields.tag:
        return false;
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

  /// Reverse-maps a priority group key back to [EisenhowerPriority].
  /// Returns null for the "none" group and for unrecognized keys.
  static EisenhowerPriority? priorityFromGroupKey(String groupKey) {
    switch (groupKey) {
      case TaskTranslationKeys.priorityUrgentImportant:
        return EisenhowerPriority.urgentImportant;
      case TaskTranslationKeys.priorityUrgentNotImportant:
        return EisenhowerPriority.urgentNotImportant;
      case TaskTranslationKeys.priorityNotUrgentImportant:
        return EisenhowerPriority.notUrgentImportant;
      case TaskTranslationKeys.priorityNotUrgentNotImportant:
        return EisenhowerPriority.notUrgentNotImportant;
      default:
        return null;
    }
  }

  /// Reverse-maps a completed-date group key to completion state.
  ///
  /// The "no date" group means the task is not completed; any date group means
  /// it is. An unrecognized key yields null.
  static bool? isCompletedFromGroupKey(String groupKey) {
    switch (groupKey) {
      case SharedTranslationKeys.noDate:
        return false;
      default:
        return true;
    }
  }

  /// Reverse-maps a tag group key back to the tag name.
  /// For the "none" group, returns null.
  static String? tagNameFromGroupKey(String groupKey) {
    if (groupKey == SharedTranslationKeys.none) {
      return null;
    }
    return groupKey;
  }

  /// Returns true when a cross-column drop can be persisted by mutating the
  /// task field that defines the grouping. Only single-field, reversible
  /// groupings qualify.
  static bool isCrossColumnMovePersistable(TaskSortFields? sortField) {
    switch (sortField) {
      case TaskSortFields.priority:
      case TaskSortFields.plannedDate:
      case TaskSortFields.deadlineDate:
      case TaskSortFields.completedDate:
      case TaskSortFields.estimatedTime:
      case TaskSortFields.tag:
        return true;
      default:
        return false;
    }
  }

  /// Returns the group key of the "empty value" column for an optional-property
  /// grouping (e.g. no priority, no date, no tag), or null when the field is
  /// not optional / has no empty column. Used to guarantee that column always
  /// exists on the board so a task can be dropped to clear the property.
  static String? emptyGroupKeyFor(TaskSortFields? sortField) {
    switch (sortField) {
      case TaskSortFields.priority:
      case TaskSortFields.estimatedTime:
      case TaskSortFields.totalDuration:
      case TaskSortFields.tag:
        return SharedTranslationKeys.none;
      case TaskSortFields.plannedDate:
      case TaskSortFields.deadlineDate:
      case TaskSortFields.completedDate:
      case TaskSortFields.createdDate:
      case TaskSortFields.modifiedDate:
        return SharedTranslationKeys.noDate;
      case TaskSortFields.title:
      case null:
        return null;
    }
  }

  /// Returns the complete, ordered set of board column keys for a
  /// fixed-cardinality grouping (priority, date buckets, duration buckets), or
  /// null when the field has an open-ended/data-driven column set (tag, title).
  ///
  /// Used so the board always shows every possible column — e.g. all four
  /// Eisenhower quadrants plus "None" — even when some are empty.
  static List<String>? fixedColumnKeysFor(TaskSortFields? sortField) {
    switch (sortField) {
      case TaskSortFields.priority:
        return const [
          TaskTranslationKeys.priorityUrgentImportant,
          TaskTranslationKeys.priorityUrgentNotImportant,
          TaskTranslationKeys.priorityNotUrgentImportant,
          TaskTranslationKeys.priorityNotUrgentNotImportant,
          SharedTranslationKeys.none,
        ];
      case TaskSortFields.plannedDate:
      case TaskSortFields.deadlineDate:
      case TaskSortFields.completedDate:
        return const [
          SharedTranslationKeys.past,
          SharedTranslationKeys.today,
          SharedTranslationKeys.tomorrow,
          SharedTranslationKeys.next7Days,
          SharedTranslationKeys.future,
          SharedTranslationKeys.noDate,
        ];
      case TaskSortFields.estimatedTime:
      case TaskSortFields.totalDuration:
        return const [
          SharedTranslationKeys.durationLessThan15Min,
          SharedTranslationKeys.duration15To30Min,
          SharedTranslationKeys.duration30To60Min,
          SharedTranslationKeys.duration1To2Hours,
          SharedTranslationKeys.durationMoreThan2Hours,
          SharedTranslationKeys.none,
        ];
      case TaskSortFields.tag:
      case TaskSortFields.title:
      case TaskSortFields.createdDate:
      case TaskSortFields.modifiedDate:
      case null:
        return null;
    }
  }

  /// Reverse-maps a forward date group key to a representative target date.
  ///
  /// Returns [GroupKeyResult.recognized] for known date groups (with the
  /// resolved date, possibly null for the "no date" group) and
  /// [GroupKeyResult.unrecognized] for unknown keys.
  static GroupKeyResult<DateTime?> dateFromGroupKey(String groupKey, {DateTime? now}) {
    final nowValue = now ?? DateTime.now();
    final today = DateTime(nowValue.year, nowValue.month, nowValue.day);

    switch (groupKey) {
      case SharedTranslationKeys.noDate:
        return const GroupKeyResult.recognized(null);
      case SharedTranslationKeys.past:
        return GroupKeyResult.recognized(today.subtract(const Duration(days: 1)));
      case SharedTranslationKeys.today:
        return GroupKeyResult.recognized(today);
      case SharedTranslationKeys.tomorrow:
        return GroupKeyResult.recognized(today.add(const Duration(days: 1)));
      case SharedTranslationKeys.next7Days:
        return GroupKeyResult.recognized(today.add(const Duration(days: 3)));
      case SharedTranslationKeys.future:
        return GroupKeyResult.recognized(today.add(const Duration(days: 8)));
      default:
        return const GroupKeyResult.unrecognized();
    }
  }

  /// Reverse-maps a duration group key to a representative estimated time in
  /// minutes. Each bucket resolves to its lower bound so the moved task lands
  /// back in the same column. The "none" group maps to null (no estimate).
  static GroupKeyResult<int?> durationFromGroupKey(String groupKey) {
    switch (groupKey) {
      case SharedTranslationKeys.none:
        return const GroupKeyResult.recognized(null);
      case SharedTranslationKeys.durationLessThan15Min:
        return const GroupKeyResult.recognized(1);
      case SharedTranslationKeys.duration15To30Min:
        return const GroupKeyResult.recognized(15);
      case SharedTranslationKeys.duration30To60Min:
        return const GroupKeyResult.recognized(30);
      case SharedTranslationKeys.duration1To2Hours:
        return const GroupKeyResult.recognized(60);
      case SharedTranslationKeys.durationMoreThan2Hours:
        return const GroupKeyResult.recognized(120);
      default:
        return const GroupKeyResult.unrecognized();
    }
  }
}
