import 'dart:io';

import 'package:acore/acore.dart';
import 'package:mcp_dart/mcp_dart.dart' hide Task;
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/commands/import_tasks_command.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_total_duration_by_task_id_query.dart';
import 'package:whph/core/application/features/tasks/services/mcp_task_actions.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

part 'task_tool_contract.dart';
part 'task_tool_support.dart';

typedef McpTaskCommitGuard = Future<bool> Function(
  RequestHandlerExtra extra,
  Set<String> scopes,
);

List<McpToolDefinition> buildTaskTools({
  required Mediator mediator,
  required McpTaskActions actions,
  required McpTaskCommitGuard authorizeBeforeCommit,
}) =>
    List.unmodifiable([
      _tool('whph_tasks_list', 'List and filter tasks.', _listInput, _pagedOutput, const {'tasks:read', 'tags:read'},
          _read, (args, extra) => _list(mediator, args)),
      _tool('whph_tasks_read', 'Read a task with tags, recurrence, reminders, and time records.', _idInput, _taskOutput,
          const {'tasks:read', 'tags:read'}, _read, (args, extra) => _readTask(mediator, actions, args)),
      _tool(
          'whph_tasks_create',
          'Create a task and its requested relationships.',
          _createInput,
          _idRevisionOutput,
          const {'tasks:write', 'tags:write'},
          _additive,
          (args, extra) => _create(mediator, actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_tasks_update',
          'Update only supplied task fields.',
          _updateInput,
          _idRevisionOutput,
          const {'tasks:write', 'tags:write'},
          _mutation,
          (args, extra) => _update(actions, authorizeBeforeCommit, args, extra)),
      _tool('whph_tasks_delete', 'Delete a task and owned records.', _revisionInput, _deleteOutput,
          const {'tasks:delete'}, _destructive, (args, extra) => _delete(actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_tasks_set_completion',
          'Set task completion explicitly.',
          _completionInput,
          _completionOutput,
          const {'tasks:write'},
          _mutation,
          (args, extra) => _setCompletion(actions, authorizeBeforeCommit, args, extra)),
      _tool('whph_tasks_reorder', 'Move a task within its sibling order.', _reorderInput, _reorderOutput,
          const {'tasks:write'}, _mutation, (args, extra) => _reorder(actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_tasks_import',
          'Import CSV task content without accepting a file path.',
          _importInput,
          _importOutput,
          const {'tasks:write', 'tags:write', 'data:import'},
          _additive,
          (args, extra) => _import(mediator, authorizeBeforeCommit, args, extra)),
      _tool('whph_task_time_records_list', 'List time records for one task.', _timeListInput, _timeListOutput,
          const {'tasks:read', 'timers:read'}, _read, (args, extra) => _timeList(actions, args)),
      _tool(
          'whph_task_time_records_add',
          'Add seconds to a task time record.',
          _timeAddInput,
          _idOutput,
          const {'tasks:write', 'timers:write'},
          _additive,
          (args, extra) => _timeAdd(mediator, actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_task_time_records_update',
          'Set the total seconds for a task local date.',
          _timeUpdateInput,
          _idRevisionOutput,
          const {'tasks:write', 'timers:write'},
          _mutation,
          (args, extra) => _timeUpdate(actions, authorizeBeforeCommit, args, extra)),
      _tool('whph_task_time_total', 'Read total task duration in seconds.', _timeTotalInput, _timeTotalOutput,
          const {'tasks:read', 'timers:read'}, _read, (args, extra) => _timeTotal(mediator, args)),
    ]);

Future<CallToolResult> _list(Mediator mediator, McpToolArguments args) => _run(() async {
      final pageSize = _pageSize(args);
      final pageIndex = _cursor(args);
      final response = await mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(GetListTasksQuery(
        pageIndex: pageIndex,
        pageSize: pageSize,
        filterBySearch: args.optionalString('search'),
        filterByPlannedStartDate: _optionalInstant(args, 'plannedFrom'),
        filterByPlannedEndDate: _optionalInstant(args, 'plannedTo'),
        filterByDeadlineStartDate: _optionalInstant(args, 'deadlineFrom'),
        filterByDeadlineEndDate: _optionalInstant(args, 'deadlineTo'),
        filterByCompletedStartDate: _optionalInstant(args, 'completedFrom'),
        filterByCompletedEndDate: _optionalInstant(args, 'completedTo'),
        filterDateOr: args.optionalString('dateFilterMode') == 'or',
        includeNullDates: args.optionalBool('includeUnscheduled') ?? false,
        filterByTags: _stringList(args, 'tagIds'),
        filterNoTags: args.optionalBool('withoutTags') ?? false,
        filterByCompleted: args.optionalBool('isCompleted'),
        filterByParentTaskId: args.optionalString('parentId'),
        areParentAndSubTasksIncluded: args.optionalBool('includeDescendants') ?? false,
        sortBy: _sort(args.optionalList('sort')),
        sortByCustomSort: !args.contains('sort'),
        groupBy: _sortOne(args.optionalObject('groupBy')),
        customTagSortOrder: _stringList(args, 'customTagOrder'),
        ignoreArchivedTagVisibility: args.optionalBool('includeArchivedTags') ?? false,
      ));
      return _page(response.items.map(_taskSummary).toList(), response.totalItemCount, pageIndex, pageSize);
    });

Future<CallToolResult> _readTask(Mediator mediator, McpTaskActions actions, McpToolArguments args) => _run(() async {
      final id = args.requireString('id');
      final task = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: id));
      final tags = await mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
        GetListTaskTagsQuery(taskId: id, pageIndex: 0, pageSize: 200),
      );
      final timeRecords = await actions.listTimeRecords(id, null, null);
      return {
        ..._taskMap(task),
        'tags': tags.items
            .map((tag) => {
                  'id': tag.tagId,
                  'name': tag.tagName,
                  'color': tag.tagColor,
                  'type': tag.tagType.name,
                  'order': tag.tagOrder,
                })
            .toList(),
        'timeRecords': timeRecords
            .map((record) => {
                  'id': record.id,
                  'occurredAt': _iso(record.createdDate),
                  'durationSeconds': record.duration,
                })
            .toList(),
        'totalDurationSeconds': task.totalDuration,
        'revision': _revision(task),
      };
    });

Future<CallToolResult> _create(Mediator mediator, McpTaskActions actions, McpTaskCommitGuard guard,
        McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      final id = KeyHelper.generateStringId();
      final recurrence = args.optionalObject('recurrence');
      final result = await actions.createTask(
        task: Task(
          id: id,
          createdDate: DateTime.now().toUtc(),
          title: args.requireString('title'),
          description: args.optionalString('description'),
          priority: _enum(args.optionalString('priority'), EisenhowerPriority.values),
          plannedDate: _optionalInstant(args, 'plannedAt'),
          deadlineDate: _optionalInstant(args, 'deadlineAt'),
          estimatedTime: args.optionalInt('estimatedMinutes'),
          statusId: args.optionalString('statusId') ?? TaskStatusConstants.todoId,
          parentTaskId: args.optionalString('parentId'),
          plannedDateReminderTime: _reminder(args.optionalObject('plannedReminder')) ?? ReminderTime.none,
          plannedDateReminderCustomOffset: _reminderOffset(args.optionalObject('plannedReminder')),
          deadlineDateReminderTime: _reminder(args.optionalObject('deadlineReminder')) ?? ReminderTime.none,
          deadlineDateReminderCustomOffset: _reminderOffset(args.optionalObject('deadlineReminder')),
          recurrenceType: _recurrenceType(recurrence) ?? RecurrenceType.none,
          recurrenceInterval: _recurrenceInt(args, 'interval'),
          recurrenceDaysString: _recurrenceDays(args)?.map((day) => day.name).join(','),
          recurrenceStartDate: _recurrenceDate(args, 'startAt'),
          recurrenceEndDate: _recurrenceDate(args, 'endAt'),
          recurrenceCount: _recurrenceInt(args, 'count'),
        ),
        tagIds: _stringList(args, 'tagIds') ?? const [],
        beforeCommit: () => _guard(guard, extra, const {'tasks:write', 'tags:write'}),
      );
      return {
        'id': result.id,
        'revision': _iso(result.revision),
      };
    });

Future<CallToolResult> _update(
  McpTaskActions actions,
  McpTaskCommitGuard guard,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final patch = <String, Object?>{};
      _copy(args, patch, 'title', args.optionalString);
      _copy(args, patch, 'description', args.optionalString);
      if (args.contains('priority'))
        patch['priority'] = _enum(args.optionalString('priority'), EisenhowerPriority.values);
      if (args.contains('plannedAt')) patch['plannedAt'] = _nullableInstant(args, 'plannedAt');
      if (args.contains('deadlineAt')) patch['deadlineAt'] = _nullableInstant(args, 'deadlineAt');
      _copy(args, patch, 'estimatedMinutes', args.optionalInt);
      _copy(args, patch, 'statusId', args.optionalString);
      _copy(args, patch, 'parentId', args.optionalString);
      if (args.contains('tagIds')) patch['tagIds'] = _stringList(args, 'tagIds')!;
      if (args.contains('tagOrder')) patch['tagOrder'] = _tagOrder(args.optionalList('tagOrder')!);
      if (args.contains('plannedReminder')) {
        final reminder = args.optionalObject('plannedReminder');
        patch['plannedReminder'] = args['plannedReminder'] == null ? ReminderTime.none : _reminder(reminder);
        patch['plannedReminderOffset'] = _reminderOffset(reminder);
      }
      if (args.contains('deadlineReminder')) {
        final reminder = args.optionalObject('deadlineReminder');
        patch['deadlineReminder'] = args['deadlineReminder'] == null ? ReminderTime.none : _reminder(reminder);
        patch['deadlineReminderOffset'] = _reminderOffset(reminder);
      }
      if (args.contains('recurrence')) _addRecurrencePatch(patch, args.optionalObject('recurrence'));
      final result = await actions.updateTask(
        id: args.requireString('id'),
        expectedRevision: _requiredRevision(args),
        patch: McpTaskPatch(Map.unmodifiable(patch)),
        beforeCommit: () => _guard(guard, extra, const {'tasks:write', 'tags:write'}),
      );
      return {'id': result.id, 'revision': _iso(result.revision)};
    });

Future<CallToolResult> _delete(
        McpTaskActions actions, McpTaskCommitGuard guard, McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      final deletedAt = await actions.deleteTask(
        id: args.requireString('id'),
        expectedRevision: _requiredRevision(args),
        beforeCommit: () => _guard(guard, extra, const {'tasks:delete'}),
      );
      return {'id': args.requireString('id'), 'deletedAt': _iso(deletedAt)};
    });

Future<CallToolResult> _setCompletion(
        McpTaskActions actions, McpTaskCommitGuard guard, McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      final isCompleted = args['isCompleted'];
      if (isCompleted is! bool) throw _validation('isCompleted', 'must be a boolean');
      final result = await actions.setCompletion(
        id: args.requireString('id'),
        expectedRevision: _requiredRevision(args),
        isCompleted: isCompleted,
        completedAt: _optionalInstant(args, 'completedAt'),
        beforeCommit: () => _guard(guard, extra, const {'tasks:write'}),
      );
      return {
        'id': result.id,
        'isCompleted': isCompleted,
        'revision': _iso(result.revision),
        if (result.recurringTaskId != null) 'recurrenceTaskId': result.recurringTaskId,
      };
    });

Future<CallToolResult> _reorder(
        McpTaskActions actions, McpTaskCommitGuard guard, McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      final targetIndex = args.optionalInt('targetIndex');
      if (targetIndex == null) throw _validation('targetIndex', 'is required');
      final result = await actions.reorderTask(
        id: args.requireString('id'),
        expectedRevision: _requiredRevision(args),
        targetIndex: targetIndex,
        beforeId: args.optionalString('beforeId'),
        afterId: args.optionalString('afterId'),
        beforeCommit: () => _guard(guard, extra, const {'tasks:write'}),
      );
      return {'id': result.id, 'order': result.order!, 'revision': _iso(result.revision)};
    });

Future<CallToolResult> _import(
        Mediator mediator, McpTaskCommitGuard guard, McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      if (args.requireString('format') != 'csv') throw _validation('format', 'must be csv');
      final directory = await Directory.systemTemp.createTemp('whph-task-import-');
      final file = File('${directory.path}/tasks.csv');
      try {
        await file.writeAsString(args.requireString('csv'), flush: true);
        final importType = _enum(args.requireString('importType'), TaskImportType.values)!;
        await _guard(guard, extra, const {'tasks:write', 'tags:write', 'data:import'});
        final response = await mediator.send<ImportTasksCommand, ImportTasksCommandResponse>(
          ImportTasksCommand(filePath: file.path, importType: importType),
        );
        return {
          'successCount': response.successCount,
          'failureCount': response.failureCount,
          'errors':
              response.errors.map((error) => error.replaceAll(directory.path, '<import>')).toList(growable: false),
        };
      } finally {
        await directory.delete(recursive: true);
      }
    });

Future<CallToolResult> _timeList(McpTaskActions actions, McpToolArguments args) => _run(() async {
      final records = await actions.listTimeRecords(
        args.requireString('taskId'),
        _optionalInstant(args, 'from'),
        _optionalInstant(args, 'to'),
      );
      return {
        'items': records
            .map((record) => {
                  'id': record.id,
                  'occurredAt': _iso(record.createdDate),
                  'durationSeconds': record.duration,
                })
            .toList(),
        'totalDurationSeconds': records.fold<int>(0, (total, record) => total + record.duration),
      };
    });

Future<CallToolResult> _timeAdd(Mediator mediator, McpTaskActions actions, McpTaskCommitGuard guard,
        McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      final duration = args.optionalInt('durationSeconds');
      if (duration == null || duration <= 0) throw _validation('durationSeconds', 'must be positive');
      final taskId = args.requireString('taskId');
      await actions.ensureTaskExists(taskId);
      await _guard(guard, extra, const {'tasks:write', 'timers:write'});
      final response = await mediator.send<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse>(
        AddTaskTimeRecordCommand(
          taskId: taskId,
          duration: duration,
          customDateTime: _optionalInstant(args, 'occurredAt'),
        ),
      );
      return {'id': response.id};
    });

Future<CallToolResult> _timeUpdate(
  McpTaskActions actions,
  McpTaskCommitGuard guard,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final total = args.optionalInt('totalDurationSeconds');
      if (total == null || total < 0) {
        throw _validation('totalDurationSeconds', 'must be a non-negative integer');
      }
      final result = await actions.updateTimeRecord(
        taskId: args.requireString('taskId'),
        date: _dateOnly(args.requireString('date'), 'date'),
        totalDurationSeconds: total,
        expectedRevision: _requiredRevision(args),
        beforeCommit: () => _guard(guard, extra, const {'tasks:write', 'timers:write'}),
      );
      return {'id': result.id, 'revision': _iso(result.revision)};
    });

Future<CallToolResult> _timeTotal(Mediator mediator, McpToolArguments args) => _run(() async {
      final response = await mediator.send<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse>(
        GetTotalDurationByTaskIdQuery(
          taskId: args.requireString('taskId'),
          startDate: _optionalInstant(args, 'from'),
          endDate: _optionalInstant(args, 'to'),
        ),
      );
      return {'totalDurationSeconds': response.totalDuration};
    });

Future<CallToolResult> _run(Future<Map<String, dynamic>> Function() operation) async {
  try {
    return McpToolResult.success(await operation());
  } on McpToolException catch (error) {
    return McpToolResult.failure(error.error);
  } on McpRevisionConflictException {
    return McpToolResult.failure(McpToolError(code: McpToolErrorCode.conflict, message: 'The record was changed.'));
  } on McpTaskNotFoundException {
    return McpToolResult.failure(McpToolError(code: McpToolErrorCode.notFound, message: 'The record was not found.'));
  } on BusinessException catch (_) {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.validationError, message: 'The request is invalid.'));
  } on ArgumentError catch (_) {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.validationError, message: 'The request is invalid.'));
  } catch (_) {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.operationFailed, message: 'The operation failed.'));
  }
}

Future<void> _guard(McpTaskCommitGuard guard, RequestHandlerExtra extra, Set<String> scopes) async {
  if (!await guard(extra, scopes)) {
    throw McpToolException(McpToolError(
      code: McpToolErrorCode.permissionDenied,
      message: 'The connection is not permitted to use this tool.',
    ));
  }
}

McpToolDefinition _tool(String name, String description, JsonObject input, JsonObject output, Set<String> scopes,
        ToolAnnotations annotations, McpToolHandler handler) =>
    McpToolDefinition(
      name: name,
      description: description,
      inputSchema: input,
      outputSchema: output,
      requiredScopes: scopes,
      annotations: annotations,
      handler: handler,
    );
