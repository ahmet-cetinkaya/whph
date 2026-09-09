import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acore/acore.dart' as acore;
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/presentation/ui/app/services/app_lifecycle_service.dart';
import 'package:whph/presentation/ui/features/settings/components/mcp_settings.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';
import 'package:whph/presentation/ui/shared/services/application_shutdown_service.dart';
import 'package:whph/presentation/ui/ui_presentation_container.dart' show notifyApplicationDataRestored;
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/task_calendar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MCP settings', () {
    late _FakeAccessService access;
    late _FakeServerService server;
    late McpRuntimeService runtime;
    late _FakeOperationService operations;
    String? clipboardText;

    setUp(() {
      access = _FakeAccessService();
      server = _FakeServerService();
      runtime = McpRuntimeService(
        accessService: access,
        serverService: server,
        isAndroid: false,
      );
      operations = _FakeOperationService();
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        },
      );
    });

    tearDown(() async {
      await runtime.dispose();
      await access.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: McpSettings(
              accessService: access,
              runtimeService: runtime,
              translationService: _FakeTranslationService(),
              operationService: operations,
              pickDirectory: () async => '/tmp/whph-mcp-transfer',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('enables listener and exposes its loopback endpoint', (tester) async {
      await pumpSettings(tester);

      expect(server.startCalls, 0);
      final onChanged = tester.widget<Switch>(find.byKey(const Key('mcp-enable-switch'))).onChanged!;
      await tester.runAsync(() async {
        onChanged(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();

      expect(access.state.preferences.isEnabled, isTrue);
      expect(server.startCalls, 1);
      expect(server.lastPort, 44041);
      expect(find.text('http://127.0.0.1:44041/mcp'), findsOneWidget);
    });

    testWidgets('creates read-scoped connection and copies token once', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('mcp-create-connection')));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
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

      await tester.enterText(
        find.byKey(const Key('mcp-client-name')),
        'Local Agent',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mcp-create-confirm')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(clipboardText, _FakeAccessService.issuedToken);
      expect(find.text(_FakeAccessService.issuedToken), findsNothing);
      expect(find.byKey(const Key('mcp-grant-created-grant')), findsOneWidget);
    });

    testWidgets('revokes an active connection immediately', (tester) async {
      access.addGrant('connection-1', 'Local Agent');
      await pumpSettings(tester);

      await tester.tap(find.byTooltip(SettingsTranslationKeys.mcpRevoke));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SettingsTranslationKeys.mcpConfirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(access.state.grants.single.isRevoked, isTrue);
      expect(find.text('Local Agent'), findsNothing);
    });

    testWidgets('keeps settings usable when the configured port is occupied', (tester) async {
      server.failStart = true;
      await pumpSettings(tester);

      final onChanged = tester.widget<Switch>(find.byKey(const Key('mcp-enable-switch'))).onChanged!;
      await tester.runAsync(() async {
        onChanged(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mcp-error')), findsOneWidget);
      expect(find.byKey(const Key('mcp-port-field')), findsOneWidget);
      expect(server.isRunning, isFalse);
    });

    test('failed running listener rebind clears the stale endpoint', () async {
      await runtime.updatePreferences(const McpServerPreferences(
        isEnabled: true,
        port: 44041,
        transferDirectory: '/tmp/whph-mcp-transfer',
      ));
      expect(runtime.state.isRunning, isTrue);

      server.failStart = true;
      await runtime.updatePreferences(const McpServerPreferences(
        isEnabled: true,
        port: 44042,
        transferDirectory: '/tmp/whph-mcp-transfer',
      ));

      expect(server.stopCalls, 1);
      expect(server.isRunning, isFalse);
      expect(runtime.state.preferences?.port, 44042);
      expect(runtime.state.isRunning, isFalse);
      expect(runtime.state.endpoint, isNull);
      expect(runtime.state.lastError, 'The local MCP listener could not be started.');
    });

    testWidgets('fails closed when secure storage cannot be read', (tester) async {
      access.failReads = true;
      await pumpSettings(tester);

      expect(find.byKey(const Key('mcp-error')), findsOneWidget);
      expect(server.startCalls, 0);
    });

    testWidgets('approves pending operations only from the local settings UI', (tester) async {
      await pumpSettings(tester);
      operations.addPending('operation-1');
      await tester.tap(find.byKey(const Key('mcp-approvals-refresh')));
      await tester.pump();

      expect(find.byKey(const Key('mcp-approval-operation-1')), findsOneWidget);
      expect(find.textContaining('dataImport'), findsNothing);
      expect(find.textContaining('.000000'), findsNothing);
      await tester.tap(find.byKey(const Key('mcp-approve-operation-1')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();

      expect(operations.approvedIds, const ['operation-1']);
      expect(find.byKey(const Key('mcp-approval-operation-1')), findsNothing);
    });
  });

  testWidgets('Android lifecycle starts only resumed and awaits every stop', (tester) async {
    final access = _FakeAccessService(isEnabled: true);
    final server = _FakeServerService();
    final runtime = McpRuntimeService(
      accessService: access,
      serverService: server,
      isAndroid: true,
    );
    final tray = _FakeSystemTrayService();
    final lifecycle = AppLifecycleService(tray, runtime, isMobile: true);

    await runtime.initialize();
    expect(server.isRunning, isFalse);

    await lifecycle.handleLifecycleState(AppLifecycleState.resumed);
    expect(server.isRunning, isTrue);
    await lifecycle.handleLifecycleState(AppLifecycleState.inactive);
    expect(server.isRunning, isFalse);
    await lifecycle.handleLifecycleState(AppLifecycleState.resumed);
    await lifecycle.handleLifecycleState(AppLifecycleState.hidden);
    expect(server.isRunning, isFalse);
    await lifecycle.handleLifecycleState(AppLifecycleState.resumed);
    await lifecycle.handleLifecycleState(AppLifecycleState.paused);
    expect(server.isRunning, isFalse);
    await lifecycle.handleLifecycleState(AppLifecycleState.resumed);
    await lifecycle.handleLifecycleState(AppLifecycleState.detached);
    expect(server.isRunning, isFalse);
    expect(server.stopCalls, 4);

    lifecycle.dispose();
    await runtime.dispose();
    await access.dispose();
  });

  test('controlled shutdown flushes timers before stopping MCP and closing access storage', () async {
    final calls = <String>[];
    final timer = _RecordingTimerService(calls);
    final server = _FakeServerService(calls: calls)..isRunning = true;
    final access = _FakeAccessService(calls: calls);
    final shutdown = ApplicationShutdownService(
      timerSessionService: timer,
      mcpServerService: server,
      mcpAccessService: access,
    );

    await shutdown.shutdown();

    expect(calls, ['timer.shutdown', 'mcp.stop', 'access.dispose']);
  });

  test('restore callback invalidates every already-open data surface', () {
    final restored = <String>[];
    final testContainer = acore.Container();
    final tasks = TasksService()..onTaskCreated.addListener(() => restored.add('tasks'));
    final habits = HabitsService()..onHabitCreated.addListener(() => restored.add('habits'));
    final notes = NotesService()..onNoteCreated.addListener(() => restored.add('notes'));
    final tags = TagsService()..onTagCreated.addListener(() => restored.add('tags'));
    final usages = AppUsagesService()..onAppUsageCreated.addListener(() => restored.add('usages'));
    final timeData = TimeDataService()..onTimeDataChanged.addListener(() => restored.add('timeData'));
    final calendar = TaskCalendarService(_TestMediator())..addListener(() => restored.add('calendar'));
    testContainer.registerSingleton<TasksService>((_) => tasks);
    testContainer.registerSingleton<HabitsService>((_) => habits);
    testContainer.registerSingleton<NotesService>((_) => notes);
    testContainer.registerSingleton<TagsService>((_) => tags);
    testContainer.registerSingleton<AppUsagesService>((_) => usages);
    testContainer.registerSingleton<TimeDataService>((_) => timeData);
    testContainer.registerSingleton<TaskCalendarService>((_) => calendar);

    notifyApplicationDataRestored(testContainer);

    expect(restored, containsAll(<String>['tasks', 'habits', 'notes', 'tags', 'usages', 'timeData', 'calendar']));
  });

  test('controlled shutdown reports failure after attempting every cleanup', () async {
    final calls = <String>[];
    final shutdown = ApplicationShutdownService(
      timerSessionService: _RecordingTimerService(calls, failShutdown: true),
      mcpServerService: _FakeServerService(calls: calls)..isRunning = true,
      mcpAccessService: _FakeAccessService(calls: calls),
    );

    await expectLater(shutdown.shutdown(), throwsA(isA<ApplicationShutdownException>()));
    expect(calls, ['timer.shutdown', 'mcp.stop', 'access.dispose']);
  });
}

class _FakeAccessService implements IMcpAccessService {
  static const issuedToken = 'test-token-never-rendered';

  final StreamController<McpAccessRevocation> _revocations = StreamController.broadcast();
  bool failReads = false;
  McpAccessState state;
  final List<String>? calls;

  _FakeAccessService({bool isEnabled = false, this.calls})
      : state = McpAccessState(
          preferences: McpServerPreferences(
            isEnabled: isEnabled,
            port: 44041,
            transferDirectory: '/tmp/whph-mcp',
          ),
          grants: const [],
        );

  void addGrant(String id, String name) {
    state = McpAccessState(
      preferences: state.preferences,
      grants: [
        ...state.grants,
        McpAccessGrant(
          id: id,
          clientName: name,
          tokenDigest: 'digest',
          scopes: const {McpScopes.tasksRead},
          createdAt: DateTime.utc(2026),
          rotatedAt: null,
          revokedAt: null,
        ),
      ],
    );
  }

  @override
  Stream<McpAccessRevocation> get revocations => _revocations.stream;

  @override
  Future<McpAccessState> readState() async {
    if (failReads) {
      throw const McpAccessStorageException('test storage failure');
    }
    return state;
  }

  @override
  Future<void> setPreferences(McpServerPreferences preferences) async {
    state = McpAccessState(preferences: preferences, grants: state.grants);
  }

  @override
  Future<McpIssuedGrant> createGrant({
    required String clientName,
    required Set<String> scopes,
  }) async {
    addGrant('created-grant', clientName);
    final grant = state.grants.last;
    state = McpAccessState(
      preferences: state.preferences,
      grants: [
        ...state.grants.take(state.grants.length - 1),
        McpAccessGrant(
          id: grant.id,
          clientName: grant.clientName,
          tokenDigest: grant.tokenDigest,
          scopes: scopes,
          createdAt: grant.createdAt,
          rotatedAt: null,
          revokedAt: null,
        ),
      ],
    );
    return McpIssuedGrant(grant: state.grants.last, token: issuedToken);
  }

  @override
  Future<McpIssuedGrant> rotateGrant(String grantId) async => McpIssuedGrant(
        grant: state.grants.firstWhere((grant) => grant.id == grantId),
        token: issuedToken,
      );

  @override
  Future<void> revokeGrant(String grantId) async {
    final now = DateTime.utc(2026, 9, 8);
    state = McpAccessState(
      preferences: state.preferences,
      grants: state.grants
          .map((grant) => grant.id == grantId
              ? McpAccessGrant(
                  id: grant.id,
                  clientName: grant.clientName,
                  tokenDigest: grant.tokenDigest,
                  scopes: grant.scopes,
                  createdAt: grant.createdAt,
                  rotatedAt: grant.rotatedAt,
                  revokedAt: now,
                )
              : grant)
          .toList(),
    );
    _revocations.add(McpAccessRevocation(grantId: grantId));
  }

  @override
  Future<McpAuthenticatedGrant?> authenticate(
    String token, {
    Set<String> requiredScopes = const {},
  }) async =>
      null;

  @override
  Future<void> dispose() async {
    calls?.add('access.dispose');
    await _revocations.close();
  }
}

class _FakeOperationService implements IMcpOperationService {
  List<McpOperation> _pending = const [];
  List<String> approvedIds = const [];

  void addPending(String id) {
    final now = DateTime.utc(2026, 9, 8);
    _pending = List.unmodifiable([
      ..._pending,
      McpOperation(
        id: id,
        type: McpOperationType.dataImport,
        status: McpOperationStatus.pendingApproval,
        clientGrantId: 'grant-1',
        requiredScopes: const {McpScopes.dataImport},
        requestHash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        summary: 'Import an isolated test backup',
        createdAt: now,
        approvalExpiresAt: now.add(const Duration(minutes: 5)),
      ),
    ]);
  }

  @override
  Future<List<McpOperation>> listPending() async => _pending;

  @override
  Future<McpOperation> approve(String operationId) async {
    approvedIds = List.unmodifiable([...approvedIds, operationId]);
    return _remove(operationId, McpOperationStatus.succeeded);
  }

  @override
  Future<McpOperation> reject(String operationId) async => _remove(operationId, McpOperationStatus.rejected);

  McpOperation _remove(String operationId, McpOperationStatus status) {
    final operation = _pending.singleWhere((item) => item.id == operationId);
    _pending = List.unmodifiable(
      _pending.where((item) => item.id != operationId),
    );
    return McpOperation(
      id: operation.id,
      type: operation.type,
      status: status,
      clientGrantId: operation.clientGrantId,
      requiredScopes: operation.requiredScopes,
      requestHash: operation.requestHash,
      summary: operation.summary,
      createdAt: operation.createdAt,
      approvalExpiresAt: operation.approvalExpiresAt,
    );
  }

  @override
  Future<McpOperation?> getForClient({
    required String operationId,
    required String clientGrantId,
    required Set<String> currentScopes,
  }) async =>
      null;

  @override
  Future<McpOperation> prepare({
    required String clientGrantId,
    required McpOperationType type,
    required Set<String> requiredScopes,
    required String requestHash,
    required String summary,
    required McpOperationExecutor execute,
  }) =>
      throw UnimplementedError();
}

class _FakeServerService implements IMcpServerService {
  _FakeServerService({this.calls});

  final List<String>? calls;
  bool failStart = false;
  int startCalls = 0;
  int stopCalls = 0;
  int? lastPort;

  @override
  bool isRunning = false;

  @override
  int? get boundPort => isRunning ? lastPort : null;

  @override
  Uri? get endpoint => isRunning ? Uri.parse('http://127.0.0.1:$lastPort/mcp') : null;

  @override
  Future<void> start({required int port}) async {
    startCalls++;
    lastPort = port;
    if (failStart) throw StateError('address already in use');
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    calls?.add('mcp.stop');
    if (isRunning) stopCalls++;
    isRunning = false;
  }
}

class _RecordingTimerService implements ITimerSessionService {
  _RecordingTimerService(this.calls, {this.failShutdown = false});

  final List<String> calls;
  final bool failShutdown;

  @override
  Stream<TimerSessionState> get changes => const Stream.empty();

  @override
  List<TimerSessionState> list() => const [];

  @override
  TimerSessionState? state(String sessionId) => null;

  @override
  Future<void> shutdown() async {
    calls.add('timer.shutdown');
    if (failShutdown) throw StateError('test timer flush failure');
  }

  @override
  TimerSessionState create({
    required String sessionId,
    required TimerSessionOwner owner,
    required TimerSessionSettings settings,
    String? selectedTaskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TimerSessionState> pause(String sessionId) => throw UnimplementedError();

  @override
  Future<TimerSessionState> restart(String sessionId) => throw UnimplementedError();

  @override
  Future<TimerSessionState> resume(String sessionId) => throw UnimplementedError();

  @override
  Future<TimerSessionState> selectTask(
    String sessionId,
    String? taskId, {
    Future<void> Function()? beforeCommit,
  }) =>
      throw UnimplementedError();

  @override
  Future<TimerSessionState> start(String sessionId) => throw UnimplementedError();

  @override
  Future<TimerSessionState> stop(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  }) =>
      throw UnimplementedError();

  @override
  Future<TimerSessionState> toggleWorkBreak(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  }) =>
      throw UnimplementedError();

  @override
  Future<TimerSessionState> updateSettings(String sessionId, TimerSessionSettings settings) =>
      throw UnimplementedError();
}

class _TestMediator extends Mediator {
  _TestMediator() : super(Pipeline());
}

class _FakeTranslationService implements ITranslationService {
  @override
  Future<void> init() async {}

  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;

  @override
  Future<void> changeLanguage(BuildContext context, String languageCode) async {}

  @override
  Future<void> changeLanguageWithoutNavigation(BuildContext context, String languageCode) async {}

  @override
  String getCurrentLanguage(BuildContext context) => 'en';

  @override
  Widget wrapWithTranslations(Widget child) => child;
}

class _FakeSystemTrayService implements ISystemTrayService {
  @override
  Future<void> cancelTrayNotification() async {}
  @override
  Future<void> destroy() async {}
  @override
  Future<TrayMenuItem?> getMenuItem(String key) async => null;
  @override
  List<TrayMenuItem> getMenuItems() => const [];
  @override
  Future<void> init() async {}
  @override
  Future<void> insertMenuItem(TrayMenuItem item, {int? index}) async {}
  @override
  Future<void> removeMenuItem(String key) async {}
  @override
  Future<void> reset() async {}
  @override
  Future<void> setBody(String body) async {}
  @override
  Future<void> setIcon(TrayIconType type) async {}
  @override
  Future<void> setMenuItems(List<TrayMenuItem> items) async {}
  @override
  Future<void> setTitle(String title) async {}
  @override
  Future<void> updateMenuItem(String key, TrayMenuItem newItem) async {}
}
