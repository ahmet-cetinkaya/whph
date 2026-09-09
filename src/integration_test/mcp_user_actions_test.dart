import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_shutdown_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.dart' as app;
import 'package:whph/presentation/ui/app.dart';
import 'package:whph/presentation/ui/features/about/components/onboarding_dialog.dart';
import 'package:whph/presentation/ui/features/settings/components/mcp_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/notification_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/sound_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/startup_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/theme_settings.dart';
import 'package:whph/presentation/ui/features/settings/pages/settings_page.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';

final _captureKey = GlobalKey();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native Settings UI controls the isolated production MCP runtime', (tester) async {
    expect(Platform.isLinux, isTrue);
    final supportDirectory = await Directory.systemTemp.createTemp('whph-mcp-ui-task-14-');
    final evidenceDirectory = Directory(
      Platform.environment['TASK14_EVIDENCE_DIR'] ??
          p.join(Directory.current.path, '..', '.omo', 'evidence', 'mcp-agent-support'),
    );
    await evidenceDirectory.create(recursive: true);
    AppDatabase.resetInstance();
    app.container = await AppBootstrapService.initializeIsolatedForTesting(supportDirectory);
    final database = AppDatabase.instance();
    final access = app.container.resolve<IMcpAccessService>();
    final port = await _reserveLoopbackPort();
    await access.setPreferences(McpServerPreferences(
      isEnabled: false,
      port: port,
      transferDirectory: supportDirectory.path,
    ));

    try {
      await AppBootstrapService.initializeCoreServices(app.container);
      final backup = await app.container.resolve<Mediator>().send<ExportDataCommand, ExportDataCommandResponse>(
            ExportDataCommand(ExportDataFileOptions.backup),
          );
      await File(p.join(supportDirectory.path, 'task-14-import.whph')).writeAsBytes(backup.fileContent as List<int>);
      final translations = app.container.resolve<ITranslationService>();
      final theme = app.container.resolve<IThemeService>();
      await tester.pumpWidget(translations.wrapWithTranslations(RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: theme.themeData,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: McpSettings(
                accessService: access,
                runtimeService: app.container.resolve<McpRuntimeService>(),
                translationService: translations,
                operationService: app.container.resolve<IMcpOperationService>(),
                pickDirectory: () async => supportDirectory.path,
              ),
            ),
          ),
        ),
      )));
      await _pumpUi(tester);
      await _showMcpSettings(tester);
      expect(find.byKey(const Key('mcp-enable-switch')), findsOneWidget);
      await _capture(tester, evidenceDirectory, 'task-14-ui-disabled.png');

      await tester.tap(find.byKey(const Key('mcp-enable-switch')));
      await _pumpUi(tester);
      expect(find.text('http://127.0.0.1:$port/mcp'), findsOneWidget);
      await _capture(tester, evidenceDirectory, 'task-14-ui-enabled.png');

      await tester.tap(find.byKey(const Key('mcp-create-connection')));
      await _pumpUi(tester);
      expect(find.byKey(const Key('mcp-client-name')), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const Key('mcp-scope-tasks:read')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const Key('mcp-scope-tasks:write')),
            )
            .selected,
        isFalse,
      );
      await _capture(tester, evidenceDirectory, 'task-14-ui-scopes.png');
      for (final scope in McpScopes.all) {
        final chip = find.byKey(Key('mcp-scope-$scope'));
        if (!tester.widget<FilterChip>(chip).selected) {
          await tester.ensureVisible(chip);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(chip);
        }
      }
      await _pumpUi(tester);
      await _capture(tester, evidenceDirectory, 'task-14-ui-scopes-bottom.png');
      await tester.enterText(
        find.byKey(const Key('mcp-client-name')),
        'Task 14 Native Client',
      );
      await tester.pump(const Duration(milliseconds: 300));
      final createButton = find.byKey(const Key('mcp-create-confirm'));
      await tester.ensureVisible(createButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(createButton);
      await _pumpUi(tester);
      final activeGrant = (await access.readState()).grants.singleWhere((grant) => !grant.isRevoked);
      expect(activeGrant.scopes, McpScopes.all);
      expect(find.text('Task 14 Native Client'), findsOneWidget);
      await _capture(tester, evidenceDirectory, 'task-14-ui-grant.png');

      final pending = await app.container.resolve<IMcpOperationService>().prepare(
            clientGrantId: activeGrant.id,
            type: McpOperationType.dataImport,
            requiredScopes: const {McpScopes.dataImport},
            requestHash: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            summary: 'Task 14 isolated approval fixture',
            execute: () async => McpOperationResult(const {'imported': true}),
          );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('mcp-approvals-refresh')));
      await _showMcpSettings(tester);
      expect(find.byKey(Key('mcp-approval-${pending.id}')), findsOneWidget);
      await _capture(tester, evidenceDirectory, 'task-14-ui-approval.png');
      await tester.tap(find.byKey(Key('mcp-approve-${pending.id}')));
      await _pumpUi(tester);
      expect(find.byKey(Key('mcp-approval-${pending.id}')), findsNothing);
      await _capture(tester, evidenceDirectory, 'task-14-ui-approved.png');

      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      try {
        await tester.enterText(
          find.byKey(const Key('mcp-port-field')),
          '${occupied.port}',
        );
        await tester.tap(find.byKey(const Key('mcp-save-port')));
        await _pumpUi(tester);
        expect(find.byKey(const Key('mcp-error')), findsOneWidget);
        await _capture(tester, evidenceDirectory, 'task-14-ui-port-error.png');
      } finally {
        await occupied.close();
      }

      final grantTile = find.byKey(Key('mcp-grant-${activeGrant.id}'));
      await tester.tap(find.descendant(of: grantTile, matching: find.byIcon(Icons.link_off)));
      await _pumpUi(tester);
      await tester.tap(find.byType(FilledButton).last);
      await _pumpUi(tester);
      expect(find.text('Task 14 Native Client'), findsNothing);
      await _capture(tester, evidenceDirectory, 'task-14-ui-revoked.png');

      final runtime = app.container.resolve<McpRuntimeService>();
      final externalGrant = await access.createGrant(
        clientName: 'Task 14 external official client',
        scopes: McpScopes.all,
      );
      await runtime.updatePreferences(McpServerPreferences(
        isEnabled: true,
        port: port,
        transferDirectory: supportDirectory.path,
      ));
      final externalScenario = await _runExternalHappySmoke(
        endpoint: runtime.state.endpoint!,
        token: externalGrant.token,
        supportDirectory: supportDirectory,
      );
      final barrier = app.container.resolve<IRestoreBarrier>();
      expect(barrier.isRestoreActive, isFalse);
      expect(barrier.isRestoreOwner, isFalse);
      app.navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(translations.wrapWithTranslations(App(
        navigatorKey: app.navigatorKey,
        container: app.container,
        initialRoute: SettingsPage.route,
      )));
      await _pumpUi(tester);
      await _pumpUi(tester);
      await _completeOnboarding(tester);
      for (final component in <Type>[
        StartupSettings,
        NotificationSettings,
        ThemeSettings,
        SoundSettings,
      ]) {
        expect(
          find.descendant(
            of: find.byType(component),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
          reason: '$component remained loading',
        );
      }
      final loadingOverlay = tester.widget<LoadingOverlay>(find.byType(LoadingOverlay));
      expect(loadingOverlay.isLoading, isFalse);
      await _showMcpSettings(tester);
      await _capture(
        tester,
        evidenceDirectory,
        'task-14-ui-full-settings.png',
        captureKey: App.repaintBoundaryKey,
      );
      final suffix = externalScenario['suffix'] as String;
      expect(externalScenario['taskTimeRecordCount'], 1);
      await tester.tap(find.text('Tasks'));
      await _pumpUi(tester);
      await _pumpUi(tester);
      expect(find.text('MCP task $suffix'), findsOneWidget);
      await _capture(
        tester,
        evidenceDirectory,
        'task-14-ui-external-task.png',
        captureKey: App.repaintBoundaryKey,
      );
      await tester.tap(find.text('Habits'));
      await _pumpUi(tester);
      await _pumpUi(tester);
      expect(find.text('MCP good habit $suffix'), findsOneWidget);
      expect(find.text('MCP bad habit $suffix'), findsOneWidget);
      await _capture(
        tester,
        evidenceDirectory,
        'task-14-ui-external-habits.png',
        captureKey: App.repaintBoundaryKey,
      );
      await tester.tap(find.text('Notes'));
      await _pumpUi(tester);
      await _pumpUi(tester);
      expect(find.text('MCP edited note $suffix'), findsOneWidget);
      await _capture(
        tester,
        evidenceDirectory,
        'task-14-ui-external-note.png',
        captureKey: App.repaintBoundaryKey,
      );
    } finally {
      await app.container.resolve<IApplicationShutdownService>().shutdown();
      await database.close();
      AppDatabase.resetInstance();
      if (await supportDirectory.exists()) {
        await supportDirectory.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<int> _reserveLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<Map<String, dynamic>> _runExternalHappySmoke({
  required Uri endpoint,
  required String token,
  required Directory supportDirectory,
}) async {
  final repositoryRoot = Directory(p.normalize(p.join(Directory.current.path, '..')));
  final smokeDirectory = p.join(repositoryRoot.path, 'scripts', 'mcp-smoke');
  final resultFile = File(p.join(supportDirectory.path, 'native-external-happy.json'));
  final result = await Process.run(
    'npm',
    ['--prefix', smokeDirectory, 'test'],
    workingDirectory: repositoryRoot.path,
    environment: {
      ...Platform.environment,
      'MCP_SMOKE_URL': endpoint.toString(),
      'MCP_SMOKE_TOKEN': token,
      'MCP_SMOKE_MODE': 'happy',
      'MCP_SMOKE_RESULT_PATH': resultFile.path,
    },
  ).timeout(const Duration(minutes: 2));
  expect('${result.stdout}${result.stderr}', isNot(contains(token)));
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  expect(await resultFile.exists(), isTrue);
  final decoded = jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
  expect(decoded['scenario'], isA<Map<String, dynamic>>());
  return decoded['scenario'] as Map<String, dynamic>;
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _showMcpSettings(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('mcp-enable-switch')));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  expect(find.byType(OnboardingDialog), findsOneWidget);
  for (var page = 0; page < 8 && find.text('Next').evaluate().isNotEmpty; page++) {
    await tester.tap(find.text('Next'));
    await _pumpUi(tester);
  }
  expect(find.text('Skip Tour'), findsOneWidget);
  await tester.tap(find.text('Skip Tour'));
  await _pumpUi(tester);
  await _pumpUi(tester);
  expect(find.byType(OnboardingDialog), findsNothing);
}

Future<void> _capture(
  WidgetTester tester,
  Directory evidenceDirectory,
  String fileName, {
  GlobalKey? captureKey,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey ?? _captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null || bytes.lengthInBytes < 1024) {
    throw TestFailure('Screenshot $fileName was empty');
  }
  final file = File(p.join(evidenceDirectory.path, fileName));
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
}
