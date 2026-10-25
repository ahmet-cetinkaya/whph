import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/sync/commands/remove_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/rename_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/start_pairing_with_address_command.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_member_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
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

const _defaultPageSize = 50;
const _maxPageSize = 200;

List<McpToolDefinition> createSyncTools({
  required Mediator mediator,
  required ISyncPeerStatusStore statusStore,
  required IMcpOperationService operations,
  required IMcpRequestContext requestContext,
}) {
  Future<Map<String, dynamic>> memberJson(SyncMemberSummary member) async =>
      _memberJson(member, (await statusStore.read(member.memberId))?.addresses ?? const []);

  Future<SyncMemberSummary?> readMember(String id) async =>
      (await mediator.send<GetSyncMemberQuery, SyncMemberSummary?>(GetSyncMemberQuery(memberId: id)));

  /// Rejects the write when the member changed after the caller read it.
  Future<CallToolResult?> rejectUnlessCurrent(McpToolArguments arguments, SyncMemberSummary? member) async {
    if (member == null) return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
    final current = (await memberJson(member))['revision'];
    if (current == arguments.requireString('expectedRevision')) return null;
    return _failure(McpToolErrorCode.conflict, 'The sync device changed after it was read.');
  }

  return List.unmodifiable([
    _tool(
      'whph_sync_devices_list',
      'Lists devices of the sync group with their sync status.',
      _listInput,
      _pageOutput,
      const {McpScopes.syncRead},
      _read,
      (arguments, extra) async {
        final pageSize = arguments.optionalInt('pageSize') ?? _defaultPageSize;
        final pageIndex = _pageIndex(arguments.optionalString('cursor'));
        if (pageSize < 1 || pageSize > _maxPageSize) {
          return _validation('pageSize', 'Page size must be from 1 through $_maxPageSize.');
        }
        final response = await mediator.send<GetListSyncMembersQuery, GetListSyncMembersQueryResponse>(
          GetListSyncMembersQuery(),
        );
        final start = pageIndex * pageSize;
        final page = response.members.skip(start).take(pageSize).toList(growable: false);
        return McpToolResult.success({
          'items': [for (final member in page) await memberJson(member)],
          'total': response.members.length,
          if (start + pageSize < response.members.length) 'nextCursor': '${pageIndex + 1}',
        });
      },
    ),
    _tool(
      'whph_sync_devices_read',
      'Reads one device of the sync group with its sync status.',
      _idInput,
      _memberOutput,
      const {McpScopes.syncRead},
      _read,
      (arguments, extra) async {
        final member = await readMember(arguments.requireString('id'));
        if (member == null) return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
        return McpToolResult.success(await memberJson(member));
      },
    ),
    _tool(
      'whph_sync_devices_update',
      'Renames a device or changes its addresses using its current revision.',
      _updateInput,
      _memberMutationOutput,
      const {McpScopes.syncManage},
      _mutation,
      (arguments, extra) async {
        if (!arguments.contains('name') && !arguments.contains('addresses')) {
          return _validation('id', 'At least one editable field is required.');
        }
        final id = arguments.requireString('id');
        final addresses = arguments.contains('addresses') ? _addressesOf(arguments) : null;
        final stale = await rejectUnlessCurrent(arguments, await readMember(id));
        if (stale != null) return stale;
        await _requireAuthorized(requestContext, extra, const {McpScopes.syncManage});
        try {
          if (arguments.contains('name')) {
            await mediator.send<RenameSyncMemberCommand, void>(
              RenameSyncMemberCommand(memberId: id, name: arguments.requireString('name')),
            );
          }
        } on SyncMembershipException catch (error) {
          return _validation('name', error.message);
        }
        if (addresses != null) await statusStore.saveAddresses(id, addresses);
        final updated = await readMember(id);
        if (updated == null) return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
        return McpToolResult.success({...await memberJson(updated), 'committed': true});
      },
    ),
    _tool(
      'whph_sync_devices_delete',
      'Removes a device from the sync group for every member, with a key rotation, using its current revision.',
      _deleteInput,
      _deleteOutput,
      const {McpScopes.syncManage},
      _delete,
      (arguments, extra) async {
        final id = arguments.requireString('id');
        final stale = await rejectUnlessCurrent(arguments, await readMember(id));
        if (stale != null) return stale;
        await _requireAuthorized(requestContext, extra, const {McpScopes.syncManage});
        try {
          await mediator.send<RemoveSyncMemberCommand, void>(RemoveSyncMemberCommand(memberId: id));
        } on ArgumentError {
          return _failure(McpToolErrorCode.notFound, 'Sync device not found.');
        } on StateError {
          return _failure(McpToolErrorCode.conflict, 'This device is not in a sync group.');
        }
        return McpToolResult.success({'id': id, 'committed': true});
      },
    ),
    _tool(
      'whph_sync_pair_prepare',
      'Prepares pairing with a WHPH device. Nothing is paired until the user approves it in the app and '
          'confirms the same code on both devices.',
      _pairInput,
      _operationOutput,
      const {McpScopes.syncManage},
      _additive,
      (arguments, extra) async {
        final peer = _peerAddress(arguments.optionalObject('peer'));
        extra.signal.throwIfAborted();
        final grant = await requestContext.currentGrant(requiredScopes: const {McpScopes.syncManage});
        if (grant == null) {
          return _failure(McpToolErrorCode.permissionDenied, 'The connection is not permitted to pair devices.');
        }
        final summary = 'Pair with the device at ${peer.address}:${peer.port}';
        final operation = await operations.prepare(
          clientGrantId: grant.id,
          type: McpOperationType.syncPair,
          requiredScopes: const {McpScopes.syncManage},
          requestHash: sha256.convert(utf8.encode(jsonEncode([peer.address, peer.port]))).toString(),
          summary: summary,
          execute: () async {
            final status = await mediator.send<StartPairingWithAddressCommand, SyncPairingStatus>(
              StartPairingWithAddressCommand(address: peer.address, port: peer.port),
            );
            return McpOperationResult({
              'status': status.phase.name,
              'requiresUserConfirmation': true,
              if (status.errorCode != null) 'error': status.errorCode,
            });
          },
        );
        return McpToolResult.success({
          'operationId': operation.id,
          'status': operation.status.name,
          'requiresApproval': true,
          'expiresAt': operation.approvalExpiresAt.toUtc().toIso8601String(),
          'peerSummary': summary,
          'requiresUserConfirmation': true,
        });
      },
    ),
    _tool(
      'whph_sync_start',
      'Starts the sync server and periodic sync.',
      _emptyInput,
      _runningOutput,
      const {McpScopes.syncManage},
      _mutation,
      (arguments, extra) async {
        await _requireAuthorized(requestContext, extra, const {McpScopes.syncManage});
        await mediator.send<StartSyncCommand, void>(StartSyncCommand());
        return McpToolResult.success({'running': true});
      },
    ),
    _tool(
      'whph_sync_stop',
      'Stops the sync server and periodic sync.',
      _emptyInput,
      _runningOutput,
      const {McpScopes.syncManage},
      _mutation,
      (arguments, extra) async {
        await _requireAuthorized(requestContext, extra, const {McpScopes.syncManage});
        await mediator.send<StopSyncCommand, StopSyncCommandResponse>(StopSyncCommand());
        return McpToolResult.success({'running': false});
      },
    ),
  ]);
}

McpToolDefinition _tool(
  String name,
  String description,
  JsonObject input,
  JsonObject output,
  Set<String> scopes,
  ToolAnnotations annotations,
  McpToolHandler handler,
) => McpToolDefinition(
  name: name,
  description: description,
  inputSchema: input,
  outputSchema: output,
  annotations: annotations,
  requiredScopes: scopes,
  handler: handler,
);
