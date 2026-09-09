part of 'mcp_settings_sync_tools_test.dart';

void expectHiddenSettingsToBeClosed(String schema) {
  expect(schema, isNot(contains('DEBUG_LOGS_ENABLED')));
  expect(schema, isNot(contains('ONBOARDING_COMPLETED')));
  expect(PublicSettingKey.fromPublicName('MCP_ACCESS_TOKEN'), isNull);
}

Future<void> verifyFailedSettingEffect(
  McpToolDefinition tool,
  DriftSettingRepository repository,
  TestEffects effects,
  String expectedRevision,
) async {
  effects.shouldFail = true;
  final result = await tool.handler(
    McpToolArguments({
      'key': 'themeMode',
      'value': 'auto',
      'expectedRevision': expectedRevision,
    }),
    requestExtra(),
  );
  expect((await repository.getByKey('THEME_MODE'))?.value, 'auto');
  expect(effects.changes.map((change) => change.value), ['dark', 'light']);
  expect(result.structuredContent, containsPair('effectStatus', 'failed'));
  expect(result.structuredContent, containsPair('committed', true));
}

Future<void> verifySyncDelete(
  List<McpToolDefinition> tools,
  DriftSyncDeviceRepository repository,
  TestSyncService service,
  String expectedRevision,
) async {
  final delete =
      tools.singleWhere((tool) => tool.name == 'whph_sync_devices_delete');
  final result = await delete.handler(
    McpToolArguments({'id': 'device-1', 'expectedRevision': expectedRevision}),
    requestExtra(),
  );
  expect(result.structuredContent, containsPair('committed', true));
  expect(await repository.getById('device-1'), isNull);
  expect(service.runCount, 2);
}

Future<void> verifySyncMutations(
  CallToolResult first,
  CallToolResult stale,
  List<McpToolDefinition> tools,
  DriftSyncDeviceRepository repository,
  TestSyncService service,
) async {
  expect(first.isError, isFalse);
  expect(stale.structuredContent!['error'], containsPair('code', 'conflict'));
  expect((await repository.getById('device-1'))?.name, 'First update');
  expect(service.runCount, 1);
  await verifySyncDelete(tools, repository, service,
      first.structuredContent!['revision'] as String);
}

List<McpToolDefinition> syncTools(
        AppDatabase database,
        DriftSyncDeviceRepository repository,
        TestSyncService syncService,
        TestRequestContext context,
        McpOperationService operations) =>
    createSyncTools(
      actions: SyncActions(
        repository: repository,
        transactions: DriftApplicationTransactionService(database),
        syncService: syncService,
        deviceIds: TestDeviceIds(),
        networkInterfaces: TestNetworkInterfaces(),
        handshake: DeviceHandshakeService(),
      ),
      operations: operations,
      requestContext: context,
    );

McpOperationService operationService(Directory directory,
        [TestAccessService? access]) =>
    McpOperationService(
      store: McpOperationStore(
          applicationDirectoryService: TestDirectoryService(directory)),
      accessService: access ?? TestAccessService(),
    );

Future<void> verifyRevokedPairing(
  McpToolDefinition prepare,
  McpOperationService operations,
  TestAccessService access,
  DriftSyncDeviceRepository repository,
  Map<String, dynamic> peer,
) async {
  final request = await prepare.handler(McpToolArguments(peer), requestExtra());
  access.isAllowed = false;
  final cancelled = await operations
      .approve(request.structuredContent!['operationId'] as String);
  access.isAllowed = true;
  expect(cancelled.status, McpOperationStatus.cancelled);
  expect((await repository.getList(0, 20)).items, isEmpty);
}

Future<HttpServer> startHandshakeServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    socket.listen((_) => socket.add(jsonEncode({
          'type': 'device_info_response',
          'data': {
            'success': true,
            'deviceId': 'peer-device',
            'deviceName': 'Test peer',
            'appName': 'WHPH',
            'platform': 'linux'
          }
        })));
  });
  return server;
}

RequestHandlerExtra requestExtra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'settings-sync-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest:
          <T extends BaseResultData>(request, resultFactory, options) async =>
              resultFactory(const {}),
    );

final class TestEffects implements ISettingsEffects {
  final List<PublicSettingChange> changes = [];
  bool shouldFail = false;
  @override
  Future<void> apply(PublicSettingChange change) async {
    if (shouldFail) throw StateError('injected effect failure');
    changes.add(change);
  }
}

final class TestRequestContext implements IMcpRequestContext {
  bool isAllowed = true;
  @override
  Future<bool> isAuthorized(Set<String> requiredScopes) async => isAllowed;
  @override
  Future<T> runOperation<T>(Future<T> Function() operation) => operation();
  @override
  Future<McpAuthenticatedGrant?> currentGrant(
          {Set<String> requiredScopes = const {}}) async =>
      isAllowed
          ? McpAuthenticatedGrant(
              id: 'grant',
              clientName: 'test',
              scopes: const {McpScopes.syncManage})
          : null;
}

final class TestSyncService extends Fake implements ISyncService {
  int startCount = 0;
  int stopCount = 0;
  int runCount = 0;
  bool shouldFailRun = false;
  @override
  SyncStatus get currentSyncStatus => const SyncStatus(state: SyncState.idle);
  @override
  Future<void> startSync() async => startCount++;
  @override
  void stopSync() => stopCount++;
  @override
  Future<void> runSync({bool isManual = false}) async {
    runCount++;
    if (shouldFailRun) throw StateError('injected sync failure');
  }
}

final class TestDeviceIds extends Fake implements IDeviceIdService {
  @override
  Future<String> getDeviceId() async => 'local-device';
}

final class TestNetworkInterfaces extends Fake
    implements INetworkInterfaceService {
  @override
  Future<List<String>> getPreferredIPAddresses() async => const ['127.0.0.1'];
}

final class TestDirectoryService extends Fake
    implements IApplicationDirectoryService {
  TestDirectoryService(this.directory);
  final Directory directory;
  @override
  Future<Directory> getApplicationDirectory() async => directory;
}

final class TestAccessService extends Fake implements IMcpAccessService {
  bool isAllowed = true;

  @override
  Future<McpAccessState> readState() async => McpAccessState(
        preferences: const McpServerPreferences(
            isEnabled: false, port: 44041, transferDirectory: ''),
        grants: isAllowed
            ? [
                McpAccessGrant(
                  id: 'grant',
                  clientName: 'test',
                  tokenDigest: 'digest',
                  scopes: const {McpScopes.syncManage},
                  createdAt: DateTime.utc(2026),
                  rotatedAt: null,
                  revokedAt: null,
                )
              ]
            : const [],
      );
}
