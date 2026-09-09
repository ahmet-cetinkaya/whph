import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:whph/core/application/shared/services/sibling_reorder_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';

typedef McpBeforeCommit = Future<void> Function();

final class McpRevisionConflictException implements Exception {
  const McpRevisionConflictException();
}

final class McpTaskNotFoundException implements Exception {
  const McpTaskNotFoundException();
}

final class McpTaskPatch {
  const McpTaskPatch(this.values);

  final Map<String, Object?> values;
}

final class McpTaskMutationResult {
  const McpTaskMutationResult(
      {required this.id,
      required this.revision,
      this.order,
      this.recurringTaskId,
      this.wasChanged = true});

  final String id;
  final DateTime revision;
  final String? order;
  final String? recurringTaskId;
  final bool wasChanged;
}

/// Transaction owner for MCP patches. It never wraps commands which emit events.
final class McpTaskActions {
  static final DateTime virtualStatusRevision =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  McpTaskActions({
    required IApplicationTransactionService transactions,
    required ITaskRepository taskRepository,
    required ITaskStatusRepository taskStatusRepository,
    required ITaskTagRepository taskTagRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required ITaskEvents taskEvents,
    required ITagRepository tagRepository,
    required ITaskRecurrenceService recurrenceService,
    required Mediator mediator,
  })  : _transactions = transactions,
        _taskRepository = taskRepository,
        _taskStatusRepository = taskStatusRepository,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository,
        _taskEvents = taskEvents,
        _tagRepository = tagRepository,
        _recurrenceService = recurrenceService,
        _mediator = mediator;

  final IApplicationTransactionService _transactions;
  final ITaskRepository _taskRepository;
  final ITaskStatusRepository _taskStatusRepository;
  final ITaskTagRepository _taskTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ITaskEvents _taskEvents;
  final ITagRepository _tagRepository;
  final ITaskRecurrenceService _recurrenceService;
  final Mediator _mediator;

  Future<McpTaskMutationResult> createTask({
    required Task task,
    required List<String> tagIds,
    required McpBeforeCommit beforeCommit,
  }) async {
    final persisted = await _transactions.run(() async {
      final isCompleted = await validateReferences(
        taskId: task.id,
        parentId: task.parentTaskId,
        statusId: task.statusId,
        tagIds: tagIds,
      );
      final lastTasks = await _taskRepository.getList(
        0,
        1,
        customWhereFilter: CustomWhereFilter(
          'parent_task_id ${task.parentTaskId == null ? 'IS NULL' : '= ?'} AND deleted_date IS NULL',
          task.parentTaskId == null ? const [] : [task.parentTaskId!],
        ),
        customOrder: [
          CustomOrder(field: 'order', direction: SortDirection.desc)
        ],
      );
      final created = task.copyWith(
        order: OrderRank.neighborRank(
          beforeOrder:
              lastTasks.items.isEmpty ? null : lastTasks.items.first.order,
          afterOrder: null,
        ),
        completedAt: isCompleted ? DateTime.now().toUtc() : null,
      );
      await _validateTask(created);
      await beforeCommit();
      await _taskRepository.add(created);
      await _replaceTags(created.id, tagIds);
      return (await _taskRepository.getById(created.id))!;
    });
    _taskEvents.notifyTaskCreated(persisted.id);
    return McpTaskMutationResult(
      id: persisted.id,
      revision: _revisionOf(persisted),
    );
  }

  Future<McpTaskMutationResult> updateTask({
    required String id,
    required DateTime expectedRevision,
    required McpTaskPatch patch,
    required McpBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final task = await _requireTask(id, expectedRevision);
      final next = _applyPatch(task, patch);
      await _validateTask(next);
      await _validateCompletionStatusChange(task, next, patch);
      await beforeCommit();
      final revision =
          await _taskRepository.updateIfRevision(next, expectedRevision);
      if (revision == null) throw const McpRevisionConflictException();
      if (patch.values['tagIds'] case final List<String> tagIds) {
        await _replaceTags(next.id, tagIds);
      }
      if (patch.values['tagOrder'] case final Map<String, int> tagOrder) {
        await _taskTagRepository.updateTagOrders(next.id, tagOrder);
      }
      return (task: next, revision: revision);
    });
    _taskEvents.notifyTaskUpdated(id);
    return McpTaskMutationResult(id: id, revision: result.revision);
  }

  Future<bool> validateReferences({
    String? taskId,
    String? parentId,
    String? statusId,
    List<String>? tagIds,
  }) async {
    if (parentId != null && await _taskRepository.getById(parentId) == null) {
      throw ArgumentError('Parent task does not exist.');
    }
    if (taskId != null && parentId == taskId) {
      throw ArgumentError('A task cannot be its own parent.');
    }
    final status =
        statusId == null ? null : await _taskStatusRepository.getById(statusId);
    if (statusId != null && status == null) {
      throw ArgumentError('Task status does not exist.');
    }
    for (final tagId in tagIds ?? const <String>[]) {
      if (await _tagRepository.getById(tagId) == null) {
        throw ArgumentError('Task tag does not exist.');
      }
    }
    return status?.isDoneStatus ?? false;
  }

  Future<DateTime> deleteTask({
    required String id,
    required DateTime expectedRevision,
    required McpBeforeCommit beforeCommit,
  }) async {
    final deletedAt = DateTime.now().toUtc();
    await _transactions.run(() async {
      final task = await _requireTask(id, expectedRevision);
      await beforeCommit();
      await _deleteTaskTree(task);
    });
    _taskEvents.notifyTaskDeleted(id);
    return deletedAt;
  }

  Future<McpTaskMutationResult> setCompletion({
    required String id,
    required DateTime expectedRevision,
    required bool isCompleted,
    DateTime? completedAt,
    required McpBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final task = await _requireTask(id, expectedRevision);
      if (task.isCompleted == isCompleted) {
        await beforeCommit();
        return McpTaskMutationResult(
            id: id, revision: _revisionOf(task), wasChanged: false);
      }
      final updated = task.copyWith(
        completedAt: isCompleted ? completedAt ?? DateTime.now().toUtc() : null,
        statusId: isCompleted
            ? TaskStatusConstants.doneId
            : TaskStatusConstants.todoId,
      );
      await beforeCommit();
      final revision =
          await _taskRepository.updateIfRevision(updated, expectedRevision);
      if (revision == null) throw const McpRevisionConflictException();
      if (isCompleted &&
          updated.estimatedTime != null &&
          updated.estimatedTime! > 0) {
        final records = await _taskTimeRecordRepository.getByTaskId(id);
        if (records.isEmpty) {
          await TaskTimeRecordService.addDurationToTaskTimeRecord(
            repository: _taskTimeRecordRepository,
            taskId: id,
            targetDate: updated.completedAt!,
            durationToAdd: updated.estimatedTime! * 60,
          );
        }
      }
      return McpTaskMutationResult(id: id, revision: revision);
    });
    final recurringTaskId = isCompleted && result.wasChanged
        ? await _recurrenceService.handleCompletedRecurringTask(id, _mediator)
        : null;
    if (!result.wasChanged) return result;
    if (isCompleted) {
      _taskEvents.notifyTaskCompleted(id);
    } else {
      _taskEvents.notifyTaskUpdated(id);
    }
    return McpTaskMutationResult(
        id: result.id,
        revision: result.revision,
        recurringTaskId: recurringTaskId);
  }

  Future<McpTaskMutationResult> reorderTask({
    required String id,
    required DateTime expectedRevision,
    required int targetIndex,
    String? beforeId,
    String? afterId,
    required McpBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final task = await _requireTask(id, expectedRevision);
      final parentId = task.parentTaskId;
      final siblings = await _taskRepository.getAll(
        customWhereFilter: CustomWhereFilter(
          'parent_task_id ${parentId == null ? 'IS NULL' : '= ?'} AND id != ? AND deleted_date IS NULL',
          parentId == null ? [task.id] : [parentId, task.id],
        ),
        customOrder: [
          CustomOrder(field: 'order', direction: SortDirection.asc),
          CustomOrder(field: 'created_date', direction: SortDirection.asc),
          CustomOrder(field: 'id', direction: SortDirection.asc),
        ],
      );
      final placement = const SiblingReorderService().computePlacement(
        moved: task,
        siblings: siblings,
        targetIndex: targetIndex,
        beforeId: beforeId,
        afterId: afterId,
        idOf: (item) => item.id,
        orderOf: (item) => item.order,
      );
      await beforeCommit();
      if (placement.requiresRenormalization) {
        final reordered = placement.renumbered!
            .where((sibling) => sibling.id != task.id)
            .map((sibling) => sibling.copyWith(
                order: placement.renumberedOrder![sibling.id]!))
            .toList(growable: false);
        await _taskRepository.updateMultiple(reordered);
        final moved =
            task.copyWith(order: placement.renumberedOrder![task.id]!);
        final revision =
            await _taskRepository.updateIfRevision(moved, expectedRevision);
        if (revision == null) throw const McpRevisionConflictException();
        return (order: moved.order, revision: revision);
      } else {
        final moved = task.copyWith(order: placement.order);
        final revision =
            await _taskRepository.updateIfRevision(moved, expectedRevision);
        if (revision == null) throw const McpRevisionConflictException();
        return (order: moved.order, revision: revision);
      }
    });
    _taskEvents.notifyTaskUpdated(id);
    return McpTaskMutationResult(
        id: id, revision: result.revision, order: result.order);
  }

  Future<List<TaskTimeRecord>> listTimeRecords(
      String taskId, DateTime? from, DateTime? to) async {
    if (await _taskRepository.getById(taskId) == null)
      throw const McpTaskNotFoundException();
    final records = (await _taskTimeRecordRepository.getByTaskId(taskId))
        .where((record) =>
            record.deletedDate == null &&
            (from == null || !record.createdDate.isBefore(from)) &&
            (to == null || !record.createdDate.isAfter(to)))
        .toList(growable: false);
    return List.unmodifiable(records.toList()
      ..sort((left, right) {
        final byDate = left.createdDate.compareTo(right.createdDate);
        return byDate != 0 ? byDate : left.id.compareTo(right.id);
      }));
  }

  Future<void> ensureTaskExists(String taskId) async {
    if (await _taskRepository.getById(taskId) == null) {
      throw const McpTaskNotFoundException();
    }
  }

  Future<McpTaskMutationResult> updateTimeRecord({
    required String taskId,
    required DateTime date,
    required int totalDurationSeconds,
    required DateTime expectedRevision,
    required McpBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final task = await _requireTask(taskId, expectedRevision);
      final start = DateTime.utc(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final records = (await _taskTimeRecordRepository.getByTaskId(taskId))
          .where((record) =>
              record.deletedDate == null &&
              !record.createdDate.isBefore(start) &&
              record.createdDate.isBefore(end));
      await beforeCommit();
      for (final record in records) {
        await _taskTimeRecordRepository.delete(record);
      }
      if (totalDurationSeconds > 0) {
        await TaskTimeRecordService.setTotalDurationForTaskTimeRecord(
          repository: _taskTimeRecordRepository,
          taskId: taskId,
          targetDate: start,
          totalDuration: totalDurationSeconds,
        );
      }
      final revision =
          await _taskRepository.updateIfRevision(task, expectedRevision);
      if (revision == null) throw const McpRevisionConflictException();
      return McpTaskMutationResult(id: taskId, revision: revision);
    });
    _taskEvents.notifyTaskTimeRecordUpdated(taskId);
    return result;
  }

  Future<TaskStatus> updateStatus({
    required String id,
    required DateTime expectedRevision,
    required McpTaskPatch patch,
    required McpBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final isPersisted = await _taskStatusRepository.existsInDb(id);
      final status =
          await _requireStatus(id, expectedRevision, isPersisted: isPersisted);
      final updated = TaskStatus(
        id: status.id,
        createdDate: status.createdDate,
        modifiedDate: _nextRevision(expectedRevision),
        name: patch.values.containsKey('name')
            ? patch.values['name']! as String
            : status.name,
        color: patch.values.containsKey('color')
            ? patch.values['color'] as String?
            : status.color,
        order: status.order,
        isBuiltIn: status.isBuiltIn,
        isDoneStatus: status.isDoneStatus,
      );
      _validateStatus(updated);
      await beforeCommit();
      if (isPersisted) {
        final revision = await _taskStatusRepository.updateIfRevision(
            updated, expectedRevision);
        if (revision == null) throw const McpRevisionConflictException();
        return TaskStatus(
          id: updated.id,
          createdDate: updated.createdDate,
          modifiedDate: revision,
          name: updated.name,
          color: updated.color,
          order: updated.order,
          isBuiltIn: updated.isBuiltIn,
          isDoneStatus: updated.isDoneStatus,
        );
      } else {
        final virtualUpdate = TaskStatus(
          id: updated.id,
          createdDate: updated.createdDate,
          name: updated.name,
          color: updated.color,
          order: updated.order,
          isBuiltIn: updated.isBuiltIn,
          isDoneStatus: updated.isDoneStatus,
        );
        await _taskStatusRepository.add(virtualUpdate);
        return (await _taskStatusRepository.getById(updated.id))!;
      }
    });
    _taskEvents.notifyTaskUpdated(id);
    return result;
  }

  Future<TaskStatus> createStatus({
    required String name,
    required String? color,
    required McpBeforeCommit beforeCommit,
  }) async {
    final status = TaskStatus(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      name: name,
      color: color,
    );
    _validateStatus(status);
    final persisted = await _transactions.run(() async {
      await beforeCommit();
      await _taskStatusRepository.add(status);
      return (await _taskStatusRepository.getById(status.id))!;
    });
    _taskEvents.notifyTaskUpdated(persisted.id);
    return persisted;
  }

  Future<DateTime> deleteStatus({
    required String id,
    required DateTime expectedRevision,
    required McpBeforeCommit beforeCommit,
  }) async {
    final deletedAt = DateTime.now().toUtc();
    await _transactions.run(() async {
      final status = await _requireStatus(id, expectedRevision);
      if (status.isBuiltIn)
        throw ArgumentError('Built-in statuses cannot be deleted.');
      final tasks = await _taskRepository.getAll(
        customWhereFilter:
            CustomWhereFilter('status_id = ? AND deleted_date IS NULL', [id]),
      );
      if (tasks.isNotEmpty)
        throw ArgumentError('Statuses in use cannot be deleted.');
      await beforeCommit();
      await _taskStatusRepository.delete(status);
    });
    _taskEvents.notifyTaskUpdated(id);
    return deletedAt;
  }

  Future<int> reorderStatuses({
    required List<({String id, DateTime revision, String order})> changes,
    required McpBeforeCommit beforeCommit,
  }) async {
    final count = await _transactions.run(() async {
      final statuses = <TaskStatus>[];
      final virtualStatuses = <TaskStatus>[];
      for (final change in changes) {
        final isPersisted = await _taskStatusRepository.existsInDb(change.id);
        final status = await _requireStatus(change.id, change.revision,
            isPersisted: isPersisted);
        final reordered = TaskStatus(
          id: status.id,
          createdDate: status.createdDate,
          modifiedDate: _nextRevision(change.revision),
          name: status.name,
          color: status.color,
          order: change.order,
          isBuiltIn: status.isBuiltIn,
          isDoneStatus: status.isDoneStatus,
        );
        if (isPersisted) {
          statuses.add(reordered);
        } else {
          virtualStatuses.add(reordered);
        }
      }
      await beforeCommit();
      for (final status in virtualStatuses) {
        await _taskStatusRepository.add(status);
      }
      await _taskStatusRepository.updateMultiple(statuses);
      return statuses.length + virtualStatuses.length;
    });
    for (final change in changes) {
      _taskEvents.notifyTaskUpdated(change.id);
    }
    return count;
  }

  Future<Task> _requireTask(String id, DateTime revision) async {
    final task = await _taskRepository.getById(id);
    if (task == null) throw const McpTaskNotFoundException();
    _checkRevision(task, revision);
    return task;
  }

  Future<TaskStatus> _requireStatus(String id, DateTime revision,
      {bool? isPersisted}) async {
    final status = await _taskStatusRepository.getById(id);
    if (status == null) throw const McpTaskNotFoundException();
    final persisted = isPersisted ?? await _taskStatusRepository.existsInDb(id);
    if (persisted) {
      _checkRevision(status, revision);
    } else if (revision.toUtc() != virtualStatusRevision) {
      throw const McpRevisionConflictException();
    }
    return status;
  }

  void _validateStatus(TaskStatus status) {
    if (!status.isBuiltIn && status.name.trim().isEmpty)
      throw ArgumentError('Status name cannot be empty.');
    if (status.name.length > 50)
      throw ArgumentError('Status name is too long.');
    final color = status.color;
    if (color != null &&
        color.isNotEmpty &&
        !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(color)) {
      throw ArgumentError(
          'Status color must be a six-digit hexadecimal value.');
    }
  }

  void _checkRevision(BaseEntity<String> entity, DateTime expected) {
    final actual = _revisionOf(entity).toUtc().millisecondsSinceEpoch;
    final requested = expected.toUtc().millisecondsSinceEpoch;
    if (actual != requested) throw const McpRevisionConflictException();
  }

  DateTime _revisionOf(BaseEntity<String> entity) =>
      entity.modifiedDate ?? entity.createdDate;

  DateTime _nextRevision(DateTime expected) {
    final minimum = expected.toUtc().add(const Duration(milliseconds: 1));
    final now = DateTime.now().toUtc();
    return now.isAfter(minimum) ? now : minimum;
  }

  Task _applyPatch(Task task, McpTaskPatch patch) {
    final values = patch.values;
    return task.copyWith(
      title:
          values.containsKey('title') ? values['title']! as String : task.title,
      description: values.containsKey('description')
          ? values['description']
          : task.description,
      priority:
          values.containsKey('priority') ? values['priority'] : task.priority,
      plannedDate: values.containsKey('plannedAt')
          ? values['plannedAt']
          : task.plannedDate,
      deadlineDate: values.containsKey('deadlineAt')
          ? values['deadlineAt']
          : task.deadlineDate,
      estimatedTime: values.containsKey('estimatedMinutes')
          ? values['estimatedMinutes']
          : task.estimatedTime,
      statusId:
          values.containsKey('statusId') ? values['statusId'] : task.statusId,
      parentTaskId: values.containsKey('parentId')
          ? values['parentId']
          : task.parentTaskId,
      plannedDateReminderTime: values['plannedReminder'] as ReminderTime?,
      deadlineDateReminderTime: values['deadlineReminder'] as ReminderTime?,
      plannedDateReminderCustomOffset:
          values.containsKey('plannedReminderOffset')
              ? values['plannedReminderOffset']
              : task.plannedDateReminderCustomOffset,
      deadlineDateReminderCustomOffset:
          values.containsKey('deadlineReminderOffset')
              ? values['deadlineReminderOffset']
              : task.deadlineDateReminderCustomOffset,
      recurrenceType: values['recurrenceType'] as RecurrenceType?,
      recurrenceInterval: values.containsKey('recurrenceInterval')
          ? values['recurrenceInterval']
          : task.recurrenceInterval,
      recurrenceDaysString: values.containsKey('recurrenceDays')
          ? values['recurrenceDays']
          : task.recurrenceDaysString,
      recurrenceStartDate: values.containsKey('recurrenceStart')
          ? values['recurrenceStart']
          : task.recurrenceStartDate,
      recurrenceEndDate: values.containsKey('recurrenceEnd')
          ? values['recurrenceEnd']
          : task.recurrenceEndDate,
      recurrenceCount: values.containsKey('recurrenceCount')
          ? values['recurrenceCount']
          : task.recurrenceCount,
    );
  }

  Future<void> _validateTask(Task task) async {
    if (task.title.trim().isEmpty)
      throw ArgumentError('Task title must not be empty.');
    if (task.plannedDate != null &&
        task.deadlineDate != null &&
        task.deadlineDate!.isBefore(task.plannedDate!)) {
      throw ArgumentError('Deadline must not be before planned time.');
    }
    if (task.parentTaskId == task.id)
      throw ArgumentError('A task cannot be its own parent.');
    var parentId = task.parentTaskId;
    while (parentId != null) {
      final parent = await _taskRepository.getById(parentId);
      if (parent == null) throw ArgumentError('Parent task does not exist.');
      if (parent.id == task.id)
        throw ArgumentError('Task parent cycle detected.');
      parentId = parent.parentTaskId;
    }
    if (task.statusId != null &&
        await _taskStatusRepository.getById(task.statusId!) == null) {
      throw ArgumentError('Task status does not exist.');
    }
  }

  Future<void> _validateCompletionStatusChange(
      Task original, Task updated, McpTaskPatch patch) async {
    if (!patch.values.containsKey('statusId')) return;
    final status = updated.statusId == null
        ? null
        : await _taskStatusRepository.getById(updated.statusId!);
    if ((status?.isDoneStatus ?? false) != original.isCompleted) {
      throw ArgumentError('Use the completion action to change completion.');
    }
  }

  Future<void> _replaceTags(String taskId, List<String> tagIds) async {
    for (final tagId in tagIds) {
      if (await _tagRepository.getById(tagId) == null) {
        throw ArgumentError('Task tag does not exist.');
      }
    }
    final existing = await _taskTagRepository.getByTaskId(taskId);
    final wanted = tagIds.toSet();
    for (final relation
        in existing.where((relation) => !wanted.contains(relation.tagId))) {
      await _taskTagRepository.delete(relation);
    }
    final existingIds = existing.map((relation) => relation.tagId).toSet();
    for (final tagId in wanted.difference(existingIds)) {
      await _taskTagRepository.add(TaskTag(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        taskId: taskId,
        tagId: tagId,
      ));
    }
  }

  Future<void> _deleteTaskTree(Task task) async {
    final descendants = <Task>[
      ...await _taskRepository.getByParentTaskId(task.id),
      ...await _taskRepository.getByRecurrenceParentId(task.id),
    ];
    for (final descendant in descendants) {
      await _deleteTaskTree(descendant);
    }
    for (final tag in await _taskTagRepository.getByTaskId(task.id)) {
      await _taskTagRepository.delete(tag);
    }
    for (final record in await _taskTimeRecordRepository.getByTaskId(task.id)) {
      await _taskTimeRecordRepository.delete(record);
    }
    await _taskRepository.delete(task);
  }
}
