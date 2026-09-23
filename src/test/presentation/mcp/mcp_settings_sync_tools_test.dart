import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/settings/models/public_setting.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_settings_effects.dart';
import 'package:whph/core/application/features/settings/services/settings_actions.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/application/features/sync/services/sync_actions.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_device_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_store.dart';
import 'package:whph/main.mapper.g.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/tools/settings_tools.dart';
import 'package:whph/presentation/mcp/tools/sync_tools.dart';

part 'mcp_settings_sync_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeJsonMapper();
  late Directory temporaryDirectory;
  late AppDatabase database;
  late DriftSettingRepository settingsRepository;
  late DriftSyncDeviceRepository syncRepository;
  late TestEffects effects;
  late TestRequestContext requestContext;
  late TestSyncService syncService;

  setUp(() async {
    AppDatabase.isTestMode = true;
    temporaryDirectory =
        await Directory.systemTemp.createTemp('whph-mcp-settings-sync-');
    database = AppDatabase(
        NativeDatabase(File('${temporaryDirectory.path}/test.sqlite')));
    settingsRepository = DriftSettingRepository.withDatabase(database);
    syncRepository = DriftSyncDeviceRepository.withDatabase(database);
    effects = TestEffects();
    requestContext = TestRequestContext();
    syncService = TestSyncService();
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
    AppDatabase.isTestMode = false;
  });

  test(
      'setting update persists in SQLite, applies once, and rejects stale revisions',
      () async {
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tool = createSettingsTools(
            actions: actions, requestContext: requestContext)
        .singleWhere((definition) => definition.name == 'whph_settings_update');

    final created = await tool.handler(
      McpToolArguments(const {'key': 'themeMode', 'value': 'dark'}),
      requestExtra(),
    );
    final firstRevision = created.structuredContent!['revision'] as String;
    final updated = await tool.handler(
      McpToolArguments({
        'key': 'themeMode',
        'value': 'light',
        'expectedRevision': firstRevision
      }),
      requestExtra(),
    );
    final secondRevision = updated.structuredContent!['revision'] as String;
    final stale = await tool.handler(
      McpToolArguments({
        'key': 'themeMode',
        'value': 'auto',
        'expectedRevision': firstRevision
      }),
      requestExtra(),
    );
    await verifyFailedSettingEffect(
        tool, settingsRepository, effects, secondRevision);

    expect(updated.isError, isFalse);
    expect(stale.structuredContent!['error'], containsPair('code', 'conflict'));
  });

  test(
      'hidden setting keys are absent from schema and direct reads fail closed',
      () async {
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tools =
        createSettingsTools(actions: actions, requestContext: requestContext);
    final updateSchema = tools
        .singleWhere((tool) => tool.name == 'whph_settings_update')
        .inputSchema
        .toJson();
    final encodedSchema = jsonEncode(updateSchema);

    expectHiddenSettingsToBeClosed(encodedSchema);
  });

  test('settings update input schema is portable across MCP clients',
      () async {
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tools =
        createSettingsTools(actions: actions, requestContext: requestContext);
    final schema = tools
        .singleWhere((tool) => tool.name == 'whph_settings_update')
        .inputSchema
        .toJson();
    final encodedSchema = jsonEncode(schema);

    // Some clients (Claude Code) ignore const in preflight validation, so a
    // top-level oneOf discriminated by key.const rejects shared value types.
    expect(encodedSchema, isNot(contains('"const"')));
    expect(schema.containsKey('oneOf'), isFalse);

    final valueSchema = schema['properties']!['value'] as Map<String, dynamic>;
    final branches = valueSchema['anyOf'] as List;
    final encodedBranches =
        branches.map((branch) => jsonEncode(branch)).toList();
    expect(encodedBranches, contains(contains('"type":"boolean"')));
    expect(encodedBranches.any((b) => b.contains('"type":"integer"')), isTrue);
    expect(encodedBranches.any((b) => b.contains('"enum"')), isTrue);

    final keyEnum =
        (schema['properties']!['key'] as Map<String, dynamic>)['enum']
            as List;
    expect(keyEnum,
        equals(PublicSettingKey.values.map((k) => k.publicName).toList()));

    expectHiddenSettingsToBeClosed(encodedSchema);
  });

  test('reminder setting uses its typed enum and rejects invalid values',
      () async {
    final update = createSettingsTools(
      actions: SettingsActions(
        repository: settingsRepository,
        transactions: DriftApplicationTransactionService(database),
        effects: effects,
      ),
      requestContext: requestContext,
    ).singleWhere((tool) => tool.name == 'whph_settings_update');

    final accepted = await update.handler(
        McpToolArguments(const {
          'key': 'taskDefaultPlannedReminder',
          'value': 'fifteenMinutesBefore'
        }),
        requestExtra());
    final rejected = await update.handler(
        McpToolArguments(
            const {'key': 'taskDefaultPlannedReminder', 'value': 'whenever'}),
        requestExtra());

    expect(accepted.isError, isFalse);
    expect(rejected.structuredContent!['error'],
        containsPair('code', 'validation_error'));
    expect(effects.changes.single.value, 'fifteenMinutesBefore');
  });

  test(
      'authorization revoked inside the transaction prevents a setting write and effect',
      () async {
    requestContext.isAllowed = false;
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tool = createSettingsTools(
            actions: actions, requestContext: requestContext)
        .singleWhere((definition) => definition.name == 'whph_settings_update');

    await expectLater(
      tool.handler(
          McpToolArguments(
              const {'key': 'notificationsEnabled', 'value': false}),
          requestExtra()),
      throwsA(isA<Exception>()),
    );
    expect(await settingsRepository.getByKey('NOTIFICATIONS_ENABLED'), isNull);
    expect(effects.changes, isEmpty);
  });

  test('sync start and stop use the configured ISyncService instance',
      () async {
    final tools = syncTools(database, syncRepository, syncService,
        requestContext, operationService(temporaryDirectory));

    await tools
        .singleWhere((tool) => tool.name == 'whph_sync_start')
        .handler(McpToolArguments(const {}), requestExtra());
    await tools
        .singleWhere((tool) => tool.name == 'whph_sync_stop')
        .handler(McpToolArguments(const {}), requestExtra());

    expect(syncService.startCount, 1);
    expect(syncService.stopCount, 1);
  });

  test('sync update rejects a stale revision without overwriting SQLite',
      () async {
    final device = SyncDevice(
      id: 'device-1',
      createdDate: DateTime.utc(2026, 1, 1),
      fromIp: '127.0.0.1',
      toIp: '192.168.1.2',
      fromDeviceId: 'peer',
      toDeviceId: 'local',
      name: 'Original',
    );
    await syncRepository.add(device);
    final persisted = await syncRepository.getById(device.id);
    final firstRevision = persisted!.modifiedDate ?? persisted.createdDate;
    final tools = syncTools(database, syncRepository, syncService,
        requestContext, operationService(temporaryDirectory));
    final update =
        tools.singleWhere((tool) => tool.name == 'whph_sync_devices_update');
    final first = await update.handler(
      McpToolArguments({
        'id': 'device-1',
        'expectedRevision': firstRevision.toIso8601String(),
        'name': 'First update',
      }),
      requestExtra(),
    );
    final stale = await update.handler(
      McpToolArguments({
        'id': 'device-1',
        'expectedRevision': firstRevision.toIso8601String(),
        'name': 'Stale update',
      }),
      requestExtra(),
    );

    await verifySyncMutations(first, stale, tools, syncRepository, syncService);
  });

  test(
      'local approval rejects without pairing and approved pairing executes once',
      () async {
    final server = await startHandshakeServer();
    addTearDown(server.close);
    final access = TestAccessService();
    final operations = operationService(temporaryDirectory, access);
    final tools = syncTools(
        database, syncRepository, syncService, requestContext, operations);
    final prepare =
        tools.singleWhere((tool) => tool.name == 'whph_sync_pair_prepare');
    final peer = {
      'peer': {
        'deviceId': 'peer-device',
        'name': 'Test peer',
        'ipAddress': '127.0.0.1',
        'port': server.port
      }
    };
    final rejectedRequest =
        await prepare.handler(McpToolArguments(peer), requestExtra());
    await operations
        .reject(rejectedRequest.structuredContent!['operationId'] as String);
    expect((await syncRepository.getList(0, 20)).items, isEmpty);
    await verifyRevokedPairing(
        prepare, operations, access, syncRepository, peer);

    final approvedRequest =
        await prepare.handler(McpToolArguments(peer), requestExtra());
    syncService.shouldFailRun = true;
    final approved = await operations
        .approve(approvedRequest.structuredContent!['operationId'] as String);
    await expectLater(() => operations.approve(approved.id), throwsStateError);

    expect(approved.status, McpOperationStatus.succeeded);
    expect(
        approved.result?.value, containsPair('status', 'paired_sync_failed'));
    expect((await syncRepository.getList(0, 20)).items.single.fromDeviceId,
        'peer-device');
    expect(syncService.runCount, 1);
  });
}
