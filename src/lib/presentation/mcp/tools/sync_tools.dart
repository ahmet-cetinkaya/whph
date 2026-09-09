import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/sync_actions.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

part 'sync_tool_contract.dart';
part 'sync_tool_support.dart';

const syncToolNames = <String>{
  'whph_sync_devices_list',
  'whph_sync_devices_read',
  'whph_sync_devices_update',
  'whph_sync_devices_delete',
  'whph_sync_pair_prepare',
  'whph_sync_start',
  'whph_sync_stop',
};

List<McpToolDefinition> createSyncTools({
  required SyncActions actions,
  required IMcpOperationService operations,
  required IMcpRequestContext requestContext,
}) =>
    List.unmodifiable([
      _tool(
          'whph_sync_devices_list',
          'Lists paired sync devices.',
          _listInput,
          _pageOutput,
          const {McpScopes.syncRead},
          _read, (arguments, extra) async {
        final pageSize = arguments.optionalInt('pageSize') ?? 50;
        final pageIndex = _pageIndex(arguments.optionalString('cursor'));
        if (pageSize < 1 || pageSize > 200)
          return _validation(
              'pageSize', 'Page size must be from 1 through 200.');
        final page =
            await actions.list(pageIndex: pageIndex, pageSize: pageSize);
        return McpToolResult.success({
          'items': page.items
              .map((device) => _deviceJson(device, actions.status))
              .toList(growable: false),
          'total': page.total,
          if (page.nextCursor != null) 'nextCursor': page.nextCursor,
        });
      }),
      _tool(
          'whph_sync_devices_read',
          'Reads one paired sync device.',
          _idInput,
          _deviceOutput,
          const {McpScopes.syncRead},
          _read, (arguments, extra) async {
        final device = await actions.read(arguments.requireString('id'));
        if (device == null)
          return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
        return McpToolResult.success(_deviceJson(device, actions.status));
      }),
      _tool(
          'whph_sync_devices_update',
          'Updates a paired device using its current revision.',
          _updateInput,
          _deviceMutationOutput,
          const {McpScopes.syncManage},
          _mutation, (arguments, extra) async {
        if (!const {'name', 'fromIp', 'toIp'}.any(arguments.contains)) {
          return _validation('id', 'At least one editable field is required.');
        }
        final fromIp = _ipUpdate(arguments, 'fromIp');
        final toIp = _ipUpdate(arguments, 'toIp');
        try {
          final updated = await actions.update(
            SyncDeviceUpdate(
              id: arguments.requireString('id'),
              expectedRevision: _revision(arguments, 'expectedRevision'),
              name: arguments.contains('name')
                  ? ReplaceField(arguments.optionalString('name'))
                  : const PreserveField(),
              fromIp: fromIp,
              toIp: toIp,
            ),
            () => _requireAuthorized(
                requestContext, extra, const {McpScopes.syncManage}),
          );
          return McpToolResult.success({
            ..._deviceJson(updated.value, actions.status),
            'committed': true,
            'syncStatus': updated.syncSucceeded ? 'succeeded' : 'failed',
          });
        } on SyncRevisionConflictException {
          return _failure(McpToolErrorCode.conflict,
              'The sync device changed after it was read.');
        } on StateError {
          return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
        }
      }),
      _tool(
          'whph_sync_devices_delete',
          'Deletes a paired sync device using its current revision.',
          _deleteInput,
          _deleteOutput,
          const {McpScopes.syncManage},
          _delete, (arguments, extra) async {
        try {
          final deletedAt = await actions.delete(
            arguments.requireString('id'),
            _revision(arguments, 'expectedRevision'),
            () => _requireAuthorized(
                requestContext, extra, const {McpScopes.syncManage}),
          );
          return McpToolResult.success({
            'id': arguments.requireString('id'),
            'deletedAt': deletedAt.value.toUtc().toIso8601String(),
            'committed': true,
            'syncStatus': deletedAt.syncSucceeded ? 'succeeded' : 'failed',
          });
        } on SyncRevisionConflictException {
          return _failure(McpToolErrorCode.conflict,
              'The sync device changed after it was read.');
        } on StateError {
          return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
        }
      }),
      _tool(
          'whph_sync_pair_prepare',
          'Prepares a local-user-approved WHPH device pairing.',
          _pairInput,
          _operationOutput,
          const {McpScopes.syncManage},
          _additive, (arguments, extra) async {
        final peer = _peer(arguments.optionalObject('peer'));
        extra.signal.throwIfAborted();
        final grant = await requestContext
            .currentGrant(requiredScopes: const {McpScopes.syncManage});
        if (grant == null)
          return _failure(McpToolErrorCode.permissionDenied,
              'The connection is not permitted to pair devices.');
        final normalized = <String, Object>{
          'deviceId': peer.deviceId,
          'ipAddress': peer.ipAddress,
          'name': peer.name,
          'port': peer.port,
        };
        final operation = await operations.prepare(
          clientGrantId: grant.id,
          type: McpOperationType.syncPair,
          requiredScopes: const {McpScopes.syncManage},
          requestHash:
              sha256.convert(utf8.encode(jsonEncode(normalized))).toString(),
          summary: 'Pair with ${peer.name} (${peer.ipAddress}:${peer.port})',
          execute: () async {
            final paired = await actions.pair(peer);
            return McpOperationResult({
              'deviceId': paired.value.id,
              'status': paired.syncSucceeded ? 'paired' : 'paired_sync_failed',
            });
          },
        );
        return McpToolResult.success(_operationJson(operation, peer));
      }),
      _tool(
          'whph_sync_start',
          'Starts the configured WHPH sync service.',
          _emptyInput,
          _statusOutput,
          const {McpScopes.syncManage},
          _mutation, (arguments, extra) async {
        await _requireAuthorized(
            requestContext, extra, const {McpScopes.syncManage});
        return McpToolResult.success(_statusJson(await actions.start()));
      }),
      _tool(
          'whph_sync_stop',
          'Stops the configured WHPH sync service.',
          _emptyInput,
          _statusOutput,
          const {McpScopes.syncManage},
          _mutation, (arguments, extra) async {
        await _requireAuthorized(
            requestContext, extra, const {McpScopes.syncManage});
        return McpToolResult.success(_statusJson(actions.stop()));
      }),
    ]);

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
