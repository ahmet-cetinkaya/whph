import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/sync/commands/remove_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/rename_sync_member_command.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_member_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/mcp_tools.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/tools/sync_tools.dart';

import '../../infrastructure/shared/features/sync/sync_container_test_support.dart';

const _grantId = 'grant-for-sync-tools';
const _tokenDigest = 'token-digest-that-must-never-reach-sync-tables';
const _memberId = 'member-1';

class _Context implements IMcpRequestContext {
  @override
  Future<bool> isAuthorized(Set<String> requiredScopes) async => true;

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) => operation();

  @override
  Future<McpAuthenticatedGrant?> currentGrant({Set<String> requiredScopes = const {}}) async =>
      McpAuthenticatedGrant(id: _grantId, clientName: 'test', scopes: const {McpScopes.syncManage});
}

class _StatusStore extends Fake implements ISyncPeerStatusStore {
  final Map<String, List<String>> addresses = {};

  @override
  Future<SyncPeerStatus?> read(String memberId) async =>
      SyncPeerStatus(memberId: memberId, addresses: addresses[memberId] ?? const []);

  @override
  Future<void> saveAddresses(String memberId, List<String> values) async => addresses[memberId] = values;
}

class _Handler<TRequest extends IRequest<TResponse>, TResponse> implements IRequestHandler<TRequest, TResponse> {
  _Handler(this._call);

  final Future<TResponse> Function(TRequest request) _call;

  @override
  Future<TResponse> call(TRequest request) => _call(request);
}

RequestHandlerExtra _extra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'sync-tools-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
    );

Future<CallToolResult> _call(List<McpToolDefinition> tools, String name, Map<String, dynamic> arguments) {
  final registry = McpToolRegistry(
    tools: [tools.singleWhere((tool) => tool.name == name)],
    authorize: (extra, scopes) => true,
    runInvocation: (invocation) => invocation(),
  );
  return registry.invoke(name, McpToolArguments(arguments), _extra());
}

void main() {
  group('with a fake member group', () {
    late Map<String, SyncMemberSummary> members;
    late _StatusStore statusStore;
    late List<String> removed;
    late List<McpToolDefinition> tools;

    setUp(() {
      members = {
        _memberId: const SyncMemberSummary(
          memberId: _memberId,
          name: 'Phone',
          platform: 'android',
          lastResult: SyncResultCategory.notReachable,
        ),
      };
      statusStore = _StatusStore();
      removed = [];
      final mediator = Mediator(Pipeline())
        ..registerHandler<GetListSyncMembersQuery, GetListSyncMembersQueryResponse,
            _Handler<GetListSyncMembersQuery, GetListSyncMembersQueryResponse>>(
          () => _Handler((_) async => GetListSyncMembersQueryResponse(members.values.toList())),
        )
        ..registerHandler<GetSyncMemberQuery, SyncMemberSummary?, _Handler<GetSyncMemberQuery, SyncMemberSummary?>>(
          () => _Handler((request) async => members[request.memberId]),
        )
        ..registerHandler<RenameSyncMemberCommand, void, _Handler<RenameSyncMemberCommand, void>>(
          () => _Handler((request) async {
            final current = members[request.memberId]!;
            members[request.memberId] = SyncMemberSummary(
              memberId: current.memberId,
              name: request.name,
              platform: current.platform,
              lastResult: current.lastResult,
            );
          }),
        )
        ..registerHandler<RemoveSyncMemberCommand, void, _Handler<RemoveSyncMemberCommand, void>>(
          () => _Handler((request) async {
            removed.add(request.memberId);
            members.remove(request.memberId);
          }),
        );
      tools = createSyncTools(
        mediator: mediator,
        statusStore: statusStore,
        operations: _NoOperations(),
        requestContext: _Context(),
      );
    });

    Future<String> readRevision() async =>
        (await _call(tools, 'whph_sync_devices_read', {'id': _memberId})).structuredContent!['revision'] as String;

    test('list and read return the member status', () async {
      final list = await _call(tools, 'whph_sync_devices_list', {});
      final read = await _call(tools, 'whph_sync_devices_read', {'id': _memberId});

      expect(list.structuredContent!['total'], 1);
      expect(read.structuredContent, containsPair('status', 'not_reachable'));
      expect(read.structuredContent, containsPair('name', 'Phone'));
      expect(read.structuredContent, containsPair('isThisDevice', false));
    });

    test('read of an unknown member is not found', () async {
      final result = await _call(tools, 'whph_sync_devices_read', {'id': 'missing'});

      expect(result.structuredContent!['error'], containsPair('code', 'not_found'));
    });

    test('update renames and replaces addresses', () async {
      final result = await _call(tools, 'whph_sync_devices_update', {
        'id': _memberId,
        'expectedRevision': await readRevision(),
        'name': 'Tablet',
        'addresses': ['192.168.1.20'],
      });

      expect(result.isError, isNot(true), reason: '${result.structuredContent}');
      expect(result.structuredContent, containsPair('name', 'Tablet'));
      expect(result.structuredContent, containsPair('addresses', ['192.168.1.20']));
    });

    test('update with a stale expectedRevision after a remote apply is rejected', () async {
      final staleRevision = await readRevision();
      members[_memberId] = const SyncMemberSummary(memberId: _memberId, name: 'Renamed by another device');

      final result = await _call(
          tools, 'whph_sync_devices_update', {'id': _memberId, 'expectedRevision': staleRevision, 'name': 'Mine'});

      expect(result.structuredContent!['error'], containsPair('code', 'conflict'));
      expect(members[_memberId]!.name, 'Renamed by another device');
    });

    test('update rejects addresses outside the private network', () async {
      final result = await _call(tools, 'whph_sync_devices_update', {
        'id': _memberId,
        'expectedRevision': await readRevision(),
        'addresses': ['8.8.8.8']
      });

      expect(result.structuredContent!['error'], containsPair('code', 'validation_error'));
    });

    test('delete removes the member from the group; a stale revision is rejected', () async {
      final stale = await _call(tools, 'whph_sync_devices_delete', {'id': _memberId, 'expectedRevision': 'stale'});
      final deleted =
          await _call(tools, 'whph_sync_devices_delete', {'id': _memberId, 'expectedRevision': await readRevision()});

      expect(stale.structuredContent!['error'], containsPair('code', 'conflict'));
      expect(deleted.structuredContent, containsPair('committed', true));
      expect(removed, [_memberId]);
    });
  });

  group('with the real database', () {
    late Directory root;
    late AppDatabase database;
    late List<McpToolDefinition> tools;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('mcp-sync-tools-');
      final container = await buildSyncTestContainer(root);
      database = AppDatabase.instance();
      tools = buildMcpTools(container, _Context());
    });
    tearDown(() => root.delete(recursive: true));

    Future<int> rows(String table) async =>
        (await database.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle()).read<int>('n');

    test('pair_prepare alone creates no member, origin or key handover', () async {
      final before = [for (final table in _syncTables) await rows(table)];

      final result = await _call(tools, 'whph_sync_pair_prepare', {
        'peer': {'ipAddress': '192.168.1.20'},
      });

      expect(result.isError, isNot(true), reason: '${result.structuredContent}');
      expect(result.structuredContent, containsPair('requiresUserConfirmation', true));
      expect(result.structuredContent, containsPair('requiresApproval', true));
      expect([for (final table in _syncTables) await rows(table)], before);
    });

    test('an MCP session leaves no grant id or token digest in the sync tables', () async {
      await _call(tools, 'whph_sync_pair_prepare', {
        'peer': {'ipAddress': '192.168.1.20'},
      });
      await _call(tools, 'whph_sync_devices_list', {});

      for (final table in _syncTables) {
        final dump = await database.customSelect('SELECT * FROM $table').get();
        final text = dump.map((row) => row.data.values.join('|')).join('\n');
        expect(text, isNot(contains(_tokenDigest)), reason: table);
        expect(text, isNot(contains(_grantId)), reason: table);
      }
    });
  });
}

const _syncTables = ['sync_clock', 'sync_member_table', 'sync_origin'];

class _NoOperations extends Fake implements IMcpOperationService {}
