import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_status_query.dart';
import 'package:whph/core/application/features/tasks/services/mcp_task_actions.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';
import 'package:whph/presentation/mcp/tools/task_tools.dart'
    show McpTaskCommitGuard;

List<McpToolDefinition> buildTaskStatusTools({
  required Mediator mediator,
  required McpTaskActions actions,
  required McpTaskCommitGuard authorizeBeforeCommit,
}) =>
    List.unmodifiable([
      _tool(
          'whph_task_statuses_list',
          'List task statuses in their display order.',
          _listInput,
          _pageOutput,
          const {'tasks:read'},
          _read,
          (args, extra) => _list(mediator, args)),
      _tool(
          'whph_task_statuses_read',
          'Read one task status and its revision.',
          _idInput,
          _statusOutput,
          const {'tasks:read'},
          _read,
          (args, extra) => _readStatus(mediator, args)),
      _tool(
          'whph_task_statuses_create',
          'Create a task status.',
          _createInput,
          _idRevisionOutput,
          const {'tasks:write'},
          _additive,
          (args, extra) =>
              _create(actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_task_statuses_update',
          'Update only supplied task status fields.',
          _updateInput,
          _idRevisionOutput,
          const {'tasks:write'},
          _mutation,
          (args, extra) =>
              _update(actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_task_statuses_delete',
          'Delete a non-built-in task status.',
          _revisionInput,
          _deleteOutput,
          const {'tasks:delete'},
          _destructive,
          (args, extra) =>
              _delete(actions, authorizeBeforeCommit, args, extra)),
      _tool(
          'whph_task_statuses_reorder',
          'Set task status ranks atomically.',
          _reorderInput,
          _countOutput,
          const {'tasks:write'},
          _mutation,
          (args, extra) =>
              _reorder(actions, authorizeBeforeCommit, args, extra)),
    ]);

Future<CallToolResult> _list(Mediator mediator, McpToolArguments args) =>
    _run(() async {
      final pageSize = args.optionalInt('pageSize') ?? 50;
      final pageIndex = int.tryParse(args.optionalString('cursor') ?? '0') ?? 0;
      final response = await mediator
          .send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
        GetListTaskStatusesQuery(
          pageIndex: pageIndex,
          pageSize: pageSize,
          includeDeleted: args.optionalBool('includeDeleted') ?? false,
        ),
      );
      return {
        'items': response.items
            .map((status) => {
                  'id': status.id,
                  'name': status.name,
                  'color': status.color,
                  'order': status.order,
                  'isBuiltIn': status.isBuiltIn,
                  'isDoneStatus': status.isDoneStatus,
                })
            .toList(),
        'totalCount': response.totalItemCount,
        'nextCursor': (pageIndex + 1) * pageSize < response.totalItemCount
            ? '${pageIndex + 1}'
            : null,
      };
    });

Future<CallToolResult> _readStatus(Mediator mediator, McpToolArguments args) =>
    _run(() async {
      final status =
          await mediator.send<GetTaskStatusQuery, GetTaskStatusQueryResponse>(
        GetTaskStatusQuery(id: args.requireString('id')),
      );
      return {
        'id': status.id,
        'name': status.name,
        'color': status.color,
        'order': status.order,
        'isBuiltIn': status.isBuiltIn,
        'isDoneStatus': status.isDoneStatus,
        'revision': _iso(status.isBuiltIn && status.modifiedDate == null
            ? McpTaskActions.virtualStatusRevision
            : status.modifiedDate ?? status.createdDate),
      };
    });

Future<CallToolResult> _create(McpTaskActions actions, McpTaskCommitGuard guard,
        McpToolArguments args, RequestHandlerExtra extra) =>
    _run(() async {
      final persisted = await actions.createStatus(
        name: args.requireString('name'),
        color: args.optionalString('color'),
        beforeCommit: () => _guard(guard, extra, const {'tasks:write'}),
      );
      return {
        'id': persisted.id,
        'revision': _iso(persisted.modifiedDate ?? persisted.createdDate)
      };
    });

Future<CallToolResult> _update(
  McpTaskActions actions,
  McpTaskCommitGuard guard,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final values = <String, Object?>{};
      if (args.contains('name')) values['name'] = args.optionalString('name');
      if (args.contains('color'))
        values['color'] = args.optionalString('color');
      final status = await actions.updateStatus(
        id: args.requireString('id'),
        expectedRevision: _revision(args),
        patch: McpTaskPatch(Map.unmodifiable(values)),
        beforeCommit: () => _guard(guard, extra, const {'tasks:write'}),
      );
      return {
        'id': status.id,
        'revision': _iso(status.modifiedDate ?? status.createdDate)
      };
    });

Future<CallToolResult> _delete(
  McpTaskActions actions,
  McpTaskCommitGuard guard,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final deletedAt = await actions.deleteStatus(
        id: args.requireString('id'),
        expectedRevision: _revision(args),
        beforeCommit: () => _guard(guard, extra, const {'tasks:delete'}),
      );
      return {'id': args.requireString('id'), 'deletedAt': _iso(deletedAt)};
    });

Future<CallToolResult> _reorder(
  McpTaskActions actions,
  McpTaskCommitGuard guard,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final raw = args.optionalList('statuses');
      if (raw == null) throw _validation('statuses');
      final changes = raw.map((entry) {
        if (entry is! Map<String, dynamic>) throw _validation('statuses');
        final id = entry['id'];
        final revision = entry['expectedRevision'];
        final order = entry['order'];
        if (id is! String || revision is! String || order is! String)
          throw _validation('statuses');
        return (id: id, revision: _parseRevision(revision), order: order);
      }).toList(growable: false);
      final count = await actions.reorderStatuses(
        changes: changes,
        beforeCommit: () => _guard(guard, extra, const {'tasks:write'}),
      );
      return {'count': count};
    });

Future<CallToolResult> _run(
    Future<Map<String, dynamic>> Function() operation) async {
  try {
    return McpToolResult.success(await operation());
  } on McpToolException catch (error) {
    return McpToolResult.failure(error.error);
  } on McpRevisionConflictException {
    return McpToolResult.failure(McpToolError(
        code: McpToolErrorCode.conflict, message: 'The record was changed.'));
  } on McpTaskNotFoundException {
    return McpToolResult.failure(McpToolError(
        code: McpToolErrorCode.notFound, message: 'The record was not found.'));
  } on ArgumentError {
    return McpToolResult.failure(McpToolError(
        code: McpToolErrorCode.validationError,
        message: 'The request is invalid.'));
  } catch (_) {
    return McpToolResult.failure(McpToolError(
        code: McpToolErrorCode.operationFailed,
        message: 'The operation failed.'));
  }
}

Future<void> _guard(McpTaskCommitGuard guard, RequestHandlerExtra extra,
    Set<String> scopes) async {
  if (!await guard(extra, scopes)) {
    throw McpToolException(McpToolError(
      code: McpToolErrorCode.permissionDenied,
      message: 'The connection is not permitted to use this tool.',
    ));
  }
}

DateTime _revision(McpToolArguments args) =>
    _parseRevision(args.requireString('expectedRevision'));
DateTime _parseRevision(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value))
    throw _validation('expectedRevision');
  return parsed.toUtc();
}

String _iso(DateTime value) => value.toUtc().toIso8601String();
McpToolException _validation(String field) => McpToolException(McpToolError(
      code: McpToolErrorCode.validationError,
      message: 'Argument "$field" is invalid.',
      details: {'field': field},
    ));

McpToolDefinition _tool(
        String name,
        String description,
        JsonObject input,
        JsonObject output,
        Set<String> scopes,
        ToolAnnotations annotations,
        McpToolHandler handler) =>
    McpToolDefinition(
        name: name,
        description: description,
        inputSchema: input,
        outputSchema: output,
        annotations: annotations,
        requiredScopes: scopes,
        handler: handler);

const _read = ToolAnnotations(
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false);
const _additive = ToolAnnotations(
    destructiveHint: false, idempotentHint: false, openWorldHint: false);
const _mutation = ToolAnnotations(
    destructiveHint: true, idempotentHint: true, openWorldHint: false);
const _destructive = ToolAnnotations(
    destructiveHint: true, idempotentHint: false, openWorldHint: false);
JsonObject _closed(Map<String, JsonSchema> properties,
        [List<String>? required]) =>
    JsonSchema.object(
        properties: properties,
        required: required,
        additionalProperties: false);
final _instant = JsonSchema.string(format: 'date-time');
final _nullableString =
    JsonSchema.anyOf([JsonSchema.string(), JsonSchema.nullValue()]);
final _statusFields = <String, JsonSchema>{
  'id': JsonSchema.string(),
  'name': JsonSchema.string(),
  'color': _nullableString,
  'order': JsonSchema.string(),
  'isBuiltIn': JsonSchema.boolean(),
  'isDoneStatus': JsonSchema.boolean(),
};
final _statusSummary = _closed(_statusFields);
final _statusOutput = _closed({..._statusFields, 'revision': _instant});
final _listInput = _closed({
  'cursor': JsonSchema.string(pattern: r'^\d+$'),
  'pageSize': JsonSchema.integer(minimum: 1, maximum: 200),
  'includeDeleted': JsonSchema.boolean()
});
final _pageOutput = _closed({
  'items': JsonSchema.array(items: _statusSummary),
  'totalCount': JsonSchema.integer(),
  'nextCursor': _nullableString
}, [
  'items',
  'totalCount',
  'nextCursor'
]);
final _idInput = _closed({'id': JsonSchema.string()}, ['id']);
final _createInput = _closed({
  'name': JsonSchema.string(minLength: 1, maxLength: 50),
  'color': JsonSchema.string(pattern: r'^[0-9A-Fa-f]{6}$')
}, [
  'name'
]);
final _updateInput = _closed({
  'id': JsonSchema.string(),
  'expectedRevision': _instant,
  'name': JsonSchema.string(maxLength: 50),
  'color': _nullableString
}, [
  'id',
  'expectedRevision'
]);
final _revisionInput = _closed(
    {'id': JsonSchema.string(), 'expectedRevision': _instant},
    ['id', 'expectedRevision']);
final _idRevisionOutput = _closed(
    {'id': JsonSchema.string(), 'revision': _instant}, ['id', 'revision']);
final _deleteOutput = _closed(
    {'id': JsonSchema.string(), 'deletedAt': _instant}, ['id', 'deletedAt']);
final _orderEntry = _closed({
  'id': JsonSchema.string(),
  'expectedRevision': _instant,
  'order': JsonSchema.string()
}, [
  'id',
  'expectedRevision',
  'order'
]);
final _reorderInput = _closed(
    {'statuses': JsonSchema.array(items: _orderEntry, uniqueItems: true)},
    ['statuses']);
final _countOutput = _closed({'count': JsonSchema.integer()}, ['count']);
