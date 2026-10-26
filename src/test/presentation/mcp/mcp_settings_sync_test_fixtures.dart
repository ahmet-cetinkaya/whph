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

McpOperationService operationService(Directory directory, [TestAccessService? access]) => McpOperationService(
      store: McpOperationStore(applicationDirectoryService: TestDirectoryService(directory)),
      accessService: access ?? TestAccessService(),
    );

RequestHandlerExtra requestExtra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'settings-sync-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
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
  Future<McpAuthenticatedGrant?> currentGrant({Set<String> requiredScopes = const {}}) async =>
      isAllowed ? McpAuthenticatedGrant(id: 'grant', clientName: 'test', scopes: const {McpScopes.syncManage}) : null;
}

final class TestDirectoryService extends Fake implements IApplicationDirectoryService {
  TestDirectoryService(this.directory);
  final Directory directory;
  @override
  Future<Directory> getApplicationDirectory() async => directory;
}

final class TestAccessService extends Fake implements IMcpAccessService {
  bool isAllowed = true;

  @override
  Future<McpAccessState> readState() async => McpAccessState(
        preferences: const McpServerPreferences(isEnabled: false, port: 44041, transferDirectory: ''),
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
