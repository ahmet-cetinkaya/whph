import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/settings/models/public_setting.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_settings_effects.dart';
import 'package:whph/core/application/features/settings/services/settings_actions.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_store.dart';
import 'package:whph/main.mapper.g.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/tools/settings_tools.dart';

part 'mcp_settings_sync_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeJsonMapper();
  late Directory temporaryDirectory;
  late AppDatabase database;
  late DriftSettingRepository settingsRepository;
  late TestEffects effects;
  late TestRequestContext requestContext;

  setUp(() async {
    AppDatabase.isTestMode = true;
    temporaryDirectory = await Directory.systemTemp.createTemp('whph-mcp-settings-sync-');
    database = AppDatabase(NativeDatabase(File('${temporaryDirectory.path}/test.sqlite')));
    settingsRepository = DriftSettingRepository.withDatabase(database);
    effects = TestEffects();
    requestContext = TestRequestContext();
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
    AppDatabase.isTestMode = false;
  });

  test('setting update persists in SQLite, applies once, and rejects stale revisions', () async {
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tool = createSettingsTools(actions: actions, requestContext: requestContext)
        .singleWhere((definition) => definition.name == 'whph_settings_update');

    final created = await tool.handler(
      McpToolArguments(const {'key': 'themeMode', 'value': 'dark'}),
      requestExtra(),
    );
    final firstRevision = created.structuredContent!['revision'] as String;
    final updated = await tool.handler(
      McpToolArguments({'key': 'themeMode', 'value': 'light', 'expectedRevision': firstRevision}),
      requestExtra(),
    );
    final secondRevision = updated.structuredContent!['revision'] as String;
    final stale = await tool.handler(
      McpToolArguments({'key': 'themeMode', 'value': 'auto', 'expectedRevision': firstRevision}),
      requestExtra(),
    );
    await verifyFailedSettingEffect(tool, settingsRepository, effects, secondRevision);

    expect(updated.isError, isFalse);
    expect(stale.structuredContent!['error'], containsPair('code', 'conflict'));
  });

  test('hidden setting keys are absent from schema and direct reads fail closed', () async {
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tools = createSettingsTools(actions: actions, requestContext: requestContext);
    final updateSchema = tools.singleWhere((tool) => tool.name == 'whph_settings_update').inputSchema.toJson();
    final encodedSchema = jsonEncode(updateSchema);

    expectHiddenSettingsToBeClosed(encodedSchema);
  });

  test('settings update input schema is portable across MCP clients', () async {
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tools = createSettingsTools(actions: actions, requestContext: requestContext);
    final schema = tools.singleWhere((tool) => tool.name == 'whph_settings_update').inputSchema.toJson();
    final encodedSchema = jsonEncode(schema);

    // Some clients (Claude Code) ignore const in preflight validation, so a
    // top-level oneOf discriminated by key.const rejects shared value types.
    expect(encodedSchema, isNot(contains('"const"')));
    expect(schema.containsKey('oneOf'), isFalse);

    final valueSchema = schema['properties']!['value'] as Map<String, dynamic>;
    final branches = valueSchema['anyOf'] as List;
    final encodedBranches = branches.map((branch) => jsonEncode(branch)).toList();
    expect(encodedBranches, contains(contains('"type":"boolean"')));
    expect(encodedBranches.any((b) => b.contains('"type":"integer"')), isTrue);
    expect(encodedBranches.any((b) => b.contains('"enum"')), isTrue);

    final keyEnum = (schema['properties']!['key'] as Map<String, dynamic>)['enum'] as List;
    expect(keyEnum, equals(PublicSettingKey.values.map((k) => k.publicName).toList()));

    expectHiddenSettingsToBeClosed(encodedSchema);
  });

  test('reminder setting uses its typed enum and rejects invalid values', () async {
    final update = createSettingsTools(
      actions: SettingsActions(
        repository: settingsRepository,
        transactions: DriftApplicationTransactionService(database),
        effects: effects,
      ),
      requestContext: requestContext,
    ).singleWhere((tool) => tool.name == 'whph_settings_update');

    final accepted = await update.handler(
        McpToolArguments(const {'key': 'taskDefaultPlannedReminder', 'value': 'fifteenMinutesBefore'}), requestExtra());
    final rejected = await update.handler(
        McpToolArguments(const {'key': 'taskDefaultPlannedReminder', 'value': 'whenever'}), requestExtra());

    expect(accepted.isError, isFalse);
    expect(rejected.structuredContent!['error'], containsPair('code', 'validation_error'));
    expect(effects.changes.single.value, 'fifteenMinutesBefore');
  });

  test('authorization revoked inside the transaction prevents a setting write and effect', () async {
    requestContext.isAllowed = false;
    final actions = SettingsActions(
      repository: settingsRepository,
      transactions: DriftApplicationTransactionService(database),
      effects: effects,
    );
    final tool = createSettingsTools(actions: actions, requestContext: requestContext)
        .singleWhere((definition) => definition.name == 'whph_settings_update');

    await expectLater(
      tool.handler(McpToolArguments(const {'key': 'notificationsEnabled', 'value': false}), requestExtra()),
      throwsA(isA<Exception>()),
    );
    expect(await settingsRepository.getByKey('NOTIFICATIONS_ENABLED'), isNull);
    expect(effects.changes, isEmpty);
  });
}
