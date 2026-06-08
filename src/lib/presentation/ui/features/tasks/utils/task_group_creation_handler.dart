import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/utils/task_grouping_helper.dart';
import 'package:whph/core/application/shared/utils/group_key_result.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_creation_helper.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_draft.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_status_display.dart';

/// Inputs for opening a task creation dialog pre-filled from a board column
/// tap ("add to group" affordance on the empty-column placeholder).
class TaskGroupCreationInput {
  /// The group key from the board (e.g. priority quadrant, date bucket,
  /// tag name, or the "None" sentinel).
  final String groupKey;

  /// The field that defines the current grouping. The board passes either
  /// the explicit `groupOption` field or, if none, the first sort option.
  final TaskSortFields? groupField;

  /// Current search query text — pre-fills the new task title.
  final String? searchQuery;

  /// Fallback tag IDs taken from the current tag filter.
  final List<String>? defaultTagIds;

  /// Whether the "no tags" filter is active. When true, the new task
  /// defaults to no tags instead of the currently filtered tag set.
  final bool showNoTagsFilter;

  /// Fallback planned/deadline dates from the active date filter.
  final DateTime? defaultPlannedDate;
  final DateTime? defaultDeadlineDate;

  /// When set, the new task is created as a subtask of this parent.
  final String? parentTaskId;

  /// Optional callback invoked with the created task id and data.
  final void Function(String taskId, dynamic taskData)? onTaskCreated;

  const TaskGroupCreationInput({
    required this.groupKey,
    required this.groupField,
    this.searchQuery,
    this.defaultTagIds,
    this.showNoTagsFilter = false,
    this.defaultPlannedDate,
    this.defaultDeadlineDate,
    this.parentTaskId,
    this.onTaskCreated,
  });
}

/// Handles "add to group" taps on the kanban board by opening the standard
/// task creation dialog pre-filled with values derived from the destination
/// column. Lives in the presentation layer because it needs [BuildContext]
/// (to show the dialog) and the in-process service container.
class TaskGroupCreationHandler {
  /// Resolves a tag name to its ID via [GetListTagsQuery]. Returns null on
  /// lookup failure or when no tag matches.
  static Future<String?> resolveTagIdByName(String tagName) async {
    try {
      final response = await container.resolve<Mediator>().send<GetListTagsQuery, GetListTagsQueryResponse>(
            GetListTagsQuery(pageIndex: 0, pageSize: 100, search: tagName, showArchived: false),
          );
      final match = response.items.where((t) => t.name.toLowerCase() == tagName.toLowerCase()).firstOrNull;
      return match?.id;
    } catch (e, stackTrace) {
      Logger.error('Failed to resolve tag ID for name: $tagName', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Resolves a status group key (display name or translation key) to its ID.
  static Future<String?> resolveStatusIdByKey(String groupKey) async {
    // Check built-in statuses first
    if (groupKey == TaskTranslationKeys.statusBuiltInTodo) {
      return TaskStatusConstants.todoId;
    }
    if (groupKey == TaskTranslationKeys.statusBuiltInDone) {
      return TaskStatusConstants.doneId;
    }

    try {
      final response =
          await container.resolve<Mediator>().send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
                const GetListTaskStatusesQuery(),
              );
      for (final status in response.items) {
        final key = TaskStatusDisplay.resolveKey(name: status.name, isDoneStatus: status.isDoneStatus);
        if (key == groupKey) {
          return status.id;
        }
      }
      return null;
    } catch (e, stackTrace) {
      Logger.error('Failed to resolve status ID for key: $groupKey', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Translates a destination board column into a [TaskDraft] by consulting
  /// [TaskGroupingHelper] for the field that defines the grouping. Tag
  /// grouping is special: the group key is a user-supplied name and needs an
  /// async tag-id lookup — that path is handled in [handle] rather than here.
  static TaskDraft? draftForGroup({
    required String groupKey,
    required TaskSortFields groupField,
    required TaskGroupCreationInput input,
  }) {
    switch (groupField) {
      case TaskSortFields.priority:
        return TaskDraft(
          title: input.searchQuery,
          tagIds: input.showNoTagsFilter ? [] : input.defaultTagIds,
          plannedDate: input.defaultPlannedDate,
          deadlineDate: input.defaultDeadlineDate,
          priority: TaskGroupingHelper.priorityFromGroupKey(groupKey),
          parentTaskId: input.parentTaskId,
        );
      case TaskSortFields.plannedDate:
        switch (TaskGroupingHelper.dateFromGroupKey(groupKey)) {
          case Recognized(:final value):
            return TaskDraft(
              title: input.searchQuery,
              tagIds: input.showNoTagsFilter ? [] : input.defaultTagIds,
              plannedDate: value,
              deadlineDate: input.defaultDeadlineDate,
              parentTaskId: input.parentTaskId,
            );
          case Unrecognized():
            return null;
        }
      case TaskSortFields.deadlineDate:
        switch (TaskGroupingHelper.dateFromGroupKey(groupKey)) {
          case Recognized(:final value):
            return TaskDraft(
              title: input.searchQuery,
              tagIds: input.showNoTagsFilter ? [] : input.defaultTagIds,
              plannedDate: input.defaultPlannedDate,
              deadlineDate: value,
              parentTaskId: input.parentTaskId,
            );
          case Unrecognized():
            return null;
        }
      case TaskSortFields.completedDate:
        return TaskDraft(
          title: input.searchQuery,
          tagIds: input.showNoTagsFilter ? [] : input.defaultTagIds,
          plannedDate: input.defaultPlannedDate,
          deadlineDate: input.defaultDeadlineDate,
          completed: TaskGroupingHelper.isCompletedFromGroupKey(groupKey),
          parentTaskId: input.parentTaskId,
        );
      case TaskSortFields.estimatedTime:
        switch (TaskGroupingHelper.durationFromGroupKey(groupKey)) {
          case Recognized(:final value):
            return TaskDraft(
              title: input.searchQuery,
              tagIds: input.showNoTagsFilter ? [] : input.defaultTagIds,
              plannedDate: input.defaultPlannedDate,
              deadlineDate: input.defaultDeadlineDate,
              estimatedTime: value,
              parentTaskId: input.parentTaskId,
            );
          case Unrecognized():
            return null;
        }
      case TaskSortFields.tag:
        // The "None" group means no tags — emit a draft with empty tagIds.
        // Non-null tag names are resolved asynchronously in [handle].
        final tagName = TaskGroupingHelper.tagNameFromGroupKey(groupKey);
        if (tagName == null) {
          return TaskDraft(
            title: input.searchQuery,
            tagIds: const [],
            plannedDate: input.defaultPlannedDate,
            deadlineDate: input.defaultDeadlineDate,
            parentTaskId: input.parentTaskId,
          );
        }
        return null; // Signal: caller must use the async path.
      case TaskSortFields.status:
        return null; // Signal: caller must use the async path.
      case TaskSortFields.totalDuration:
      case TaskSortFields.title:
      case TaskSortFields.createdDate:
      case TaskSortFields.modifiedDate:
        return null;
    }
  }

  /// Opens the task creation dialog pre-filled from the destination group.
  /// Returns true when a dialog was actually shown, false when the input was
  /// incomplete (no group field, unrecognized key, or no widget context).
  static Future<bool> handle({
    required BuildContext context,
    required TaskGroupCreationInput input,
  }) async {
    final groupField = input.groupField;
    if (groupField == null) return false;
    if (!context.mounted) return false;

    // Tag grouping needs an async tag-id lookup; resolve then re-enter
    // through the same code path with the resolved id.
    if (groupField == TaskSortFields.tag) {
      final tagName = TaskGroupingHelper.tagNameFromGroupKey(input.groupKey);
      if (tagName != null) {
        final tagId = await resolveTagIdByName(tagName);
        if (!context.mounted) return false;
        await TaskCreationHelper.createTask(
          context: context,
          draft: TaskDraft(
            title: input.searchQuery,
            tagIds: tagId != null ? [tagId] : const [],
            plannedDate: input.defaultPlannedDate,
            deadlineDate: input.defaultDeadlineDate,
            parentTaskId: input.parentTaskId,
          ),
          onTaskCreated: input.onTaskCreated,
        );
        return true;
      }
      // tagName == null is the "None" group — fall through to the sync path.
    }

    // Status grouping needs an async status-id lookup; resolve then re-enter
    // through the same code path with the resolved id.
    if (groupField == TaskSortFields.status) {
      final statusId = await resolveStatusIdByKey(input.groupKey);
      if (statusId == null) {
        Logger.warning(
            'Could not resolve status for group key "${input.groupKey}". Task will be created with default status.');
      }
      if (!context.mounted) return false;
      await TaskCreationHelper.createTask(
        context: context,
        draft: TaskDraft(
          title: input.searchQuery,
          tagIds: input.showNoTagsFilter ? [] : input.defaultTagIds,
          plannedDate: input.defaultPlannedDate,
          deadlineDate: input.defaultDeadlineDate,
          statusId: statusId,
          parentTaskId: input.parentTaskId,
        ),
        onTaskCreated: input.onTaskCreated,
      );
      return true;
    }

    final draft = draftForGroup(
      groupKey: input.groupKey,
      groupField: groupField,
      input: input,
    );
    if (draft == null) return false;
    if (!context.mounted) return false;

    await TaskCreationHelper.createTask(
      context: context,
      draft: draft,
      onTaskCreated: input.onTaskCreated,
    );
    return true;
  }
}
